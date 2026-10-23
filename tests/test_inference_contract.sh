#!/usr/bin/env bash
# FARCI — test du contrat d'inférence (FARCI §16)
#
# Paramétrable : BASE_URL (défaut : runtime A de config/network.env).

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"
source "$FARCI_TESTS_DIR/lib/json.sh"

TEST_NAME="inference-contract"
test_start
if [[ -z "${BASE_URL:-}" ]]; then
  test_local_default INFERENCE_A_URL INFERENCE_A_PORT
  test_need_service INFERENCE_A_URL /v1/models
  BASE_URL="$INFERENCE_A_URL/v1"
fi

models=$(curl -sf --max-time 10 "$BASE_URL/models" 2>/dev/null || echo "")
if [[ -z "$models" ]] || ! json_valid "$models"; then
  test_fail "/v1/models ne renvoie pas de JSON"
elif [[ "$(json_get "$models" object)" != "list" ]]; then
  test_fail "/v1/models : champ object != list"
else
  test_pass "$BASE_URL"
fi

test_finish
