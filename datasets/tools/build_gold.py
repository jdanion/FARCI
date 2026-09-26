#!/usr/bin/env python3
"""FARCI — génère le gold standard depuis le registre des cas.

RÈGLE ABSOLUE (FARCI §27) : le gold standard n'est JAMAIS produit par un LLM.
Il est écrit directement depuis le registre structuré cases.py.

Usage :
    python datasets/tools/build_gold.py              # tous les cas
    python datasets/tools/build_gold.py --quick      # 10 cas seulement
    python datasets/tools/build_gold.py --check      # vérifier l'intégrité
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

# Ajouter le dossier parent au path pour importer cases
sys.path.insert(0, str(Path(__file__).parent))

from cases import CASES, compute_checksum, get_case, quick_set


def case_to_gold(case) -> dict:
    """Convertit un cas en dictionnaire gold."""
    return {
        "patient_id": case.patient_id,
        "nir": case.nir,
        "age": case.age,
        "sex": case.sex,
        "diagnosis": case.diagnosis,
        "procedure_type": case.procedure_type,
        "approach": case.approach,
        "venous_resection": case.venous_resection,
        "tumor_size_mm": case.tumor_size_mm,
        "histology": case.histology,
        "pT": case.pT,
        "pN": case.pN,
        "nodes_examined": case.nodes_examined,
        "nodes_positive": case.nodes_positive,
        "margin_R": case.margin_R,
        "pancreatic_fistula": case.pancreatic_fistula,
        "delayed_gastrojejunostomy": case.delayed_gastrojejunostomy,
        "hemorrhage": case.hemorrhage,
        "length_of_stay": case.length_of_stay,
        "readmission": case.readmission,
    }


def build_gold(output_dir: Path, cases: list, checksum: str) -> int:
    """Écrit les fichiers gold JSON."""
    output_dir.mkdir(parents=True, exist_ok=True)
    count = 0

    for case in cases:
        gold = case_to_gold(case)
        # Métadonnées d'intégrité
        gold["_meta"] = {
            "checksum": checksum,
            "generator": "build_gold.py",
            "source": "cases.py (registre structuré)",
        }
        filepath = output_dir / f"patient_{case.patient_id}.json"
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(gold, f, ensure_ascii=False, indent=2)
            f.write("\n")
        count += 1

    return count


def verify_gold(gold_dir: Path, expected_checksum: str) -> tuple[int, int]:
    """Vérifie l'intégrité des fichiers gold existants."""
    ok = 0
    fail = 0
    for f in sorted(gold_dir.glob("patient_*.json")):
        try:
            with open(f, "r", encoding="utf-8") as fh:
                data = json.load(fh)
            if data.get("_meta", {}).get("checksum") == expected_checksum:
                ok += 1
            else:
                print(f"CHECKSUM MISMATCH: {f.name}")
                fail += 1
        except Exception as e:
            print(f"ERREUR: {f.name}: {e}")
            fail += 1
    return ok, fail


def main():
    parser = argparse.ArgumentParser(description="Génère le gold standard FARCI")
    parser.add_argument("--quick", action="store_true", help="10 cas seulement")
    parser.add_argument("--check", action="store_true", help="Vérifier l'intégrité")
    parser.add_argument("--output", type=Path, default=None, help="Répertoire de sortie")
    args = parser.parse_args()

    script_dir = Path(__file__).parent.parent
    output_dir = args.output or script_dir / "gold"
    checksum = compute_checksum()

    if args.check:
        ok, fail = verify_gold(output_dir, checksum)
        print(f"Vérification: {ok} OK, {fail} échec(s)")
        return 1 if fail > 0 else 0

    cases = quick_set() if args.quick else CASES
    count = build_gold(output_dir, cases, checksum)
    print(f"Gold standard généré: {count} cas → {output_dir}")
    print(f"Checksum registre: {checksum}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
