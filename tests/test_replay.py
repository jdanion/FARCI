"""Plan C — runtime rejoué : les étapes 2 et 3 sans GPU, sans modèle, sans Docker.

Démarre reference/replay/server.py dans le processus, puis joue le parcours
Python complet (pseudonymisation → appel au contrat OpenAI → validation →
écriture → évaluation) avec le client en Python standard."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import threading
import unittest
import urllib.request
from pathlib import Path

from _paths import HAS_PYDANTIC, ROOT

sys.path.insert(0, str(ROOT / "reference" / "replay"))

import evaluate as ev  # noqa: E402
import recordings  # noqa: E402
import server  # noqa: E402

RAW = ROOT / "datasets" / "raw"
GOLD = ROOT / "datasets" / "gold"


def post(url: str, payload: dict) -> bytes:
    request = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


class RuntimeRejoue(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["no_proxy"] = os.environ["NO_PROXY"] = "*"
        cls.httpd = server.make_server(0, delay=0, host="127.0.0.1")
        cls.base = f"http://127.0.0.1:{cls.httpd.server_address[1]}/v1"
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()

    def test_enregistrements_a_jour(self):
        current = json.loads(recordings.OUTPUT.read_text(encoding="utf-8"))
        self.assertEqual(current, json.loads(json.dumps(recordings.synthetic())))

    def test_contrat_models(self):
        with urllib.request.urlopen(self.base + "/models", timeout=5) as response:
            data = json.load(response)
        self.assertEqual(data["object"], "list")
        self.assertIn("med-extraction", [m["id"] for m in data["data"]])

    def test_raisonnement_hors_du_contenu(self):
        text = next(RAW.glob("patient_*_crap.txt")).read_text(encoding="utf-8")
        data = json.loads(post(self.base + "/chat/completions",
                               {"model": "med-extraction", "messages": [{"role": "user", "content": text}]}))
        message = data["choices"][0]["message"]
        self.assertTrue(message["reasoning_content"])
        self.assertNotIn("Mode rejoué", message["content"])

    def test_flux_sse(self):
        text = next(RAW.glob("patient_*_cro.txt")).read_text(encoding="utf-8")
        raw = post(self.base + "/chat/completions", {"model": "med-extraction", "stream": True,
                                                     "messages": [{"role": "user", "content": text}]})
        events = [line[6:] for line in raw.decode().splitlines() if line.startswith("data: ")]
        self.assertEqual(events[-1], "[DONE]")
        content = "".join(json.loads(e)["choices"][0]["delta"].get("content", "") for e in events[:-1])
        self.assertIn('"diagnosis"', content)

    def test_message_non_reconnu(self):
        data = json.loads(post(self.base + "/chat/completions",
                               {"messages": [{"role": "user", "content": "bonjour"}]}))
        self.assertIn("Mode rejoué", data["choices"][0]["message"]["content"])

    @unittest.skipUnless(HAS_PYDANTIC, "pydantic absent (pip install -r requirements.txt)")
    def test_parcours_complet_et_classement(self):
        from common import farci_client, pipeline

        tmp = Path(tempfile.mkdtemp())
        os.environ["FARCI_GATEWAY_URL"] = self.base
        os.environ["FARCI_TRACE"] = "off"
        saved, farci_client.OpenAI = farci_client.OpenAI, None  # chemin stdlib

        def complete(messages, model):
            return farci_client.chat_completion(messages, model=model)

        try:
            for prompt in ("v1", "v2"):
                pipeline.run(RAW, tmp / prompt, complete, prompt_version=prompt, log=lambda _: None)
            chaos = pipeline.run(RAW, tmp / "chaos", complete, model="med-chaos", log=lambda _: None)
            runs = {r["run"]: r for r in ev.evaluate(GOLD, tmp)["runs"]}
        finally:
            farci_client.OpenAI = saved
            shutil.rmtree(tmp)
        # Scénario 04 : tout est refusé, rien n'est écrit.
        self.assertEqual(chaos, {"ecrits": 0, "rejetes": 20, "erreurs": 0})
        self.assertEqual(runs["v1"]["json_valides"], 19)
        self.assertEqual(runs["v2"]["json_valides"], 20)
        self.assertGreater(runs["v2"]["f1"], runs["v1"]["f1"])
        self.assertGreater(runs["v1"]["f1"], 0.9)


if __name__ == "__main__":
    unittest.main()
