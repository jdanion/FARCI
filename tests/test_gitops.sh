#!/usr/bin/env bash
# FARCI — test GitOps : Gitea accessible (brique bonus)

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="gitops"
test_start
test_local_default GITEA_URL GITEA_PORT
test_need_service GITEA_URL /api/healthz

if curl -sf --max-time 5 "$GITEA_URL/api/healthz" >/dev/null 2>&1; then
  test_pass "gitea"
else
  test_fail "gitea ne répond pas"
fi

test_finish
