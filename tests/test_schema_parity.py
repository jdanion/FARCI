"""Parité du contrat d'extraction : le schéma JSON, le modèle Pydantic, les
métriques, les prompts et le gold décrivent EXACTEMENT les mêmes champs.

Une divergence ici fausse silencieusement les scores de l'étape 2 (FARCI R8)."""

from __future__ import annotations

import json
import re
import unittest

from _paths import HAS_PYDANTIC, ROOT

from metrics import EXTRACTION_FIELDS
from schema_check import load_schema, validate

SCHEMA = load_schema()
PROPERTIES = SCHEMA["properties"]
PROMPTS = sorted((ROOT / "07-applications" / "common" / "prompts").glob("extraction_v*.md"))
GOLD_FILES = sorted((ROOT / "datasets" / "gold").glob("patient_*.json"))


class SchemaJson(unittest.TestCase):
    def test_copies_identiques(self):
        copy = ROOT / "04-clinical-documents" / "schemas" / "clinical_extraction.schema.json"
        self.assertEqual(json.loads(copy.read_text(encoding="utf-8")), SCHEMA)

    def test_tous_les_champs_requis(self):
        self.assertEqual(sorted(SCHEMA["required"]), sorted(PROPERTIES))

    def test_metriques(self):
        self.assertEqual(sorted(EXTRACTION_FIELDS), sorted(PROPERTIES))


class Prompts(unittest.TestCase):
    def test_chaque_prompt_liste_le_schema(self):
        self.assertTrue(PROMPTS)
        for prompt in PROMPTS:
            text = prompt.read_text(encoding="utf-8")
            block = re.search(r"```json\s*(\{.*?\})\s*```", text, flags=re.DOTALL)
            self.assertIsNotNone(block, f"{prompt.name} : bloc ```json absent")
            self.assertEqual(sorted(json.loads(block.group(1))), sorted(PROPERTIES), prompt.name)

    def test_enumerations_du_prompt(self):
        for prompt in PROMPTS:
            described = json.loads(re.search(r"```json\s*(\{.*?\})\s*```",
                                             prompt.read_text(encoding="utf-8"),
                                             flags=re.DOTALL).group(1))
            for field, rules in PROPERTIES.items():
                if "enum" not in rules:
                    continue
                expected = {"null" if v is None else str(v).lower() for v in rules["enum"]}
                self.assertEqual({v.lower() for v in described[field].split("|")}, expected,
                                 f"{prompt.name} : {field}")


class Gold(unittest.TestCase):
    def test_vingt_dossiers_conformes(self):
        self.assertEqual(len(GOLD_FILES), 20)
        for path in GOLD_FILES:
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(validate(data, SCHEMA), [], path.name)
            self.assertEqual(path.stem, f"patient_{data['patient_id']}")


@unittest.skipUnless(HAS_PYDANTIC, "pydantic absent (pip install -r requirements.txt)")
class Pydantic(unittest.TestCase):
    def setUp(self):
        from common.schemas import ClinicalExtraction

        self.model = ClinicalExtraction

    def test_memes_champs_tous_requis(self):
        fields = self.model.model_fields
        self.assertEqual(sorted(fields), sorted(PROPERTIES))
        self.assertEqual(sorted(n for n, f in fields.items() if f.is_required()), sorted(PROPERTIES))

    def test_memes_enumerations(self):
        base = json.loads(GOLD_FILES[0].read_text(encoding="utf-8"))
        for field, rules in PROPERTIES.items():
            if "enum" not in rules:
                continue
            for value in rules["enum"]:
                self.model(**{**base, field: value})  # chaque valeur du schéma passe
            with self.assertRaises(Exception, msg=f"{field} : valeur hors schéma acceptée"):
                self.model(**{**base, field: "hors-schema"})

    def test_le_gold_passe_pydantic(self):
        for path in GOLD_FILES:
            data = json.loads(path.read_text(encoding="utf-8"))
            self.model(**data)


if __name__ == "__main__":
    unittest.main()
