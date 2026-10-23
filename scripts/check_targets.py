#!/usr/bin/env python3
"""FARCI — validation du registre des cibles (scripts/targets.def).

Ce fichier est la source de vérité de deux points d'entrée : la Makefile et
./bin/farci. Une seule tabulation en trop suffisait à faire disparaître une
cible SILENCIEUSEMENT (awk -F'\\t' voit alors 5 champs, le filtre les ignore).
Ce contrôle existe pour que cette erreur ne puisse plus être silencieuse.

Format attendu, une ligne par cible, champs séparés par exactement un TAB :
    nom <TAB> groupe <TAB> description <TAB> script
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.environ.get("FARCI_ROOT", os.getcwd())
DEFINITIONS = os.path.join(ROOT, "scripts", "targets.def")
CMD_DIR = os.path.join(ROOT, "scripts", "cmd")
NAME_RE = re.compile(r"[a-z][a-z0-9-]*")


def help_groups() -> set[str]:
    """Groupes que help.sh sait afficher : lus dans sa ligne GROUP_ORDER=(...),
    pour qu'il n'existe qu'une seule liste."""
    help_sh = os.path.join(CMD_DIR, "help.sh")
    with open(help_sh, encoding="utf-8") as handle:
        match = re.search(r"^GROUP_ORDER=\(([^)]*)\)", handle.read(), flags=re.MULTILINE)
    return set(match.group(1).split()) if match else set()


def main() -> int:
    if not os.access(DEFINITIONS, os.R_OK):
        print(f"registre de cibles introuvable : {DEFINITIONS}", file=sys.stderr)
        return 1

    problems: list[str] = []
    targets: list[tuple[str, str]] = []
    groups: set[str] = set()

    with open(DEFINITIONS, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, start=1):
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            fields = [field for field in re.split(r"\t+", raw.strip()) if field]
            if len(fields) != 4:
                problems.append(
                    f"ligne {number}: {len(fields)} champ(s) au lieu de 4 "
                    f"(séparateurs TAB, pas espaces) -> {raw.strip()!r}"
                )
                continue
            name, group, description, script = fields
            if not NAME_RE.fullmatch(name):
                problems.append(f"ligne {number}: nom de cible invalide {name!r} (kebab-case attendu)")
            if not description:
                problems.append(f"ligne {number}: description vide pour {name}")
            if not NAME_RE.fullmatch(script.removesuffix(".sh")):
                problems.append(f"ligne {number}: nom de script invalide {script!r}")
            groups.add(group)
            targets.append((name, script))

    names = [name for name, _ in targets]
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        problems.append(f"cibles en double : {', '.join(duplicates)}")

    for name, script in targets:
        path = os.path.join(CMD_DIR, script)
        if not os.access(path, os.R_OK):
            problems.append(f"cible {name} : scripts/cmd/{script} absent")
        elif not os.access(path, os.X_OK):
            problems.append(f"cible {name} : scripts/cmd/{script} n'est pas exécutable")

    # Les groupes déclarés ici doivent être ceux que help.sh sait afficher,
    # sinon des cibles seraient présentes mais invisibles.
    known_groups = help_groups()
    for group in sorted(groups - known_groups):
        problems.append(
            f"groupe inconnu {group!r} : l'ajouter à GROUP_ORDER et GROUP_TITLES (scripts/cmd/help.sh)"
        )

    if problems:
        for problem in problems:
            print(f"PROBLEME : {problem}", file=sys.stderr)
        return 1

    print(f"{len(targets)} cibles valides, {len(groups)} groupes, tous les scripts exécutables")
    return 0


if __name__ == "__main__":
    sys.exit(main())
