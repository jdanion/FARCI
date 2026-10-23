#!/usr/bin/env bash
# FARCI — test réseau : Caddy répond et relaie l'agrégateur de santé

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="network"
test_start
test_need_service CADDY_URL /healthz

if curl -sf --max-time 5 "$FARCI_STATUS_URL" >/dev/null 2>&1; then
  test_pass "caddy + /status"
else
  test_fail "Caddy répond mais /status est muet (health-aggregator ?)"
fi

test_finish
