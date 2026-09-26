#!/usr/bin/env bash
# FARCI — test réseau : Caddy, health-aggregator, Uptime Kuma

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="network"
test_start

# Caddy
if curl -sf "http://192.168.50.15/healthz" >/dev/null 2>&1; then
  test_pass "caddy"
else
  test_fail "caddy ne répond pas"
fi

test_finish
