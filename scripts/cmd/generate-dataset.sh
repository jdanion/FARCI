#!/usr/bin/env bash
# FARCI — ./bin/farci generate-dataset
# Génère le dataset synthétique (PDF ou TXT si fpdf2 absent)

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec python3 "$FARCI_ROOT/datasets/tools/generate_dataset.py" "$@"
