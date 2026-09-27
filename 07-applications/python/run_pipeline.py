#!/usr/bin/env python3
"""FARCI — CLI du pipeline d'extraction (parcours Python).

Usage :
    python run_pipeline.py --input datasets/raw --output datasets/extracted/python
    python run_pipeline.py --input datasets/raw/patient_001.pdf --output datasets/extracted/python
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Ajouter le dossier parent au path pour importer common
sys.path.insert(0, str(Path(__file__).parent.parent))

from common.pipeline import process_pdf


def main():
    parser = argparse.ArgumentParser(description="FARCI — pipeline d'extraction")
    parser.add_argument("--input", type=Path, required=True, help="PDF ou dossier")
    parser.add_argument("--output", type=Path, default=Path("datasets/extracted/python"))
    parser.add_argument("--model", default="med-extraction")
    parser.add_argument("--prompt", default="v1", choices=["v1", "v2"])
    parser.add_argument("--temperature", type=float, default=0.0)
    args = parser.parse_args()

    if args.input.is_dir():
        pdfs = sorted(args.input.glob("*.pdf"))
        if not pdfs:
            print("ERREUR: aucun PDF trouvé")
            return 1
        for pdf in pdfs:
            output = process_pdf(pdf, args.output, args.model, args.prompt)
            print(f"OK {output}")
    else:
        output = process_pdf(args.input, args.output, args.model, args.prompt)
        print(f"OK {output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
