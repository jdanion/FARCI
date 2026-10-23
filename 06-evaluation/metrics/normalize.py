"""FARCI — normalisation des valeurs avant comparaison.

Règles :
- texte : insensible à la casse, aux accents et aux espaces multiples
- nombres : `20 mm` = `20` = `20.0`, la virgule décimale est acceptée
- booléens : `oui/non/true/false/1/0/yes/no`
- `null` reste `null` : « non précisé » est une réponse, pas une absence
"""

from __future__ import annotations

import re
import unicodedata

NUMBER_FIELDS = ("age", "tumor_size_mm", "nodes_examined", "nodes_positive", "length_of_stay")
BOOLEAN_FIELDS = (
    "venous_resection", "pancreatic_fistula", "delayed_gastrojejunostomy",
    "hemorrhage", "readmission",
)


def field_type(field: str) -> str:
    if field in NUMBER_FIELDS:
        return "number"
    if field in BOOLEAN_FIELDS:
        return "boolean"
    return "text"


def normalize_text(value) -> str:
    """Minuscules, sans accents, sans espaces multiples (œ -> oe)."""
    text = str(value).lower().strip().replace("œ", "oe").replace("æ", "ae")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", text)


def normalize_number(value) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    match = re.search(r"-?\d+(?:[.,]\d+)?", str(value))
    return float(match.group().replace(",", ".")) if match else None


def normalize_boolean(value) -> bool | None:
    if isinstance(value, bool):
        return value
    text = normalize_text(value)
    if text in ("oui", "true", "1", "yes", "vrai"):
        return True
    if text in ("non", "false", "0", "no", "faux"):
        return False
    return None


def normalize_value(field: str, value):
    """Normalise une valeur selon le TYPE du champ nommé `field`."""
    if value is None:
        return None
    kind = field_type(field)
    if kind == "number":
        return normalize_number(value)
    if kind == "boolean":
        return normalize_boolean(value)
    return normalize_text(value)
