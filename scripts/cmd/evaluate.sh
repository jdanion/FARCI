#!/usr/bin/env bash
# FARCI — ./bin/farci evaluate
# Compare les extractions (datasets/extracted/<run>/) au gold standard et
# classe les runs par F1. Options : voir --help (06-evaluation/metrics/evaluate.py).
#
#   ./bin/farci evaluate
#   ./bin/farci evaluate --subset quick
#   ./bin/farci evaluate --extracted-dir datasets/gold     contrôle : score parfait

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
need_python

exec python3 "$FARCI_ROOT/06-evaluation/metrics/evaluate.py" "$@"
