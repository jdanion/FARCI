#!/usr/bin/env python3
"""FARCI — validation de scripts/suite.def (« Ensuite : » après chaque commande).

Ce que l'on garantit :
- chaque ligne a exactement 4 champs (clé, quand, commande, pourquoi) ;
- « quand » vaut ok, echec ou tout ;
- la clé commence par une cible de scripts/targets.def, ou par un script du
  dépôt lancé directement (00-gitops/gitea/bootstrap.sh…) ;
- chaque cible a au moins une suggestion en cas de succès ;
- chaque commande suggérée existe : « ./bin/farci X » est une cible, un
  chemin (./preload.sh, 00-gitops/…) est un fichier du dépôt.
"""

from __future__ import annotations

import os
import sys

ROOT = os.environ.get("FARCI_ROOT", os.getcwd())
SUITE = os.path.join(ROOT, "scripts", "suite.def")
TARGETS = os.path.join(ROOT, "scripts", "targets.def")


def targets() -> set[str]:
    names = set()
    with open(TARGETS, encoding="utf-8") as handle:
        for line in handle:
            if line.strip() and not line.startswith("#"):
                names.add(line.split("\t", 1)[0])
    return names


def command_problem(command: str, known: set[str]) -> str | None:
    words = command.split()
    if not words or words[0].startswith("http") or words[0] == "git":
        return None
    if words[0] == "./bin/farci":
        if len(words) < 2 or words[1] not in known:
            return f"cible inconnue : {command}"
        return None
    if "/" in words[0]:
        path = os.path.join(ROOT, words[0].removeprefix("./"))
        if not os.path.isfile(path):
            return f"script introuvable : {words[0]}"
        return None
    return f"commande non reconnue (./bin/farci, script du dépôt, git ou URL) : {command}"


def main() -> int:
    known = targets()
    problems: list[str] = []
    with_ok: set[str] = set()
    with open(SUITE, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.split("\t")
            where = f"suite.def:{number}"
            if len(fields) != 4 or not all(f.strip() for f in fields):
                problems.append(f"{where} : 4 champs non vides séparés par des TAB attendus")
                continue
            key, when, command, _ = fields
            if when not in ("ok", "echec", "tout"):
                problems.append(f"{where} : quand = {when!r} (ok, echec ou tout)")
            head = key.split()[0]
            if head not in known and not os.path.isfile(os.path.join(ROOT, head)):
                problems.append(f"{where} : clé {key!r} : ni une cible ni un script du dépôt")
            if when in ("ok", "tout") and " " not in key:
                with_ok.add(key)
            problem = command_problem(command, known)
            if problem:
                problems.append(f"{where} : {problem}")
    for name in sorted(known - with_ok):
        problems.append(f"cible sans suggestion après succès : {name} (ajouter une ligne « {name}\tok\t… »)")
    for problem in problems:
        print(f"KO   {problem}", file=sys.stderr)
    if problems:
        return 1
    print(f"suite.def cohérent : {len(with_ok)} cibles ont leur « Ensuite : »")
    return 0


if __name__ == "__main__":
    sys.exit(main())
