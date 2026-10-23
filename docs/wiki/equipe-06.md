# Équipe 6 — Évaluation (MLflow, métriques)

## Attendus pédagogiques

- Comprendre la notion de métrique d'évaluation (precision, recall, F1)
- Comprendre la différence entre micro et macro
- Comprendre pourquoi `null` attendu compte comme correct
- Comprendre la notion de run MLflow et de paramétrage
- Savoir comparer des runs entre eux

## Solution simple (scripts)

```bash
# 1. Contrôle : le gold comparé à lui-même donne 1.00 partout
./bin/farci evaluate --extracted-dir datasets/gold

# 2. Valider le gold contre le schéma
python3 06-evaluation/gold-standard/validate_gold.py

# 3. Après l'étape 2 : classer les runs
./bin/farci evaluate

# 4. Bonus : MLflow
./bin/farci up 06-evaluation/mlflow
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Démarrer MLflow

```bash
docker run -d \
  --name farci-mlflow \
  -p 5000:5000 \
  -v mlflow-data:/mlflow \
  ghcr.io/mlflow/mlflow:v3.16.1 \
  mlflow server \
  --host 0.0.0.0 \
  --port 5000 \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root /mlflow/artifacts
```

### 2. Calculer les métriques

```python
from metrics.metrics import compute_metrics

gold = {"patient_id": "123", "age": 67, "sex": "M", ...}
predicted = {"patient_id": "123", "age": 67, "sex": "M", ...}

result = compute_metrics(gold, predicted)
print(f"F1: {result['micro']['f1']:.4f}")
```

### 3. Normaliser les valeurs

```python
from metrics.normalize import normalize_value

normalize_value("age", "67")        # → 67.0
normalize_value("sex", "M")         # → "m"
normalize_value("tumor_size_mm", "28 mm")  # → 28.0
normalize_value("venous_resection", "oui")  # → True
```

### 4. Lancer un run MLflow

```python
import mlflow

mlflow.set_tracking_uri("$MLFLOW_URL")
mlflow.set_experiment("farci-evaluation")

with mlflow.start_run():
    mlflow.log_param("model", "ornith-1.5-9b")
    mlflow.log_param("runtime", "llamacpp")
    mlflow.log_param("prompt_version", "v1")
    mlflow.log_metric("f1", 0.84)
    mlflow.log_metric("precision", 0.82)
    mlflow.log_metric("recall", 0.86)
```

### 5. Comparer des runs

```bash
# Dans l'UI MLflow : $MLFLOW_URL
# Sélectionner plusieurs runs → Compare
```

## Vérifications

- [ ] MLflow répond sur :5000
- [ ] Métriques calculées (precision, recall, F1)
- [ ] Runs comparables dans l'UI
- [ ] Détection de régression fonctionnelle
