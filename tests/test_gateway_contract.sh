#!/usr/bin/env bash
# FARCI — test du contrat gateway (FARCI §18)
#
# Paramétrable par implémentation : IMPL=litellm|bifrost

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="gateway-contract"
test_start

IMPL="${IMPL:-litellm}"
GATEWAY_URL="${GATEWAY_URL:-http://192.168.50.15/v1}"
API_KEY="${FARCI_API_KEY:-sk-standard-placeholder}"

# Vérifier l'authentification
code=$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST "$GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}' 2>/dev/null || echo "000")

if [[ "$code" == "200" ]]; then
  test_pass "$IMPL"
elif [[ "$code" == "401" ]]; then
  test_fail "authentification échouée"
else
  test_fail "code $code"
fi

test_finish
