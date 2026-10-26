#!/usr/bin/env bash
# FARCI — ./bin/farci chaos
# Étape 3 : pannes réversibles. Délègue à ./chaos/chaos.sh.
#
#   ./bin/farci chaos list
#   ./bin/farci chaos scenario-01
#   ./bin/farci chaos status
#   ./bin/farci chaos reset

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec "$FARCI_ROOT/chaos/chaos.sh" "$@"
