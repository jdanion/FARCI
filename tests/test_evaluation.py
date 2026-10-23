"""Évaluation : un gold comparé à lui-même doit obtenir un score parfait, et
chaque défaut (dossier absent, JSON invalide, valeur fausse) doit se voir."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

import evaluate as ev
from metrics import compute_metrics
from normalize import normalize_value

GOLD = ROOT / "datasets" / "gold"


class GoldContreGold(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.extracted = self.tmp / "extracted"
        shutil.copytree(GOLD, self.extracted / "equipe-1")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_eval(self, **kwargs):
        return ev.evaluate(GOLD, self.extracted, **kwargs)

    def test_score_parfait(self):
        results = self.run_eval()
        self.assertEqual(results["nb_dossiers"], 20)
        [run] = results["runs"]
        self.assertEqual(run["run"], "equipe-1")
        self.assertEqual(run["json_valides"], 20)
        self.assertEqual(run["completude"], 1.0)
        self.assertEqual(run["exactitude"], 1.0)
        self.assertEqual((run["precision"], run["recall"], run["f1"]), (1.0, 1.0, 1.0))

    def test_gold_directement_comme_run(self):
        results = ev.evaluate(GOLD, GOLD)
        self.assertEqual(results["runs"][0]["f1"], 1.0)

    def test_jeu_rapide(self):
        results = self.run_eval(subset="quick")
        self.assertEqual(results["nb_dossiers"], 10)
        self.assertEqual(results["runs"][0]["f1"], 1.0)

    def test_dossier_absent_compte_comme_manque(self):
        next((self.extracted / "equipe-1").glob("patient_*.json")).unlink()
        [run] = self.run_eval()["runs"]
        self.assertEqual(run["json_valides"], 19)
        self.assertAlmostEqual(run["completude"], 0.95)
        self.assertEqual(run["precision"], 1.0)
        self.assertLess(run["recall"], 1.0)

    def test_json_illisible_et_hors_schema(self):
        files = sorted((self.extracted / "equipe-1").glob("patient_*.json"))
        files[0].write_text("{pas du json", encoding="utf-8")
        data = json.loads(files[1].read_text(encoding="utf-8"))
        data["sex"] = "X"
        files[1].write_text(json.dumps(data), encoding="utf-8")
        [run] = self.run_eval()["runs"]
        self.assertEqual(run["json_valides"], 18)
        statuts = {d["statut"] for d in run["par_dossier"]}
        self.assertIn("illisible", statuts)
        self.assertIn("invalide", statuts)

    def test_classement_par_f1(self):
        moins_bon = self.extracted / "equipe-2"
        shutil.copytree(self.extracted / "equipe-1", moins_bon)
        for path in moins_bon.glob("patient_*.json"):
            data = json.loads(path.read_text(encoding="utf-8"))
            data["length_of_stay"] = data["length_of_stay"] + 1
            path.write_text(json.dumps(data), encoding="utf-8")
        runs = self.run_eval()["runs"]
        self.assertEqual([r["run"] for r in runs], ["equipe-1", "equipe-2"])
        self.assertLess(runs[1]["f1"], 1.0)

    def test_latence_lue_dans_meta(self):
        for path in (self.extracted / "equipe-1").glob("patient_*.json"):
            data = json.loads(path.read_text(encoding="utf-8"))
            data["_meta"] = {"latency_s": 2.0}
            path.write_text(json.dumps(data), encoding="utf-8")
        [run] = self.run_eval()["runs"]
        self.assertEqual(run["latence_moyenne_s"], 2.0)


class Metriques(unittest.TestCase):
    def test_issues_par_champ(self):
        gold = {"age": 60, "pT": None, "tumor_size_mm": 20.0, "sex": "M"}
        pred = {"age": "60 ans", "pT": "pT2", "tumor_size_mm": None, "sex": "F"}
        fields = compute_metrics(gold, pred)["fields"]
        self.assertEqual(fields["age"]["outcome"], "vp")
        self.assertEqual(fields["pT"]["outcome"], "fp")
        self.assertEqual(fields["tumor_size_mm"]["outcome"], "fn")
        self.assertEqual(fields["sex"]["outcome"], "faux")

    def test_normalisation(self):
        self.assertEqual(normalize_value("approach", "Cœlioscopie"), normalize_value("approach", "coelioscopie"))
        self.assertEqual(normalize_value("tumor_size_mm", "28,0 mm"), 28.0)
        self.assertIs(normalize_value("readmission", "Non"), False)
        self.assertIsNone(normalize_value("pT", None))


if __name__ == "__main__":
    unittest.main()
