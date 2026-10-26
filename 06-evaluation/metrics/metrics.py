"""FARCI — métriques d'extraction, champ par champ.

Pour chaque champ noté, en comparant la valeur normalisée du gold (g) et de
la prédiction (p) :

    g null, p null            -> VN  (juste : « non précisé » bien reconnu)
    g null, p renseigné       -> FP  (valeur inventée)
    g renseigné, p null       -> FN  (valeur manquée)
    g et p renseignés, égaux  -> VP
    g et p renseignés, ≠      -> FP + FN (mauvaise valeur)

précision = VP / (VP + FP), rappel = VP / (VP + FN), F1 = moyenne harmonique,
exactitude = (VP + VN) / nombre de champs.

`patient_id` n'est pas noté : c'est la clé du dossier (le nom du fichier),
et il est pseudonymisé avant d'atteindre le modèle.
"""

from __future__ import annotations

from normalize import normalize_value

EXTRACTION_FIELDS = [
    "patient_id", "age", "sex", "diagnosis",
    "procedure_type", "approach", "venous_resection",
    "tumor_size_mm", "histology", "pT", "pN",
    "nodes_examined", "nodes_positive", "margin_R",
    "pancreatic_fistula", "delayed_gastrojejunostomy", "hemorrhage",
    "length_of_stay", "readmission",
]
SCORED_FIELDS = [f for f in EXTRACTION_FIELDS if f != "patient_id"]


def compare_field(field: str, gold_value, predicted_value) -> dict:
    gold_norm = normalize_value(field, gold_value)
    pred_norm = normalize_value(field, predicted_value)
    if gold_norm is None and pred_norm is None:
        outcome = "vn"
    elif gold_norm is None:
        outcome = "fp"
    elif pred_norm is None:
        outcome = "fn"
    elif gold_norm == pred_norm:
        outcome = "vp"
    else:
        outcome = "faux"
    return {
        "gold": gold_value,
        "predicted": predicted_value,
        "outcome": outcome,
        "correct": outcome in ("vp", "vn"),
    }


def empty_counts() -> dict:
    return {"vp": 0, "vn": 0, "fp": 0, "fn": 0, "faux": 0}


def add_outcome(counts: dict, outcome: str) -> None:
    counts[outcome] += 1
    if outcome == "faux":
        # Une mauvaise valeur est à la fois inventée (FP) et manquée (FN).
        counts["fp"] += 1
        counts["fn"] += 1


def scores(counts: dict) -> dict:
    vp, vn, fp, fn = counts["vp"], counts["vn"], counts["fp"], counts["fn"]
    # Rien à trouver et rien d'inventé : le dossier est parfait, pas nul.
    perfect_empty = 1.0 if (fp == 0 and fn == 0) else 0.0
    precision = vp / (vp + fp) if (vp + fp) else perfect_empty
    recall = vp / (vp + fn) if (vp + fn) else perfect_empty
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    total = vp + vn + fp + fn - counts["faux"]
    accuracy = (vp + vn) / total if total else 0.0
    return {"precision": precision, "recall": recall, "f1": f1, "exactitude": accuracy}


def compute_metrics(gold: dict, predicted: dict | None) -> dict:
    """Métriques d'un dossier. `predicted=None` : dossier non extrait ou invalide,
    chaque valeur attendue compte alors comme manquée."""
    predicted = predicted or {}
    counts = empty_counts()
    fields = {}
    for field in SCORED_FIELDS:
        result = compare_field(field, gold.get(field), predicted.get(field))
        fields[field] = result
        add_outcome(counts, result["outcome"])
    return {"fields": fields, "counts": counts, **scores(counts)}
