#!/usr/bin/env python3
"""FARCI — accès JSON en ligne de commande, sans jq (règle n°0 : stdlib only).

Commandes :
  get    <chemin>        lit une valeur depuis stdin ou depuis un fichier (-)
  keys   [chemin]        liste les clés d'un objet
  has    <chemin>        vrai si le chemin existe
  type   <chemin>        affiche le type JSON
  valid                  vrai si l'entrée est du JSON valide
  norm                   json pretty-print compact (une ligne)

Chemins acceptés : a.b.c, a.b[0].c, [0].a, a["b"].c
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any

_INDEX = re.compile(r"^([^\[\]]*)((\[[^\]]*\])*)$")
_STEP = re.compile(r"\[([^\]]*)\]")


def parse_path(path: str) -> list[str]:
    """'a.b[0].c' -> ['a', 'b', '0', 'c'] (les indices deviennent des chaînes)."""
    steps: list[str] = []
    for part in path.split("."):
        if not part:
            continue
        match = _INDEX.match(part)
        if match is None:
            raise ValueError(f"chemin invalide : {path!r}")
        name, brackets, _ = match.groups()
        if name:
            steps.append(name.strip('"').strip("'"))
        for step in _STEP.findall(brackets or ""):
            steps.append(step.strip('"').strip("'"))
    return steps


def resolve(data: Any, steps: list[str]) -> Any:
    current = data
    for step in steps:
        if isinstance(current, dict):
            if step not in current:
                raise KeyError(step)
            current = current[step]
        elif isinstance(current, list):
            try:
                current = current[int(step)]
            except (ValueError, IndexError) as exc:
                raise KeyError(step) from exc
        else:
            raise KeyError(step)
    return current


def load_input(path: str) -> Any:
    raw = open(path, "r", encoding="utf-8").read() if path != "-" else sys.stdin.read()
    if not raw.strip():
        raise ValueError("entrée vide")
    return json.loads(raw)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 64
    command, args = argv[1], argv[2:]
    try:
        if command == "valid":
            source = args[0] if args else "-"
            try:
                json.loads(open(source, encoding="utf-8").read() if source != "-" else sys.stdin.read())
            except Exception:
                return 1
            return 0

        if command == "norm":
            source = args[0] if args else "-"
            data = load_input(source)
            print(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
            return 0

        if command in ("get", "keys", "has", "type"):
            if command == "keys":
                path = args[0] if args else ""
                source = args[1] if len(args) > 1 else "-"
            else:
                if not args:
                    print(f"{command}: chemin manquant", file=sys.stderr)
                    return 64
                path, source = args[0], (args[1] if len(args) > 1 else "-")
            data = load_input(source)
            value = resolve(data, parse_path(path)) if path else data
            if command == "has":
                return 0 if value is not None or path in _flat_keys(data) else 1
            if command == "keys":
                if isinstance(value, dict):
                    print("\n".join(str(k) for k in value))
                    return 0
                if isinstance(value, list):
                    print(f"liste[{len(value)}]")
                    return 0
                print(f"pas un objet : {type(value).__name__}", file=sys.stderr)
                return 1
            if command == "type":
                print(_json_type(value))
                return 0
            if value is None:
                return 1
            if isinstance(value, (dict, list)):
                print(json.dumps(value, ensure_ascii=False))
            elif isinstance(value, bool):
                print("true" if value else "false")
            else:
                print(value)
            return 0

    except json.JSONDecodeError as exc:
        print(f"JSON invalide : {exc}", file=sys.stderr)
        return 1
    except (KeyError, IndexError):
        return 1
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(f"commande inconnue : {command}", file=sys.stderr)
    return 64


def _flat_keys(data: Any) -> set[str]:
    if isinstance(data, dict):
        return set(data)
    return set()


def _json_type(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    return "object"


if __name__ == "__main__":
    sys.exit(main(sys.argv))
