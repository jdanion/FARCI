#!/usr/bin/env bash
# FARCI — test d'observabilité : Phoenix joignable

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="observability"
test_start
test_local_default PHOENIX_URL PHOENIX_PORT
test_need_service PHOENIX_URL /healthz

if [[ "$(http_code "$PHOENIX_URL/healthz")" == "200" ]]; then
  test_pass "phoenix"
else
  test_fail "phoenix ne répond pas 200 sur /healthz"
fi

test_finish
