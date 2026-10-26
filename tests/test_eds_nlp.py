"""Service EDS-NLP (équipe 4) : contrat HTTP, doublure rejouée, client.

Sans EDS-NLP installé (CI, postes étudiants), on teste le contrat HTTP avec
des pipelines factices, l'annotation XML du runtime rejoué et le client. Avec
EDS-NLP (image farci/eds-nlp, ou `pip install edsnlp`), on teste en plus les
vrais composants de l'AP-HP contre le runtime rejoué."""

from __future__ import annotations

import importlib.util
import json
import os
import threading
import unittest
import urllib.error
import urllib.request
from types import SimpleNamespace

from _paths import ROOT

import server as replay  # reference/replay

EDS_DIR = ROOT / "04-clinical-documents" / "eds-nlp"
HAS_EDSNLP = importlib.util.find_spec("edsnlp") is not None and importlib.util.find_spec("eds_pseudo") is not None


def load(name: str):
    spec = importlib.util.spec_from_file_location(f"eds_{name}", EDS_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


service = load("service")
client = load("client")
NO_PROXY = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def call(url: str, payload: dict | None = None) -> tuple[int, dict]:
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with NO_PROXY.open(request, timeout=10) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        return exc.code, json.load(exc)


class FakeService:
    api_url, model = "http://passerelle/v1", "med-extraction"

    def pseudonymize(self, text, context):
        return {"texte": text.replace(context.get("NOM", ["?"])[0], "[NOM]"), "entites": []}

    def entities(self, text, context, pseudonymize=True):
        if "panne" in text:
            raise RuntimeError("passerelle injoignable")
        return {"texte_envoye": text, "entites": [], "modele": self.model}


class ContratHTTP(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = service.make_server(FakeService(), 0, host="127.0.0.1")
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()
        cls.url = f"http://127.0.0.1:{cls.httpd.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()

    def test_sante(self):
        self.assertEqual(call(self.url + "/health"), (200, {"status": "ok", "llm": "http://passerelle/v1",
                                                            "modele": "med-extraction"}))

    def test_pseudonymiser(self):
        code, body = call(self.url + "/v1/pseudonymiser", {"texte": "M. Dupont", "contexte": {"NOM": "Dupont"}})
        self.assertEqual((code, body["texte"]), (200, "M. [NOM]"))

    def test_corps_invalide(self):
        self.assertEqual(call(self.url + "/v1/entites", {"text": "anglais"})[0], 400)

    def test_llm_injoignable_502(self):
        code, body = call(self.url + "/v1/entites", {"texte": "panne"})
        self.assertEqual(code, 502)
        self.assertIn("passerelle", body["erreur"])

    def test_contexte_filtre(self):
        self.assertEqual(service.clean_context({"nom": "Dupont", "pirate": "x", "IPP": ["", "123"]}),
                         {"NOM": ["Dupont"], "IPP": ["123"]})


class DoublureRejouee(unittest.TestCase):
    def test_annotation_xml(self):
        body = {"model": "med-extraction", "messages": [
            {"role": "system", "content": "Tu es un assistant d'annotation XML."},
            {"role": "user", "content": "exemple"}, {"role": "assistant", "content": "exemple"},
            {"role": "user", "content": "DPC pour TNE grade 2 du pancréas, pT3 pN1."}]}
        _, content, _ = replay.completion(replay.Library(), body)
        self.assertEqual(content, "<intervention>DPC</intervention> pour "
                                  "<diagnostic>TNE grade 2 du pancréas</diagnostic>, "
                                  "<stade>pT3</stade> <stade>pN1</stade>.")


class Client(unittest.TestCase):
    def test_contexte_depuis_le_registre(self):
        context = client.context_for(client.patient_id(client.RAW / "patient_1234567890123_cro.txt"))
        self.assertEqual((context["NOM"], context["IPP"]), (["Dupont"], ["1234567890123"]))

    def test_attendus_du_gold(self):
        case = SimpleNamespace(histology="TNE grade 2", diagnosis="TNE grade 2 du pancréas",
                               procedure_type="DPC", pT="pT3", pN=None, pancreatic_fistula=True,
                               delayed_gastrojejunostomy=False, hemorrhage=False)
        self.assertEqual(client.expected(case)["complication"], {"fistule pancréatique"})
        self.assertEqual(client.expected(case)["stade"], {"pt3"})


@unittest.skipUnless(HAS_EDSNLP, "EDS-NLP absent (il tourne dans l'image farci/eds-nlp)")
class VraisComposantsAPHP(unittest.TestCase):
    """EDS-Pseudo + eds.llm_markup_extractor, contre le runtime rejoué."""

    @classmethod
    def setUpClass(cls):
        cls.runtime = replay.make_server(0, host="127.0.0.1")
        threading.Thread(target=cls.runtime.serve_forever, daemon=True).start()
        os.environ.setdefault("OPENAI_API_KEY", "farci")
        os.environ["no_proxy"] = os.environ["NO_PROXY"] = "127.0.0.1"
        cls.service = service.Service(f"http://127.0.0.1:{cls.runtime.server_address[1]}/v1", "med-extraction")
        cls.text = (client.RAW / "patient_1234567890123_cro.txt").read_text(encoding="utf-8")
        cls.context = client.context_for("1234567890123")

    @classmethod
    def tearDownClass(cls):
        cls.runtime.shutdown()

    def test_aucune_identite_ne_reste(self):
        result = self.service.pseudonymize(self.text, self.context)
        for value in ("Jean", "Dupont", "1234567890123", "15/03/1958"):
            self.assertNotIn(value, result["texte"])

    def test_le_modele_ne_voit_que_le_texte_pseudonymise(self):
        result = self.service.entities(self.text, self.context)
        self.assertNotIn("Dupont", result["texte_envoye"])
        labels = {e["label"] for e in result["entites"]}
        self.assertLessEqual({"diagnostic", "intervention"}, labels)


if __name__ == "__main__":
    unittest.main()
