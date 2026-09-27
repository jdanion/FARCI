#!/usr/bin/env python3
"""FARCI — validation du gold standard.

Vérifie que les fichiers gold sont conformes au schéma et cohérents.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

GOLD_DIR = Path(__file__).parent.parent / "datasets" / "gold"

REQUIRED_FIELDS = [
    "patient_id", "age", "sex", "diagnosis",
    "procedure_type", "approach", "venous_resection",
    "tumor_size_mm", "histology", "pT", "pN",
    "nodes_examined", "nodes_positive", "margin_R",
    "pancreatic_fistula", "delayed_gastrojejunostomy", "hemorrhage",
    "length_of_stay", "readmission",
]


def validate_gold_file(path: Path) -> list[str]:
    """Valide un fichier gold. Retourne la liste des erreurs."""
    errors = []

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"JSON invalide: {e}"]

    # Vérifier les champs requis
    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(f"champ manquant: {field}")

    # Vérifier les types
    if "age" in data and not isinstance(data["age"], int):
        errors.append("age doit être un entier")
    if "sex" in data and data["sex"] not in ("M", "F"):
        errors.append("sex doit être 'M' ou 'F'")
    if "length_of_stay" in data and not isinstance(data["length_of_stay"], int):
        errors.append("length_of_stay doit être un entier")

    return errors


def main():
    gold_files = sorted(GOLD_DIR.glob("patient_*.json"))
    if not gold_files:
        print("ERREUR: aucun fichier gold trouvé")
        return 1

    total_errors = 0
    for f in gold_files:
        errors = validate_gold_file(f)
        if errors:
            total_errors += len(errors)
            print(f"ERREUR {f.name}:")
            for e in errors:
                print(f"  - {e}")
        else:
            print(f"OK {f.name}")

    if total_errors > 0:
        print(f"\n{total_errors} erreur(s) totale(s)")
        return 1

    print(f"\n{len(gold_files)} fichier(s) gold valide(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
