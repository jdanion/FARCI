#!/usr/bin/env python3
"""FARCI — évaluation des extractions contre le gold standard (FARCI §34).

Une « run » est un dossier d'extractions : `datasets/extracted/<équipe>/`,
contenant un `patient_<IPP>.json` par dossier patient. Toutes les runs
trouvées sont évaluées sur le MÊME gold, puis classées par F1.

Usage :
    ./bin/farci evaluate                              toutes les runs
    ./bin/farci evaluate --runs python webui          certaines runs
    ./bin/farci evaluate --subset quick               jeu rapide (10 cas)
    ./bin/farci evaluate --extracted-dir datasets/gold    contrôle : gold vs gold
    ./bin/farci evaluate --json                       sortie JSON
    ./bin/farci evaluate --report-dir datasets/reports    rapport .md + .json
    ./bin/farci evaluate --min-f1 1.0                 code 2 si une run est en dessous

Règles (affichées aussi dans le rapport) :
  - un dossier absent, illisible ou non conforme au schéma compte comme
    « tout manqué » : le F1 est calculé sur TOUS les dossiers du gold ;
  - `patient_id` n'est pas noté (clé du dossier, pseudonymisée) ;
  - la latence moyenne vient de `_meta.latency_s` quand le pipeline l'écrit.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "datasets" / "tools"))

from metrics import SCORED_FIELDS, add_outcome, compute_metrics, empty_counts, scores  # noqa: E402
from report import render_report, save_report  # noqa: E402
from schema_check import load_schema, validate  # noqa: E402


def load_json(path: Path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def patient_key(path: Path) -> str:
    return path.stem.removeprefix("patient_")


def discover_runs(extracted_dir: Path, wanted: list[str] | None) -> dict[str, Path]:
    """nom de run -> dossier. Un dossier qui contient directement des
    patient_*.json est lui-même une run (c'est le cas de --extracted-dir gold)."""
    if not extracted_dir.is_dir():
        return {}
    if any(extracted_dir.glob("patient_*.json")):
        found = {extracted_dir.name: extracted_dir}
    else:
        found = {
            child.name: child
            for child in sorted(extracted_dir.iterdir())
            if child.is_dir() and any(child.glob("patient_*.json"))
        }
    if wanted:
        missing = [name for name in wanted if name not in found]
        for name in missing:
            found[name] = extracted_dir / name  # run demandée mais vide : 0 %
        found = {name: found[name] for name in wanted}
    return found


def evaluate_run(name: str, run_dir: Path, gold: dict[str, dict], schema: dict) -> dict:
    counts = empty_counts()
    per_field = {field: 0 for field in SCORED_FIELDS}
    dossiers = []
    latencies = []
    found = valid = 0

    for key, gold_record in gold.items():
        path = run_dir / f"patient_{key}.json"
        status, errors, predicted = "absent", [], None
        if path.is_file():
            found += 1
            try:
                data = load_json(path)
            except (OSError, json.JSONDecodeError) as exc:
                status, errors = "illisible", [f"JSON illisible : {exc}"]
            else:
                errors = validate(data, schema)
                if errors:
                    status = "invalide"
                else:
                    status, predicted = "valide", data
                    valid += 1
                    latency = (data.get("_meta") or {}).get("latency_s")
                    if isinstance(latency, (int, float)) and not isinstance(latency, bool):
                        latencies.append(float(latency))

        result = compute_metrics(gold_record, predicted)
        for field, comparison in result["fields"].items():
            add_outcome(counts, comparison["outcome"])
            per_field[field] += comparison["correct"]
        dossiers.append({
            "patient": key,
            "statut": status,
            "f1": result["f1"],
            "erreurs": errors[:5],
        })

    total = len(gold)
    return {
        "run": name,
        "dossiers": total,
        "extraits": found,
        "json_valides": valid,
        "completude": valid / total if total else 0.0,
        **scores(counts),
        "latence_moyenne_s": sum(latencies) / len(latencies) if latencies else None,
        "par_champ": {field: per_field[field] / total if total else 0.0 for field in SCORED_FIELDS},
        "par_dossier": dossiers,
    }


def load_gold(gold_dir: Path, subset: str) -> dict[str, dict]:
    gold = {patient_key(p): load_json(p) for p in sorted(gold_dir.glob("patient_*.json"))}
    if subset == "quick":
        from cases import quick_set

        keep = {case.patient_id for case in quick_set()}
        gold = {key: value for key, value in gold.items() if key in keep}
    return gold


def evaluate(gold_dir: Path, extracted_dir: Path, runs: list[str] | None = None,
             subset: str = "full") -> dict:
    gold = load_gold(gold_dir, subset)
    schema = load_schema()
    results = [
        evaluate_run(name, run_dir, gold, schema)
        for name, run_dir in discover_runs(extracted_dir, runs).items()
    ]
    results.sort(key=lambda r: (r["f1"], r["completude"]), reverse=True)
    return {
        "gold_dir": str(gold_dir),
        "extracted_dir": str(extracted_dir),
        "subset": subset,
        "nb_dossiers": len(gold),
        "runs": results,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="FARCI — évaluation des extractions contre le gold standard",
    )
    parser.add_argument("--gold-dir", type=Path, default=ROOT / "datasets" / "gold")
    parser.add_argument("--extracted-dir", type=Path, default=ROOT / "datasets" / "extracted")
    parser.add_argument("--runs", nargs="*", default=None, help="noms de runs (sous-dossiers)")
    parser.add_argument("--subset", choices=["full", "quick"], default="full")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    parser.add_argument("--report-dir", type=Path, default=None)
    parser.add_argument("--min-f1", type=float, default=None,
                        help="seuil : code de sortie 2 si une run a un F1 inférieur")
    args = parser.parse_args(argv)

    results = evaluate(args.gold_dir, args.extracted_dir, args.runs, args.subset)
    if not results["nb_dossiers"]:
        print(f"ERREUR : aucun gold dans {args.gold_dir}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        print(render_report(results))
    if args.report_dir:
        save_report(results, args.report_dir)
    if not results["runs"]:
        print(f"\naucune extraction trouvée dans {args.extracted_dir}", file=sys.stderr)
        return 1
    if args.min_f1 is not None:
        below = [r["run"] for r in results["runs"] if r["f1"] < args.min_f1]
        if below:
            print(f"\nF1 < {args.min_f1} : {', '.join(below)}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
