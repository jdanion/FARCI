#!/usr/bin/env python3
"""FARCI — rendu du tableau de progression (FARCI §49), projeté dans la salle.

    python3 scripts/board.py [--all] [--json] [--no-probe] [--strict]

Lignes « core » détaillées, lignes « bonus » résumées (--all : détaillées).
Chaque ligne dit QUI rend le service :
    ✅ UP    la brique de l'équipe répond
    🛟 REF   l'équipe n'y est pas (encore), la référence du formateur la remplace
    DOWN     personne ne rend ce service
Deux verdicts sous le cadre : le pipeline des ÉQUIPES (le moment clé de
l'étape 1) et le service rendu à la salle (équipes + référence).

Code de sortie avec --strict : 0 si le pipeline des équipes est READY.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import services  # noqa: E402

INNER = 44
COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
GREEN, YELLOW, RED, DIM, BOLD, RESET = (
    ("\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[1m", "\033[0m") if COLOR else ("",) * 6
)


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def width(text: str) -> int:
    """Largeur à l'écran : un emoji occupe deux colonnes, une couleur aucune."""
    total = 0
    for char in ANSI.sub("", text):
        if unicodedata.combining(char) or char == "️":
            continue
        total += 2 if unicodedata.east_asian_width(char) in ("W", "F") else 1
    return total


def line(label: str, value: str, colour: str = "") -> str:
    space = INNER - 2 - width(label) - width(value)
    return f"║ {colour}{label}{' ' * max(1, space)}{value}{RESET if colour else ''} ║"


def row_value(states: list[dict]) -> tuple[str, str]:
    """Valeur et couleur d'une ligne à partir de ses services."""
    if all(s["served_by"] == "equipe" for s in states):
        return "✅ UP", GREEN
    if all(s["served_by"] for s in states):
        return "🛟 REF", YELLOW
    if any(s["served_by"] for s in states):
        return "DEGRADED", YELLOW
    if all(s["team"] == "unknown" and s["reference"] in (None, "unknown") for s in states):
        return "UNKNOWN", DIM
    return "DOWN", RED


def verdict(state: str) -> str:
    return {"READY": GREEN, "DEGRADED": YELLOW}.get(state, RED)


def render(room: dict, show_all: bool) -> str:
    by_id = {s["id"]: s for s in room["services"]}
    bar = "═" * INNER
    out = [f"╔{bar}╗", line(f"{BOLD}FARCI{RESET if COLOR else ''} WORKSHOP" if COLOR else "FARCI WORKSHOP",
                           time.strftime("%H:%M")), f"╠{bar}╣"]
    bonus_up, bonus_total, bonus_names = 0, 0, []
    for row in services.registry().get("status_rows", []):
        states = services.row_members(row, [by_id[sid] for sid in row.get("check", []) if sid in by_id])
        value, colour = row_value(states)
        if row.get("tier") == "bonus" and not show_all:
            bonus_total += 1
            if value.endswith("UP"):
                bonus_up += 1
                bonus_names.append(row["label"])
            continue
        label = row["label"] + (" (bonus)" if row.get("tier") == "bonus" else "")
        out.append(line(label, value, colour))
    if bonus_total:
        out.append(line("Bonus", f"{bonus_up}/{bonus_total} UP", DIM))
    out.append(f"╠{bar}╣")
    team = room["pipeline"]["state"]
    served = room["service_rendu"]["state"]
    out.append(line("CLINICAL PIPELINE", team, verdict(team)))
    if team != "READY":
        out.append(line("Service rendu (avec 🛟)", served, verdict(served)))
    out.append(f"╚{bar}╝")
    if bonus_names:
        out.append(f"  Bonus en service : {', '.join(bonus_names)}")
    if room["rescue"]:
        out.append(f"  Référence forcée (rescue) : {', '.join(room['rescue'])}")
    chaos = room.get("chaos") or {}
    if chaos.get("exclues") or chaos.get("coupees"):
        parts = [f"équipe coupée : {', '.join(chaos['exclues'])}"] if chaos.get("exclues") else []
        parts += [f"route coupée : {', '.join(chaos['coupees'])}"] if chaos.get("coupees") else []
        out.append(f"  {RED}PANNE EN COURS{RESET if COLOR else ''} — " + " ; ".join(parts))
    if team != "READY" and room["pipeline"]["missing"]:
        out.append("")
        if served == "READY":
            out.append("  À livrer par les équipes (la référence 🛟 les remplace en attendant) :")
        else:
            out.append("  Il manque, dans l'ordre de montage :")
        out.append("    " + " → ".join(room["pipeline"]["missing"]))
    if any(s["served_by"] == "reference" for s in room["services"]):
        out.append("  🛟 = la référence du formateur remplace la brique de l'équipe")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    show_all = "--all" in argv
    room = services.room_state(float(os.environ.get("FARCI_HEALTH_TIMEOUT", "3")),
                               with_probe="--no-probe" not in argv)
    if "--json" in argv:
        print(json.dumps(room, ensure_ascii=False, indent=2))
    else:
        print()
        print(render(room, show_all))
        print()
    if "--strict" in argv:
        return 0 if room["pipeline"]["state"] == "READY" else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
