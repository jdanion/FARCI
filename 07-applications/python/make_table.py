#!/usr/bin/env python3
"""FARCI — génère un tableau comparatif des extractions."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load_results(extracted_dir: Path) -> list[dict]:
    """Charge tous les JSON d'extraction."""
    results = []
    for f in sorted(extracted_dir.glob("*.json")):
        with open(f, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        results.append(data)
    return results


def make_table(results: list[dict]) -> str:
    """Génère un tableau markdown."""
    if not results:
        return "Aucun résultat."

    fields = list(results[0].keys())
    lines = [
        "| " + " | ".join(fields) + " |",
        "|" + "|".join(["---"] * len(fields)) + "|",
    ]

    for r in results:
        row = [str(r.get(f, "")) for f in fields]
        lines.append("| " + " | ".join(row) + " |")

    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="FARCI — tableau comparatif")
    parser.add_argument("--input", type=Path, default=Path("datasets/extracted/python"))
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    results = load_results(args.input)
    table = make_table(results)

    if args.output:
        args.output.write_text(table, encoding="utf-8")
        print(f"Tableau sauvegardé : {args.output}")
    else:
        print(table)


if __name__ == "__main__":
    main()
