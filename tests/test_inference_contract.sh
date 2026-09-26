#!/usr/bin/env bash
# FARCI — test du contrat d'inférence (FARCI §16)
#
# Reçoit BASE_URL, vérifie la forme de la réponse.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="inference-contract"
test_start

BASE_URL="${BASE_URL:-http://192.168.50.20:8080/v1}"

# Vérifier /v1/models
models=$(curl -sf "$BASE_URL/models" 2>/dev/null || echo "")
if [[ -z "$models" ]]; then
  test_fail "models vide"
  test_finish
  exit 1
fi

# Vérifier /health
health=$(curl -sf "$BASE_URL/health" 2>/dev/null || echo "")
if [[ -z "$health" ]]; then
  test_fail "health vide"
  test_finish
  exit 1
fi

test_pass "ollama"
test_finish
