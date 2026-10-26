#!/usr/bin/env bash
# FARCI — entrypoint MLflow
# Configure le backend store et les artifacts.

set -euo pipefail

export MLFLOW_BACKEND_STORE_URI="${MLFLOW_BACKEND_STORE_URI:-sqlite:///mlflow.db}"
export MLFLOW_DEFAULT_ARTIFACT_ROOT="${MLFLOW_DEFAULT_ARTIFACT_ROOT:-/mlflow/artifacts}"

exec mlflow server \
  --host 0.0.0.0 \
  --port 5000 \
  --backend-store-uri "$MLFLOW_BACKEND_STORE_URI" \
  --default-artifact-root "$MLFLOW_DEFAULT_ARTIFACT_ROOT"
