#!/usr/bin/env bash
# FARCI — wrapper CLI pour le casting des équipes

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

exec python3 "$FARCI_ROOT/casting/casting.py" "$@"
