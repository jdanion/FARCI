#!/usr/bin/env bash
# FARCI — ./bin/farci preload
# Précharge les artefacts air-gap (images, poids, wheels) : à faire AVEC Internet.
# Délègue à ./preload.sh, qui reste utilisable directement.
#
#   ./bin/farci preload --core
#   ./bin/farci preload --dry-run --core

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec "$FARCI_ROOT/preload.sh" "$@"
