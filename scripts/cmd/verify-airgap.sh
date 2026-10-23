#!/usr/bin/env bash
# FARCI — ./bin/farci verify-airgap
# Vérifie que l'atelier peut se dérouler sans Internet.
# Délègue à ./verify-airgap.sh, qui reste utilisable directement.
#
#   ./bin/farci verify-airgap
#   ./bin/farci verify-airgap --strict

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec "$FARCI_ROOT/verify-airgap.sh" "$@"
