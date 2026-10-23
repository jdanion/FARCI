"""Structured output (FARCI §28, scénario 04) : une sortie de LLM ne devient
une donnée de recherche qu'après validation. Si elle échoue, RIEN n'est écrit.

Le modèle est simulé : ces tests n'ont besoin ni de GPU, ni de réseau."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from _paths import HAS_PYDANTIC, ROOT

GOLD = ROOT / "datasets" / "gold"
RAW = ROOT / "datasets" / "raw"


def gold_answer(key: str) -> dict:
    data = json.loads((GOLD / f"patient_{key}.json").read_text(encoding="utf-8"))
    data.pop("_meta")
    data.pop("nir")
    return data


@unittest.skipUnless(HAS_PYDANTIC, "pydantic absent (pip install -r requirements.txt)")
class SortieStructuree(unittest.TestCase):
    def setUp(self):
        from common import pipeline

        self.pipeline = pipeline
        self.tmp = Path(tempfile.mkdtemp())
        self.keys = sorted(pipeline.patient_documents(RAW))[:3]
        self.logs: list[str] = []

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_with(self, answer):
        """answer(dossier_text, key) -> texte renvoyé par le « modèle »."""
        order = iter(self.keys)

        def complete(messages, model):
            self.assertEqual(model, "med-extraction")
            self.assertEqual(messages[0]["role"], "system")
            return answer(messages[1]["content"], next(order))

        return self.pipeline.run(RAW, self.tmp, complete, only=set(self.keys), log=self.logs.append)

    def written(self):
        return sorted(p.name for p in self.tmp.glob("patient_*.json"))

    def test_json_conforme_ecrit(self):
        summary = self.run_with(lambda text, key: json.dumps(gold_answer(key)))
        self.assertEqual(summary["ecrits"], 3)
        self.assertEqual(self.written(), [f"patient_{k}.json" for k in self.keys])
        data = json.loads((self.tmp / f"patient_{self.keys[0]}.json").read_text(encoding="utf-8"))
        self.assertIn("latency_s", data["_meta"])

    def test_bloc_markdown_tolere(self):
        summary = self.run_with(lambda t, k: "```json\n" + json.dumps(gold_answer(k)) + "\n```")
        self.assertEqual(summary["ecrits"], 3)

    def test_json_invalide_rien_ecrit(self):
        summary = self.run_with(lambda t, k: '{"age": 67, "sex": ')
        self.assertEqual(summary, {"ecrits": 0, "rejetes": 3, "erreurs": 0})
        self.assertEqual(self.written(), [])

    def test_hors_schema_rien_ecrit(self):
        def wrong(text, key):
            data = gold_answer(key)
            data["approach"] = "robotique"
            return json.dumps(data)

        summary = self.run_with(wrong)
        self.assertEqual(summary["rejetes"], 3)
        self.assertEqual(self.written(), [])

    def test_raisonnement_dans_content_rejete(self):
        # Contrat reasoning (PLAN R11) : le raisonnement doit être dans
        # reasoning_content. S'il fuit dans content, le JSON est refusé.
        summary = self.run_with(lambda t, k: "<think>calcul</think>" + json.dumps(gold_answer(k)))
        self.assertEqual(summary["ecrits"], 0)

    def test_le_modele_ne_voit_pas_d_identifiant(self):
        seen = []

        def spy(text, key):
            seen.append(text)
            return json.dumps(gold_answer(key))

        self.run_with(spy)
        for text, key in zip(seen, self.keys):
            self.assertNotIn(key, text)
            self.assertIn("[IPP_", text)

    def test_panne_passerelle_comptee_comme_erreur(self):
        def down(text, key):
            raise ConnectionError("passerelle injoignable")

        summary = self.run_with(down)
        self.assertEqual(summary["erreurs"], 3)
        self.assertEqual(self.written(), [])


if __name__ == "__main__":
    unittest.main()
