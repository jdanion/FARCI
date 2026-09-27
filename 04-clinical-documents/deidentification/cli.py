#!/usr/bin/env python3
"""FARCI — CLI de pseudonymisation.

Usage :
    python -m deidentification.cli input.txt output.txt
    python -m deidentification.cli --mapping mapping.json input.txt output.txt
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .mapping import MappingStore
from .rules import pseudonymize_text


def main():
    parser = argparse.ArgumentParser(description="FARCI — pseudonymisation de documents")
    parser.add_argument("input", type=Path, help="Fichier d'entrée")
    parser.add_argument("output", type=Path, help="Fichier de sortie")
    parser.add_argument("--mapping", type=Path, default=None, help="Fichier de mapping (JSON)")
    args = parser.parse_args()

    # Charger ou créer le mapping
    if args.mapping and args.mapping.exists():
        mapping = MappingStore.load(args.mapping)
    else:
        mapping = MappingStore()

    # Lire le fichier d'entrée
    text = args.input.read_text(encoding="utf-8")

    # Pseudonymiser
    result = pseudonymize_text(text, mapping)

    # Écrire le fichier de sortie
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result, encoding="utf-8")

    # Sauvegarder le mapping
    mapping_path = args.mapping or args.output.parent / "mapping.json"
    mapping.save(mapping_path)

    print(f"Pseudonymisation terminée : {args.output}")
    print(f"Mapping sauvegardé : {mapping_path}")


if __name__ == "__main__":
    main()
