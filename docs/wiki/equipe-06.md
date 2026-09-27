# Équipe 6 — Évaluation (MLflow, métriques)

## Attendus pédagogiques

- Comprendre la notion de métrique d'évaluation (precision, recall, F1)
- Comprendre la différence entre micro et macro
- Comprendre pourquoi `null` attendu compte comme correct
- Comprendre la notion de run MLflow et de paramétrage
- Savoir comparer des runs entre eux

## Solution simple (scripts)

```bash
# 1. Démarrer MLflow
cd 06-evaluation/mlflow
docker compose up -d

# 2. Évaluer
python 06-evaluation/metrics/evaluate.py

# 3. Valider le gold
python 06-evaluation/gold-standard/validate_gold.py
```

## Solution from scratch

### 1. Démarrer MLflow

```bash
docker run -d \
  --name farci-mlflow \
  --network farci \
  -p 5000:5000 \
  -v mlflow-data:/mlflow \
  mlflow/mlflow:3.16.1 \
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

mlflow.set_tracking_uri("http://192.168.50.50:5000")
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
# Dans l'UI MLflow : http://192.168.50.50:5000
# Sélectionner plusieurs runs → Compare
```

## Vérifications

- [ ] MLflow répond sur :5000
- [ ] Métriques calculées (precision, recall, F1)
- [ ] Runs comparables dans l'UI
- [ ] Détection de régression fonctionnelle
