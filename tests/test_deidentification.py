"""Pseudonymisation : aucun identifiant direct du dataset ne doit atteindre
le modèle (IPP, NIR, nom, prénom, date de naissance)."""

from __future__ import annotations

import unittest

from _paths import ROOT

from cases import CASES
from deidentification import MappingStore, pseudonymize_text

RAW = ROOT / "datasets" / "raw"


class Pseudonymisation(unittest.TestCase):
    def test_aucune_fuite_sur_le_dataset(self):
        checked = 0
        for case in CASES:
            for path in sorted(RAW.glob(f"patient_{case.patient_id}_*.txt")):
                text = pseudonymize_text(path.read_text(encoding="utf-8"), MappingStore())
                for secret in (case.patient_id, case.nir, case.nom, case.prenom):
                    self.assertNotIn(secret, text, f"{path.name} : {secret} en clair")
                checked += 1
        self.assertEqual(checked, 80)

    def test_deterministe_et_reversible(self):
        path = next(RAW.glob("patient_*_cro.txt"))
        source = path.read_text(encoding="utf-8")
        first, second = MappingStore(), MappingStore()
        self.assertEqual(pseudonymize_text(source, first), pseudonymize_text(source, second))
        self.assertEqual(first.to_dict(), second.to_dict())
        self.assertIn("IPP_0", first.to_dict())

    def test_le_contenu_clinique_est_conserve(self):
        path = next(RAW.glob("patient_*_crap.txt"))
        text = pseudonymize_text(path.read_text(encoding="utf-8"), MappingStore())
        self.assertIn("Ganglions examinés", text)
        self.assertRegex(text, r"pT\d")


if __name__ == "__main__":
    unittest.main()
