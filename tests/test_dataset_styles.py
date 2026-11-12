"""Les quatre styles d'écriture des dossiers et les consignes d'extraction.

Un jeu de formulaires « champ : valeur » ne départage ni les modèles ni les
consignes. Ces tests gardent ce qui rend la comparaison possible : des styles
réellement différents, des pièges présents, un gold inchangé, et des consignes
qui portent toutes le même schéma."""

from __future__ import annotations

import json
import re
import unittest

from _paths import ROOT

from cases import CASES, quick_set
from deidentification import MappingStore, pseudonymize_text
from styles import STYLE_BY_RANK, STYLES, en_lettres, render_documents, style_of

RAW = ROOT / "datasets" / "raw"
PROMPTS = ROOT / "07-applications" / "common" / "prompts"
IDENTITE = re.compile(r"^(Patient|IPP|NIR|Date de naissance) :")


def dossier(case) -> str:
    return "\n".join(p.read_text(encoding="utf-8") for p in sorted(RAW.glob(f"patient_{case.patient_id}_*.txt")))


class Styles(unittest.TestCase):
    def test_cinq_dossiers_par_style(self):
        for style in STYLES:
            self.assertEqual(sum(1 for s in STYLE_BY_RANK.values() if s == style), 5, style)
        self.assertEqual(style_of(CASES[0].patient_id), "formulaire")
        self.assertEqual(style_of(CASES[19].patient_id), "pieges")
        self.assertEqual(style_of("inconnu"), "formulaire")

    def test_le_jeu_rapide_couvre_les_quatre_styles(self):
        quick = quick_set()
        self.assertEqual(len(quick), 10)
        self.assertEqual({style_of(c.patient_id) for c in quick}, set(STYLES))

    def test_le_dataset_versionne_est_celui_du_generateur(self):
        for case in CASES:
            documents = render_documents(case)
            if documents is None:
                continue
            for kind, text in documents.items():
                path = RAW / f"patient_{case.patient_id}_{kind}.txt"
                self.assertEqual(path.read_text(encoding="utf-8"), text, path.name)

    def test_seul_le_formulaire_donne_les_champs_tout_faits(self):
        for rank, case in enumerate(CASES):
            text = dossier(case)
            if STYLE_BY_RANK[rank] == "formulaire":
                self.assertIn("Voie d'abord :", text)
            else:
                for label in ("Voie d'abord :", "Résection veineuse :", "Durée de séjour :", "Sexe :", "Âge :"):
                    self.assertNotIn(label, text, f"{case.patient_id} : {label}")

    def test_la_pseudonymisation_ne_touche_que_l_identite(self):
        # Un mot clinique pris pour un nom par le dictionnaire fausserait l'extraction.
        for path in sorted(RAW.glob("patient_*.txt")):
            text = pseudonymize_text(path.read_text(encoding="utf-8"), MappingStore())
            for line in text.splitlines():
                if "[" in line:
                    self.assertRegex(line, IDENTITE, f"{path.name} : {line}")

    def test_les_pieges_sont_la(self):
        for rank in range(15, 20):
            case, text = CASES[rank], dossier(CASES[rank])
            self.assertIn("Antécédents :", text)
            self.assertIn("soins de suite", text)
            self.assertIn("7e édition", text)
            # Le scanner ne donne pas la taille retenue par le registre.
            scanner = (RAW / f"patient_{case.patient_id}_crscan.txt").read_text(encoding="utf-8")
            self.assertNotIn(f" {int(case.tumor_size_mm)} mm", scanner)
            if not case.pancreatic_fistula:
                self.assertIn("fuite biochimique", text)
            if not case.hemorrhage:
                self.assertIn("écartée", text)
            if not case.readmission:
                self.assertIn("Consultation non programmée", text)

    def test_la_valeur_du_registre_reste_dans_le_texte(self):
        # Chaque style écrit la valeur autrement, mais elle y est : le gold reste atteignable.
        for rank in range(5, 20):
            case, text = CASES[rank], dossier(CASES[rank])
            self.assertRegex(text, rf"\b{case.age} (ans|a\.)", case.patient_id)
            self.assertRegex(text, rf"p?T{case.pT[2:]}", case.patient_id)
            self.assertIn(str(case.nodes_examined), text)
            self.assertIn(case.margin_R, text.replace("saines (R0)", "R0") if case.margin_R in text else
                          {"R0": "R0", "R1": "R1", "R2": "R2"}[case.margin_R]
                          if re.search("tissu sain|microscopiquement|macroscopique", text) else text)
            size = int(case.tumor_size_mm)
            self.assertTrue(f"{size} mm" in text or f"{size / 10:.1f}".replace(".", ",") + " cm" in text
                            or f"x {size} x" in text, case.patient_id)
            self.assertTrue(f"J{case.length_of_stay}" in text or en_lettres(case.length_of_stay) in text, case.patient_id)

    def test_en_lettres(self):
        self.assertEqual([en_lettres(n) for n in (0, 7, 16, 21, 28, 71, 80, 94)],
                         ["zéro", "sept", "seize", "vingt et un", "vingt-huit", "soixante et onze",
                          "quatre-vingts", "quatre-vingt-quatorze"])


class Consignes(unittest.TestCase):
    NOMS = ("naif", "prudent", "exhaustif", "clinique", "exemples", "v1", "v2")

    def test_chaque_consigne_porte_le_meme_schema(self):
        reference = None
        for nom in self.NOMS:
            text = (PROMPTS / f"extraction_{nom}.md").read_text(encoding="utf-8")
            self.assertIn(f"prompt d'extraction {nom}", text.splitlines()[0])
            self.assertIn("{{text}}", text)
            schema = json.loads(text.split("## Schéma", 1)[1].split("```json", 1)[1].split("```", 1)[0])
            reference = reference or schema
            self.assertEqual(schema, reference, nom)

    def test_les_consignes_sont_vraiment_differentes(self):
        corps = {}
        for nom in self.NOMS[:5]:
            text = (PROMPTS / f"extraction_{nom}.md").read_text(encoding="utf-8")
            self.assertIn("Stratégie :", text, nom)
            corps[nom] = text.split("## Schéma", 1)[0]
        self.assertEqual(len(set(corps.values())), 5)
        self.assertIn("fuite", corps["clinique"])
        self.assertIn("dans le doute, `true`", corps["exhaustif"])
        self.assertIn("Au moindre doute", corps["prudent"])
        self.assertNotIn("## Règles", corps["naif"])

    def test_l_exemple_n_est_pas_un_dossier_du_jeu(self):
        exemple = (PROMPTS / "extraction_exemples.md").read_text(encoding="utf-8")
        for case in CASES:
            self.assertNotIn(case.patient_id, exemple)
            self.assertNotIn(case.nom, exemple)

    def test_le_modele_ne_recoit_pas_la_strategie(self):
        import importlib.util
        if importlib.util.find_spec("pydantic") is None:
            self.skipTest("pydantic absent")
        from common.pipeline import available_prompts, render_prompt
        self.assertEqual(set(available_prompts()), set(self.NOMS))
        for nom in self.NOMS:
            rendu = render_prompt(nom)
            self.assertNotIn("Stratégie", rendu)
            self.assertNotIn("<!--", rendu)
            self.assertNotIn("{{text}}", rendu)


if __name__ == "__main__":
    unittest.main()
