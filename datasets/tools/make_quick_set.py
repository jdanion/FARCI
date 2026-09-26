#!/usr/bin/env python3
"""FARCI — crée le sous-ensemble quick (10 premiers cas).

Le quick set est inclus dans le full set : ce sont les 10 premiers cas.
Ce script vérifie simplement que le sous-ensemble est bien contenu dans
l'ensemble complet.

Usage :
    python datasets/tools/make_quick_set.py              # afficher le quick set
    python datasets/tools/make_quick_set.py --check      # vérifier l'inclusion
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from cases import CASES, quick_set


def main():
    parser = argparse.ArgumentParser(description="Gère le sous-ensemble quick FARCI")
    parser.add_argument("--check", action="store_true", help="Vérifier l'inclusion")
    args = parser.parse_args()

    quick = quick_set()

    if args.check:
        full_ids = {c.patient_id for c in CASES}
        quick_ids = {c.patient_id for c in quick}
        if quick_ids.issubset(full_ids):
            print(f"OK: quick set ({len(quick_ids)} cas) ⊂ full set ({len(full_ids)} cas)")
            return 0
        else:
            print("ERREUR: quick set n'est pas inclus dans le full set")
            return 1

    print(f"Quick set: {len(quick)} cas")
    for c in quick:
        print(f"  {c.patient_id} - {c.prenom} {c.nom} - {c.diagnosis}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
