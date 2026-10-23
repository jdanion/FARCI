#!/usr/bin/env python3
"""FARCI — génère le dataset synthétique complet.

Produit 4 documents texte par cas dans datasets/raw/ (le dataset versionné,
utilisé par le pipeline de l'atelier) :
  - compte rendu opératoire
  - compte rendu anatomopathologique
  - compte rendu scanner
  - lettre de sortie

Le générateur est DÉTERMINISTE : même graine → mêmes fichiers (SHA256 identiques).

Avec --pdf, les mêmes documents sont rendus en PDF dans datasets/pdf/ (hors
Git) pour la démonstration Docling.

Usage :
    ./bin/farci generate-dataset              # 20 cas, .txt -> datasets/raw/
    ./bin/farci generate-dataset --quick      # 10 cas
    ./bin/farci generate-dataset --pdf        # PDF -> datasets/pdf/ (fpdf2 requis)
    ./bin/farci generate-dataset --check      # empreinte du répertoire
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

# Ajouter le dossier parent au path pour importer cases
sys.path.insert(0, str(Path(__file__).parent))

from cases import CASES, compute_checksum, quick_set
from render_pdf import render_case_pdfs


def compute_dir_checksum(directory: Path) -> str:
    """Calcule un checksum déterministe de tous les fichiers d'un dossier."""
    h = hashlib.sha256()
    for f in sorted(directory.iterdir()):
        if f.is_file():
            h.update(f.name.encode())
            h.update(f.read_bytes())
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description="Génère le dataset synthétique FARCI")
    parser.add_argument("--quick", action="store_true", help="10 cas seulement")
    parser.add_argument("--check", action="store_true", help="Vérifier l'intégrité")
    parser.add_argument("--pdf", action="store_true", help="PDF dans datasets/pdf/ (démo Docling)")
    parser.add_argument("--output", type=Path, default=None, help="Répertoire de sortie")
    args = parser.parse_args()

    script_dir = Path(__file__).parent.parent
    fmt = "pdf" if args.pdf else "txt"
    output_dir = args.output or script_dir / ("pdf" if args.pdf else "raw")
    output_dir.mkdir(parents=True, exist_ok=True)

    if args.check:
        current = compute_dir_checksum(output_dir)
        print(f"Checksum répertoire: {current}")
        return 0

    cases = quick_set() if args.quick else CASES
    count = 0
    for case in cases:
        render_case_pdfs(case, output_dir, fmt)
        count += 1

    final_checksum = compute_dir_checksum(output_dir)
    print(f"Dataset généré: {count} cas → {output_dir}")
    print(f"Checksum dataset: {final_checksum}")
    print(f"Checksum registre: {compute_checksum()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
