#!/usr/bin/env bash
# FARCI — ./bin/farci test
# Tests d'intégration des briques déployées (tests/run-all.sh).
# Une brique absente est SKIP ; FARCI_TESTS_STRICT=1 en fait un échec.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec "$FARCI_ROOT/tests/run-all.sh" "$@"
