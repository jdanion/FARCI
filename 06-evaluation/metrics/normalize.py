"""FARCI — normalisation des valeurs avant comparaison.

Règles :
- Casse : insensible
- Accents : insensibles
- Unités : `20 mm` = `20`
- Booléens : `oui/non/true/false/0/1`
- Plages : `pT1b` → `pT1b`
- F1 : 0/1/2
"""

from __future__ import annotations

import re
import unicodedata


def normalize_text(value: str) -> str:
    """Normalise un texte : minuscules, sans accents, sans espaces multiples."""
    value = value.lower().strip()
    # Supprimer les accents
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    # Espaces multiples → un seul
    value = re.sub(r"\s+", " ", value)
    return value


def normalize_number(value) -> float | None:
    """Normalise un nombre : supprime unités et espaces."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    # Extraire le nombre d'une chaîne
    match = re.search(r"[\d.]+", str(value))
    return float(match.group()) if match else None


def normalize_boolean(value) -> bool | None:
    """Normalise un booléen."""
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    normalized = normalize_text(str(value))
    if normalized in ("oui", "true", "1", "yes"):
        return True
    if normalized in ("non", "false", "0", "no"):
        return False
    return None


def normalize_value(field: str, value):
    """Normalise une valeur selon son type de champ."""
    if value is None:
        return None

    # Champs numériques
    if field in ("age", "tumor_size_mm", "nodes_examined", "nodes_positive", "length_of_stay"):
        return normalize_number(value)

    # Champs booléens
    if field in ("venous_resection", "pancreatic_fistula", "delayed_gastrojejunostomy",
                 "hemorrhage", "readmission"):
        return normalize_boolean(value)

    # Champs texte
    if field in ("patient_id", "sex", "diagnosis", "procedure_type", "approach",
                 "histology", "pT", "pN", "margin_R"):
        return normalize_text(str(value)) if value else value

    return value
