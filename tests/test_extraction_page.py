"""Page « Extraction » du tableau : exemples du jeu rapide et extraction en
direct, avec une passerelle simulée (serveur local, sans modèle)."""

from __future__ import annotations

import json
import os
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from _paths import ROOT

os.environ.setdefault("FARCI_ROOT", str(ROOT))
sys.path.insert(0, str(ROOT / "01-network-dashboard" / "health-aggregator"))
import extraction  # noqa: E402

IPP = extraction.cas_rapides()[0]


class Exemples(unittest.TestCase):
    def test_dix_dossiers_du_jeu_rapide(self):
        self.assertEqual(len(extraction.liste()), 10)

    def test_le_modele_ne_recoit_rien_d_identifiant(self):
        ex = extraction.exemple(IPP)
        self.assertEqual([d["type"] for d in ex["documents"]], ["cro", "crap", "crscan", "lettre"])
        self.assertIn(IPP, ex["documents"][0]["texte"])
        self.assertNotIn(IPP, ex["dossier"])
        self.assertIn("[IPP_0]", ex["dossier"])
        self.assertEqual(set(ex["prompts"]), {"v1", "v2"})
        self.assertNotIn("_meta", ex["gold"])

    def test_dossier_inconnu_ou_chemin_refuse(self):
        self.assertIsNone(extraction.exemple("../../etc/passwd"))
        self.assertIsNone(extraction.exemple("0000000000000"))

    def test_gold_contre_gold_tout_juste(self):
        gold = extraction.exemple(IPP)["gold"]
        c = extraction.comparer(gold, gold)
        self.assertEqual(c["justes"], c["total"])


class Direct(unittest.TestCase):
    """Une passerelle simulée qui se trompe sur un champ."""

    @classmethod
    def setUpClass(cls):
        gold = extraction.exemple(IPP)["gold"]
        reponse = {**gold, "tumor_size_mm": 999}

        class Passerelle(BaseHTTPRequestHandler):
            def do_POST(self):
                corps = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                cls.recu = corps
                body = json.dumps({"model": "simule", "choices": [{"message": {
                    "content": "```json\n" + json.dumps(reponse) + "\n```"}}]}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Passerelle)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        os.environ["FARCI_EXTRACTION_URL"] = f"http://127.0.0.1:{cls.server.server_port}/v1"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        os.environ.pop("FARCI_EXTRACTION_URL", None)

    def test_extraction_comparee_au_gold(self):
        code, res = extraction.extraire(IPP, "v2")
        self.assertEqual(code, 200)
        self.assertTrue(res["ok"])
        faux = [l["champ"] for l in res["comparaison"]["lignes"] if not l["juste"]]
        self.assertEqual(faux, ["tumor_size_mm"])
        messages = self.recu["messages"]
        self.assertEqual(self.recu["model"], "med-extraction")
        self.assertNotIn(IPP, messages[1]["content"])      # le dossier envoyé est pseudonymisé
        self.assertIn("Tu es un moteur d'extraction", messages[0]["content"])

    def test_prompt_inconnu(self):
        self.assertEqual(extraction.extraire(IPP, "v9")[0], 400)


if __name__ == "__main__":
    unittest.main()
