"""FARCI — métriques d'extraction.

Exactitude champ par champ, micro P/R/F1.
Les champs `null` attendus comptent comme corrects si prédits `null`.
"""

from __future__ import annotations

from typing import Any

from .normalize import normalize_value


# Champs extraits (schéma ClinicalExtraction)
EXTRACTION_FIELDS = [
    "patient_id", "age", "sex", "diagnosis",
    "procedure_type", "approach", "venous_resection",
    "tumor_size_mm", "histology", "pT", "pN",
    "nodes_examined", "nodes_positive", "margin_R",
    "pancreatic_fistula", "delayed_gastrojejunostomy", "hemorrhage",
    "length_of_stay", "readmission",
]


def compare_field(gold_value: Any, predicted_value: Any) -> dict:
    """Compare un champ entre gold et prédiction."""
    field_type = "unknown"
    for f in EXTRACTION_FIELDS:
        if f == "patient_id":
            field_type = "id"
        elif f in ("age", "tumor_size_mm", "nodes_examined", "nodes_positive", "length_of_stay"):
            field_type = "number"
        elif f in ("venous_resection", "pancreatic_fistula", "delayed_gastrojejunostomy",
                   "hemorrhage", "readmission"):
            field_type = "boolean"
        else:
            field_type = "text"
        break

    # Normaliser les deux valeurs
    gold_norm = normalize_value(field_type, gold_value) if gold_value is not None else None
    pred_norm = normalize_value(field_type, predicted_value) if predicted_value is not None else None

    correct = gold_norm == pred_norm

    return {
        "gold": gold_value,
        "predicted": predicted_value,
        "gold_normalized": gold_norm,
        "pred_normalized": pred_norm,
        "correct": correct,
    }


def compute_metrics(gold: dict, predicted: dict) -> dict:
    """Calcule les métriques micro et macro pour un dossier."""
    field_results = {}
    tp = fp = fn = 0

    for field in EXTRACTION_FIELDS:
        result = compare_field(gold.get(field), predicted.get(field))
        field_results[field] = result

        if result["correct"]:
            tp += 1
        else:
            # Faux négatif ou faux positif
            if gold.get(field) is None and predicted.get(field) is None:
                tp += 1  # Les deux None, correct
            elif gold.get(field) is None:
                fp += 1
            elif predicted.get(field) is None:
                fn += 1
            else:
                fp += 1
                fn += 1

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0

    return {
        "fields": field_results,
        "micro": {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "tp": tp,
            "fp": fp,
            "fn": fn,
        },
        "macro": {
            "correct": sum(1 for r in field_results.values() if r["correct"]),
            "total": len(EXTRACTION_FIELDS),
        },
    }
