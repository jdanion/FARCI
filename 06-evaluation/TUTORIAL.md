# TUTORIAL — Équipe 6 : Évaluation & MLflow

## Objectif

Mettre en place l'évaluation des extractions LLM : métriques champ par champ,
comparaison au gold standard, suivi des runs dans MLflow.

## Architecture

```
Extraction (JSON)
    │
    ▼
┌─────────────┐
│ evaluate.py │  ← compare au gold
│             │  ← métriques micro/macro
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   MLflow    │  ← suivi des runs
│   :5000     │
└─────────────┘
```

## Démarrage

### MLflow

```bash
cd 06-evaluation/mlflow
docker compose up -d
```

### Évaluation

```bash
# Tous les dossiers
python 06-evaluation/metrics/evaluate.py

# Sous-ensemble
python 06-evaluation/metrics/evaluate.py --runs python flowise
```

## Axes expérimentaux

| Axe | Valeurs |
|---|---|
| `model` | ornith-1.5-9b / qwen3.8-27b |
| `quant` | q4km / q5km / q8_0 |
| `runtime` | ollama / llamacpp / omlx |
| `thinking` | on / off |
| `prompt_version` | v1 / v2 |
| `schema_mode` | json_schema / prompt_strict / gbnf |

## Détection de régression

```
JSON validity       100 %
Extraction F1       0.84
Regression          none
```

## Dépannage

### MLflow ne démarre pas

```bash
docker logs farci-mlflow
```

### Pas de données dans MLflow

Vérifier que les runs ont été lancés avec les bons paramètres.
