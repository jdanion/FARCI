#!/usr/bin/env bash
# FARCI — test air-gap : images de la chaîne cœur présentes localement

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="airgap"
test_start

if ! have docker || ! docker info >/dev/null 2>&1; then
  test_skip "docker indisponible"
  test_finish
  exit $?
fi

if "$FARCI_ROOT/scripts/cmd/verify-images.sh" >/dev/null 2>&1; then
  test_pass "images présentes"
else
  test_fail "images manquantes (./bin/farci verify-images)"
fi

test_finish
