#!/usr/bin/env bash
# FARCI — importe les poids locaux dans Ollama sous le nom logique `med-extraction`
#
#   02-inference/ollama/create-model.sh             choix automatique selon la RAM
#   02-inference/ollama/create-model.sh principal   Ornith-1.5-9B (≥ 16 Go de RAM)
#   02-inference/ollama/create-model.sh secours     Qwen3.5-2B (portable modeste, ~3 Go)
#
# Le nom servi est TOUJOURS `med-extraction` : la passerelle, le runtime de
# référence et le runtime rejoué parlent du même modèle logique. Changer de
# poids ne change rien pour la passerelle ni pour l'application (message 3).
# Les poids viennent de $FARCI_MODELS_DIR (préchargés), jamais d'Internet.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# « Ensuite : » quand le script est lancé directement (scripts/suite.def).
[[ -n "${FARCI_SUITE_PARENT:-}" ]] || trap 'farci_suite 02-inference/ollama/create-model.sh $?' EXIT
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,11p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

CONTAINER="${OLLAMA_CONTAINER:-farci-ollama}"
PRINCIPAL="Ornith-1.5-9B-Q5_K_M.gguf"
SECOURS="Qwen3.5-2B-Q4_K_M.gguf"

choice="${1:-auto}"
if [[ "$choice" == "auto" ]]; then
  ram_gb="$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)"
  if [[ "$(uname)" == "Darwin" ]]; then
    ram_gb="$(( $(sysctl -n hw.memsize) / 1073741824 ))"
  fi
  if (( ram_gb >= 16 )); then choice=principal; else choice=secours; fi
  info "RAM détectée : ${ram_gb} Go → modèle $choice"
fi
case "$choice" in
  principal) gguf="$PRINCIPAL" ;;
  secours)   gguf="$SECOURS" ;;
  *)         die "choix inconnu : $choice (principal | secours)" ;;
esac

section "FARCI — import de $gguf sous le nom med-extraction"
docker exec "$CONTAINER" test -f "/gguf/$gguf" \
  || die "/gguf/$gguf absent dans $CONTAINER : ./bin/farci verify-models (FARCI_MODELS_DIR)"

import() {
  local name="$1" file="$2"
  docker exec "$CONTAINER" sh -c "printf 'FROM /gguf/%s\nPARAMETER temperature 0\nPARAMETER num_ctx 8192\n' '$file' > /tmp/Modelfile.$name && ollama create $name -f /tmp/Modelfile.$name" \
    && ok "$name ← $file" || die "import de $name échoué"
}

import med-extraction "$gguf"
# Le modèle de secours est aussi exposé sous son propre alias, s'il est là.
if [[ "$gguf" != "$SECOURS" ]] && docker exec "$CONTAINER" test -f "/gguf/$SECOURS"; then
  import med-extraction-lite "$SECOURS"
fi
docker exec "$CONTAINER" ollama list
