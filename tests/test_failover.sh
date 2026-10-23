#!/usr/bin/env bash
# FARCI — test de failover (scénario 01, en version automatique)
#
# DESTRUCTIF : arrête le runtime primaire puis le redémarre. Il ne s'exécute
# donc que si FARCI_TESTS_DESTRUCTIVE=1 (recette J-1), sinon SKIP.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="failover"
test_start
if [[ "${FARCI_TESTS_DESTRUCTIVE:-0}" != "1" ]]; then
  test_skip "destructif (FARCI_TESTS_DESTRUCTIVE=1)"
  test_finish
  exit $?
fi
test_need_service CADDY_URL /livez

PRIMARY="${PRIMARY:-farci-ollama}"
API_KEY="${FARCI_API_KEY:-${GATEWAY_KEY_STANDARD:-}}"

docker stop "$PRIMARY" >/dev/null 2>&1 || true
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 120 \
  -X POST "$FARCI_GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"model\":\"${FARCI_MODEL_ALIAS:-med-extraction}\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}],\"max_tokens\":1}" \
  2>/dev/null || true)
docker start "$PRIMARY" >/dev/null 2>&1 || true

if [[ "$code" == "200" ]]; then
  test_pass "repli 200 sans $PRIMARY"
else
  test_fail "repli : code $code sans $PRIMARY"
fi

test_finish
