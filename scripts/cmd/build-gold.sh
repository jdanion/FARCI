#!/usr/bin/env bash
# FARCI — ./bin/farci build-gold
# Génère le gold standard depuis le registre des cas

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec python3 "$FARCI_ROOT/datasets/tools/build_gold.py" "$@"
