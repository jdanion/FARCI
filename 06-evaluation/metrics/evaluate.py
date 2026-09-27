#!/usr/bin/env python3
"""FARCI — évaluation des extractions (FARCI §34).

Compare les extractions de `datasets/extracted/` avec le gold standard
de `datasets/gold/`.

Usage :
    python 06-evaluation/metrics/evaluate.py
    python 06-evaluation/metrics/evaluate.py --runs python flowise
    python 06-evaluation/metrics/evaluate.py --gold-dir datasets/gold --extracted-dir datasets/extracted
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .metrics import compute_metrics, EXTRACTION_FIELDS
from .report import render_report


def load_json(path: Path) -> dict:
    """Charge un fichier JSON."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def evaluate(gold_dir: Path, extracted_dir: Path, runs: list[str] | None = None) -> dict:
    """Évalue les extractions contre le gold standard."""
    gold_files = sorted(gold_dir.glob("patient_*.json"))
    results = {
        "nb_dossiers": len(gold_files),
        "completude": 0,
        "json_valides": 0,
        "runs": [],
    }

    all_micro = []

    for gold_file in gold_files:
        patient_id = gold_file.stem.replace("patient_", "")
        gold = load_json(gold_file)

        # Chercher l'extraction correspondante
        extracted = None
        if runs:
            for run in runs:
                candidate = extracted_dir / run / f"patient_{patient_id}.json"
                if candidate.exists():
                    extracted = load_json(candidate)
                    break
        else:
            candidate = extracted_dir / f"patient_{patient_id}.json"
            if candidate.exists():
                extracted = load_json(candidate)

        if extracted:
            results["json_valides"] += 1
            metrics = compute_metrics(gold, extracted)
            all_micro.append(metrics["micro"])
            results["runs"].append({
                "patient_id": patient_id,
                "f1": metrics["micro"]["f1"],
            })

    # Agréger
    if all_micro:
        results["completude"] = results["json_valides"] / results["nb_dossiers"] if results["nb_dossiers"] > 0 else 0
        results["precision"] = sum(m["precision"] for m in all_micro) / len(all_micro)
        results["recall"] = sum(m["recall"] for m in all_micro) / len(all_micro)
        results["f1"] = sum(m["f1"] for m in all_micro) / len(all_micro)

    return results


def main():
    parser = argparse.ArgumentParser(description="FARCI — évaluation des extractions")
    parser.add_argument("--gold-dir", type=Path, default=Path("datasets/gold"))
    parser.add_argument("--extracted-dir", type=Path, default=Path("datasets/extracted"))
    parser.add_argument("--runs", nargs="*", default=None)
    args = parser.parse_args()

    results = evaluate(args.gold_dir, args.extracted_dir, args.runs)
    print(json.dumps(results, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
