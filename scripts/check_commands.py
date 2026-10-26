#!/usr/bin/env python3
"""FARCI — la documentation ne cite que des commandes qui existent.

Un étudiant qui recopie une commande de la doc et obtient « cible inconnue »
perd dix minutes et la confiance dans le reste du document. Ce contrôle lit
tous les .md (sauf les documents historiques : cahier des charges, plan,
journal des versions publiées) et vérifie :

  - `./bin/farci <cible>` et `make <cible>`  -> la cible est dans targets.def ;
  - `./chaos/chaos.sh <commande>`             -> commande connue, scénario existant ;
  - `./preload.sh --option`                   -> option présente dans son aide ;
  - un chemin de script ou de test cité (`scripts/…`, `tests/…`, `./xxx.sh`,
    `chaos/…`, `0X-…/…`)                       -> le fichier existe.

Sortie : une ligne par problème, code 1 s'il y en a.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("FARCI_ROOT", Path(__file__).resolve().parents[1]))

# Documents qui décrivent l'intention ou l'histoire, pas l'état du dépôt.
HISTORICAL = {"FARCI.md", "PLAN.md"}

FARCI_RE = re.compile(r"(?:\./bin/farci|\bmake)\s+([a-z][a-z0-9-]*)")
CHAOS_RE = re.compile(r"\./chaos/chaos\.sh\s+([a-z0-9-]+)")
PATH_RE = re.compile(
    r"(?<![\w/.-])((?:\./)?(?:scripts|tests|chaos|bin|datasets/tools|0[0-8]-[a-z-]+)/[\w./-]+\.(?:sh|py)"
    r"|\./[\w-]+\.sh)\b"
)
PRELOAD_RE = re.compile(r"\./preload\.sh((?:\s+--[a-z][a-z0-9-]*(?:\s+[a-z_0-9]+)?)+)")
CHAOS_COMMANDS = {"list", "status", "reset", "revert", "help"}
# Mots qui suivent « make » dans une phrase française sans être une cible.
NOT_TARGETS = {"est", "et", "peut", "absent", "manque", "n", "fait", "ne"}


def targets() -> set[str]:
    names = set()
    for line in (ROOT / "scripts" / "targets.def").read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            names.add(line.split("\t")[0])
    return names


def preload_flags() -> set[str]:
    """Options documentées dans l'aide de preload.sh (bloc usage)."""
    text = (ROOT / "preload.sh").read_text(encoding="utf-8")
    usage = text[text.index("Options :"):text.index("USAGE", text.index("Options :"))]
    return set(re.findall(r"^\s+(--[a-z][a-z0-9-]*)", usage, flags=re.MULTILINE))


def markdown_files() -> list[Path]:
    try:
        listed = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
            check=True, capture_output=True, text=True,
        ).stdout.split()
        files = [ROOT / name for name in listed]
    except (OSError, subprocess.CalledProcessError):
        files = [p for p in ROOT.rglob("*.md") if ".git" not in p.parts]
    return sorted(p for p in files if p.name not in HISTORICAL and p.is_file())


def scenario_exists(name: str) -> bool:
    match = re.fullmatch(r"scenario-(\d+)", name)
    return bool(match) and any((ROOT / "chaos" / "scenarios").glob(f"scenario-{int(match[1]):02d}-*.sh"))


def check_file(path: Path, known: set[str], flags: set[str]) -> list[str]:
    problems = []
    rel = path.relative_to(ROOT)
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        for match in FARCI_RE.finditer(line):
            name = match.group(1)
            if name in NOT_TARGETS:
                continue
            if name not in known:
                problems.append(f"{rel}:{number}: cible inconnue « {match.group(0)} »")
        for match in CHAOS_RE.finditer(line):
            name = match.group(1)
            if name not in CHAOS_COMMANDS and not scenario_exists(name):
                problems.append(f"{rel}:{number}: commande chaos inconnue « {match.group(0)} »")
        for match in PRELOAD_RE.finditer(line):
            for flag in re.findall(r"--[a-z][a-z0-9-]*", match.group(1)):
                if flag not in flags:
                    problems.append(f"{rel}:{number}: option inconnue de preload.sh « {flag} »")
        for match in PATH_RE.finditer(line):
            cited = match.group(1).removeprefix("./")
            if not (ROOT / cited).exists():
                problems.append(f"{rel}:{number}: fichier cité absent « {match.group(1)} »")
    return problems


def main() -> int:
    known, flags = targets(), preload_flags()
    problems = [p for md in markdown_files() for p in check_file(md, known, flags)]
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
