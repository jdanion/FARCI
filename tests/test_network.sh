#!/usr/bin/env bash
# FARCI — test réseau (équipe 1) : votre Caddy répond et relaie l'agrégateur
# de santé. Sans CADDY_IP déclarée, le Caddy de cette machine (CADDY_PORT).

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="network"
test_start
test_local_default CADDY_URL CADDY_PORT
test_need_service CADDY_URL /livez

if curl -sf --max-time 5 "$CADDY_URL/status" >/dev/null 2>&1; then
  test_pass "caddy + /status"
else
  test_fail "Caddy répond mais /status est muet (health-aggregator ?)"
fi

test_finish
