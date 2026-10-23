#!/usr/bin/env python3
"""FARCI — enregistrements du runtime rejoué (plan C).

Le runtime rejoué (`reference/replay/server.py`) ne calcule rien : il renvoie,
pour chaque dossier du dataset, une réponse ENREGISTRÉE. Ce fichier fabrique
ces enregistrements, de deux façons :

  synthétique (défaut)   à partir du gold, avec des erreurs FIXÉES, réalistes
                         et reproductibles : le prompt v1 se trompe un peu plus
                         que le v2, un dossier renvoie un JSON tronqué. Le
                         classement de l'évaluation garde donc un sens.
  --from-run <dossier>   à partir d'une vraie run (datasets/extracted/<run>/),
                         typiquement la répétition J-1 sur le vrai modèle :
                         le jour J, le plan C rejoue les vraies réponses.

Le modèle `med-chaos` (scénario 04) renvoie toujours une sortie non conforme.

Usage :
    python3 reference/replay/recordings.py                   # réécrit recordings.json
    python3 reference/replay/recordings.py --check           # vérifie qu'il est à jour
    python3 reference/replay/recordings.py --from-run datasets/extracted/recette --prompt v1
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GOLD = ROOT / "datasets" / "gold"
OUTPUT = HERE / "recordings.json"

# Erreurs fixées : (index du dossier dans l'ordre du gold, champ, valeur rendue).
# Choisies pour ressembler à ce que fait un vrai modèle : valeur manquée,
# confusion entre deux catégories proches, unité oubliée, booléen inversé.
ERRORS = {
    "v1": [
        (1, "tumor_size_mm", None),                   # taille non trouvée
        (3, "approach", "laparotomie"),               # « convertie » perdue
        (6, "pN", "pN0"),                             # ganglions mal lus
        (8, "delayed_gastrojejunostomy", True),       # complication inventée
        (12, "nodes_examined", None),
        (16, "margin_R", "R1"),
    ],
    "v2": [
        (6, "pN", "pN0"),
        (16, "margin_R", "R1"),
    ],
}
# Dossiers dont la réponse est un JSON tronqué (sortie interrompue) : la
# validation doit refuser de les écrire, le rapport doit les compter.
TRUNCATED = {"v1": [4], "v2": []}
# Dossiers renvoyés dans un bloc ```json : toléré par le pipeline.
FENCED = {"v1": [2, 9], "v2": [2]}


def gold_records() -> list[tuple[str, dict]]:
    records = []
    for path in sorted(GOLD.glob("patient_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        data.pop("_meta", None)
        data.pop("nir", None)
        records.append((path.stem.removeprefix("patient_"), data))
    return records


def as_answer(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False)


def synthetic() -> dict:
    records = gold_records()
    models: dict = {"med-extraction": {}, "med-chaos": {"*": {}}}
    for prompt in ("v1", "v2"):
        answers = {}
        for index, (key, record) in enumerate(records):
            answer = dict(record, patient_id="[IPP_0]")
            for err_index, field, value in ERRORS[prompt]:
                if err_index == index:
                    answer[field] = value
            text = as_answer(answer)
            if index in TRUNCATED[prompt]:
                text = text[: len(text) // 2]
            elif index in FENCED[prompt]:
                text = "```json\n" + text + "\n```"
            answers[key] = text
        models["med-extraction"][prompt] = answers
    for key, record in records:
        # Hors schéma : âge en lettres, sexe hors énumération, champ requis absent.
        broken = dict(record, patient_id="[IPP_0]", age="soixante-sept", sex="X")
        broken.pop("histology", None)
        models["med-chaos"]["*"][key] = as_answer(broken)
    return {
        "version": 1,
        "source": "synthétique : gold + erreurs fixées (reference/replay/recordings.py)",
        "models": models,
    }


def from_run(run_dir: Path, prompt: str, base: dict) -> dict:
    answers = {}
    for path in sorted(run_dir.glob("patient_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        data.pop("_meta", None)
        answers[path.stem.removeprefix("patient_")] = as_answer(data)
    if not answers:
        raise SystemExit(f"aucune extraction dans {run_dir}")
    merged = json.loads(json.dumps(base))
    current = merged["models"]["med-extraction"].get(prompt, {})
    current.update(answers)  # les dossiers absents de la run gardent la réponse synthétique
    merged["models"]["med-extraction"][prompt] = current
    merged["source"] = f"run enregistrée {run_dir.name} (prompt {prompt}) + synthétique"
    return merged


def write(data: dict, path: Path = OUTPUT) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="FARCI — enregistrements du runtime rejoué")
    parser.add_argument("--check", action="store_true", help="vérifier que recordings.json est à jour")
    parser.add_argument("--from-run", type=Path, default=None, help="dossier d'une run réelle")
    parser.add_argument("--prompt", choices=["v1", "v2"], default="v1")
    args = parser.parse_args()

    data = synthetic()
    if args.check:
        current = json.loads(OUTPUT.read_text(encoding="utf-8")) if OUTPUT.exists() else None
        if current is None or current.get("source", "").startswith("run enregistrée"):
            print("recordings.json absent ou issu d'une run : rien à comparer")
            return 0 if current else 1
        if current != json.loads(json.dumps(data)):
            print("recordings.json n'est pas à jour : python3 reference/replay/recordings.py")
            return 1
        print("recordings.json à jour")
        return 0
    if args.from_run:
        data = from_run(args.from_run, args.prompt, data)
    write(data)
    total = sum(len(v) for m in data["models"].values() for v in m.values())
    print(f"{OUTPUT.relative_to(ROOT)} : {total} réponses ({data['source']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
