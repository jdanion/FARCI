"""FARCI — validation d'une extraction contre le schéma JSON (stdlib seulement).

Le contrat est `datasets/schemas/clinical_extraction.schema.json`. Ce module en
vérifie le sous-ensemble réellement utilisé (type, enum, minimum, maximum,
required) sans dépendre de la bibliothèque `jsonschema`, absente en air-gap.

Règle d'évaluation :
  - un champ requis absent, d'un mauvais type ou hors énumération rend le
    dossier INVALIDE ;
  - les clés commençant par « _ » sont des métadonnées (`_meta` : latence,
    modèle, prompt) et sont ignorées ;
  - une autre clé hors schéma est signalée mais n'invalide pas le dossier
    (le gold contient par exemple le NIR, qui n'est pas une variable extraite).
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "datasets" / "schemas" / "clinical_extraction.schema.json"

_JSON_TYPES = {
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "null": type(None),
    "object": dict,
    "array": list,
}


def load_schema(path: Path = SCHEMA_PATH) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def _type_ok(value, expected) -> bool:
    names = expected if isinstance(expected, list) else [expected]
    for name in names:
        python_type = _JSON_TYPES[name]
        # En JSON, true n'est pas un entier : bool hérite de int en Python.
        if isinstance(value, bool) and name in ("integer", "number"):
            continue
        if name == "integer" and isinstance(value, float) and not value.is_integer():
            continue
        if isinstance(value, python_type):
            return True
    return False


def validate(data, schema: dict | None = None) -> list[str]:
    """Liste des erreurs de conformité (vide = dossier valide)."""
    schema = schema or load_schema()
    if not isinstance(data, dict):
        return ["la réponse n'est pas un objet JSON"]

    errors: list[str] = []
    properties = schema.get("properties", {})
    for field in schema.get("required", []):
        if field not in data:
            errors.append(f"{field} : champ requis absent")

    for field, value in data.items():
        if field.startswith("_") or field not in properties:
            continue
        rules = properties[field]
        if "type" in rules and not _type_ok(value, rules["type"]):
            errors.append(f"{field} : type {type(value).__name__} au lieu de {rules['type']}")
            continue
        if "enum" in rules and value not in rules["enum"]:
            errors.append(f"{field} : {value!r} hors énumération {rules['enum']}")
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if "minimum" in rules and value < rules["minimum"]:
                errors.append(f"{field} : {value} < minimum {rules['minimum']}")
            if "maximum" in rules and value > rules["maximum"]:
                errors.append(f"{field} : {value} > maximum {rules['maximum']}")
    return errors


def extra_fields(data: dict, schema: dict | None = None) -> list[str]:
    """Clés hors schéma (hors métadonnées « _ »), pour information."""
    schema = schema or load_schema()
    properties = schema.get("properties", {})
    return sorted(k for k in data if not k.startswith("_") and k not in properties)
