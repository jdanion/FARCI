#!/usr/bin/env bash
# FARCI — test d'observabilité : Phoenix, Langfuse

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="observability"
test_start

# Phoenix
if curl -sf "http://192.168.50.51:6006/health" >/dev/null 2>&1; then
  test_pass "phoenix"
else
  test_fail "phoenix ne répond pas"
fi

test_finish
