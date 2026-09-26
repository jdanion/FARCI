#!/usr/bin/env bash
# FARCI — ./bin/farci make-quick-set
# Crée le sous-ensemble quick (10 premiers cas)

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec python3 "$FARCI_ROOT/datasets/tools/make_quick_set.py" "$@"
