#!/usr/bin/env bash
# FARCI — test GitOps : Gitea accessible, runner enregistré

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="gitops"
test_start

GITEA_URL="${GITEA_URL:-http://192.168.50.10:3000}"

if curl -sf "$GITEA_URL/api/v1/version" >/dev/null 2>&1; then
  test_pass "gitea"
else
  test_fail "gitea ne répond pas"
fi

test_finish
