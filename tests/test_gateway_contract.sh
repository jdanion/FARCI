#!/usr/bin/env bash
# FARCI — test du contrat gateway (FARCI §18)
#
# Passe par l'accueil de la salle (FARCI_ENTRY_URL) : le client ne connaît que
# lui. La passerelle qui répond est celle de l'équipe 3, ou celle de la
# référence (🛟) : le contrat est le même.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="gateway-contract"
test_start
test_need_service FARCI_ENTRY_URL /livez

API_KEY="${FARCI_API_KEY:-${GATEWAY_KEY_STANDARD:-}}"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 120 \
  -X POST "$FARCI_GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"model\":\"${FARCI_MODEL_ALIAS:-med-extraction}\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}],\"max_tokens\":1}" \
  2>/dev/null || true)

case "$code" in
  200) test_pass "med-extraction" ;;
  401) test_fail "authentification refusée (clé GATEWAY_KEY_STANDARD)" ;;
  *)   test_fail "code HTTP $code" ;;
esac

test_finish
