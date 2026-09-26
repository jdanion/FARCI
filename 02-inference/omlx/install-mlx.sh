#!/usr/bin/env bash
# FARCI — installation oMLX (Mac uniquement)
#
# Installe MLX et les dépendances nécessaires pour exécuter les modèles
# sur Apple Silicon.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

section "FARCI — installation oMLX"

# Vérifier qu'on est sur un Mac
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "oMLX est uniquement disponible sur macOS (Apple Silicon)"
  exit 1
fi

# Vérifier Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
  err "oMLX nécessite Apple Silicon (arm64)"
  exit 1
fi

info "installation de MLX..."
pip3 install --upgrade mlx mlx-lm mlx-vlm

info "vérification..."
python3 -c "import mlx; print(f'MLX {mlx.__version__}')" || {
  err "MLX n'est pas installé correctement"
  exit 1
}

ok "MLX installé"
