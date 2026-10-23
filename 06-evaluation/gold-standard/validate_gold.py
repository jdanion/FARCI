#!/usr/bin/env python3
"""FARCI — validation du gold standard.

Vérifie que chaque fichier de datasets/gold/ est conforme au schéma
d'extraction (datasets/schemas/clinical_extraction.schema.json) et que son
nom correspond à son patient_id.

Usage :
    python3 06-evaluation/gold-standard/validate_gold.py [--gold-dir DIR]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GOLD_DIR = ROOT / "datasets" / "gold"
sys.path.insert(0, str(ROOT / "06-evaluation" / "metrics"))

from schema_check import load_schema, validate  # noqa: E402


def validate_gold_file(path: Path, schema: dict) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"JSON invalide : {exc}"]
    errors = validate(data, schema)
    if isinstance(data, dict) and path.stem != f"patient_{data.get('patient_id')}":
        errors.append(f"nom de fichier différent du patient_id {data.get('patient_id')!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="FARCI — validation du gold standard")
    parser.add_argument("--gold-dir", type=Path, default=GOLD_DIR)
    args = parser.parse_args()

    gold_files = sorted(args.gold_dir.glob("patient_*.json"))
    if not gold_files:
        print(f"ERREUR : aucun fichier gold dans {args.gold_dir}")
        return 1

    schema = load_schema()
    total_errors = 0
    for path in gold_files:
        errors = validate_gold_file(path, schema)
        total_errors += len(errors)
        print(f"{'ERREUR' if errors else 'OK'} {path.name}")
        for error in errors:
            print(f"  - {error}")

    if total_errors:
        print(f"\n{total_errors} erreur(s)")
        return 1
    print(f"\n{len(gold_files)} fichier(s) gold conformes au schéma")
    return 0


if __name__ == "__main__":
    sys.exit(main())
