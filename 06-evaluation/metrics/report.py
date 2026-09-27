"""FARCI — rapport d'évaluation.

Génère un tableau lisible et exporte en markdown/JSON.
"""

from __future__ import annotations

import json
from pathlib import Path


def render_report(results: dict) -> str:
    """Génère un rapport lisible."""
    lines = [
        "# FARCI — Rapport d'évaluation",
        "",
        f"- Dossiers : {results.get('nb_dossiers', 0)}",
        f"- Complétude : {results.get('completude', 0):.1%}",
        f"- JSON valides : {results.get('json_valides', 0)}",
        f"- Precision : {results.get('precision', 0):.4f}",
        f"- Recall : {results.get('recall', 0):.4f}",
        f"- F1 : {results.get('f1', 0):.4f}",
        "",
        "## Détail par dossier",
        "",
        "| Patient | F1 |",
        "|---|---|",
    ]

    for run in results.get("runs", []):
        lines.append(f"| {run['patient_id']} | {run['f1']:.4f} |")

    return "\n".join(lines)


def save_report(results: dict, output_dir: Path):
    """Sauvegarde le rapport en markdown et JSON."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # JSON
    json_path = output_dir / "report.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    # Markdown
    md_path = output_dir / "report.md"
    md_path.write_text(render_report(results), encoding="utf-8")

    print(f"Rapport sauvegardé : {json_path}, {md_path}")
