#!/usr/bin/env bash
# FARCI — test du contrat gateway (FARCI §18)
#
# Passe par le point d'entrée stable (Caddy) : le client ne connaît que lui.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="gateway-contract"
test_start
test_need_service CADDY_URL /healthz

API_KEY="${FARCI_API_KEY:-${GATEWAY_KEY_STANDARD:-}}"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 120 \
  -X POST "$FARCI_GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"model\":\"${FARCI_MODEL_ALIAS:-med-extraction}\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}],\"max_tokens\":1}" \
  2>/dev/null || echo "000")

case "$code" in
  200) test_pass "med-extraction" ;;
  401) test_fail "authentification refusée (clé GATEWAY_KEY_STANDARD)" ;;
  *)   test_fail "code HTTP $code" ;;
esac

test_finish
