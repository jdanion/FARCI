"""FARCI — rapport d'évaluation : classement des runs, détail par champ.

Le classement est le moment où les parcours se comparent : même gold, même
schéma, même alias de modèle. Un chiffre seul ne veut rien dire.
"""

from __future__ import annotations

import json
from pathlib import Path


def _pct(value) -> str:
    return "—" if value is None else f"{value:.0%}"


def _num(value, fmt=".2f") -> str:
    return "—" if value is None else format(value, fmt)


def render_report(results: dict) -> str:
    runs = results.get("runs", [])
    lines = [
        "# FARCI — rapport d'évaluation",
        "",
        f"Gold : {results.get('nb_dossiers', 0)} dossiers ({results.get('subset', 'full')})",
        "",
        "| Rang | Run | Complétude | JSON valides | Exactitude | Précision | Rappel | F1 | Latence moy. (s) |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for rank, run in enumerate(runs, start=1):
        lines.append(
            f"| {rank} | {run['run']} | {_pct(run['completude'])} "
            f"| {run['json_valides']}/{run['dossiers']} | {_pct(run['exactitude'])} "
            f"| {_num(run['precision'])} | {_num(run['recall'])} | **{_num(run['f1'])}** "
            f"| {_num(run['latence_moyenne_s'], '.1f')} |"
        )
    if not runs:
        lines.append("| — | aucune extraction | | | | | | | |")

    for run in runs:
        weakest = sorted(run["par_champ"].items(), key=lambda kv: kv[1])[:3]
        problems = [d for d in run["par_dossier"] if d["statut"] != "valide"]
        lines += ["", f"## {run['run']}", ""]
        lines.append(
            "Champs les moins bien extraits : "
            + ", ".join(f"{field} ({_pct(score)})" for field, score in weakest)
        )
        if problems:
            lines.append("")
            lines.append("Dossiers non comptés comme valides :")
            for dossier in problems[:10]:
                detail = f" — {dossier['erreurs'][0]}" if dossier["erreurs"] else ""
                lines.append(f"- {dossier['patient']} : {dossier['statut']}{detail}")

    lines += [
        "",
        "Règle : un dossier absent ou non conforme au schéma compte comme « tout manqué ».",
    ]
    return "\n".join(lines)


def save_report(results: dict, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "report.json"
    with open(json_path, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)
    md_path = output_dir / "report.md"
    md_path.write_text(render_report(results) + "\n", encoding="utf-8")
    print(f"\nRapport sauvegardé : {json_path}, {md_path}")
