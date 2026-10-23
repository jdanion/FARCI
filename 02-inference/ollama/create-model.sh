#!/usr/bin/env bash
# FARCI — importe les modèles GGUF dans Ollama
#
# Les poids sont déjà présents dans $FARCI_MODELS_DIR (préchargés en phase 1).
# Aucun `ollama pull` : on crée les modèles depuis les fichiers locaux.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

OLLAMA_HOST="${OLLAMA_HOST:-${INFERENCE_A_URL:?INFERENCE_A_IP/INFERENCE_PORT manquants : voir config/network.env}}"
MODELS_DIR="${FARCI_MODELS_DIR}"

section "FARCI — import des modèles dans Ollama"

# Vérifier qu'Ollama répond
if ! curl -sf "$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
  err "Ollama ne répond pas sur $OLLAMA_HOST"
  exit 1
fi

# Modèles à importer
declare -A MODELS=(
  ["ornith-1.5-9b-q5km"]="Ornith-1.5-9B-Q5_K_M.gguf"
  ["ornith-1.5-9b-q4km"]="Ornith-1.5-9B-Q4_K_M.gguf"
  ["qwen3.8-27b-q4km"]="Qwen3.8-27B-Q4_K_M.gguf"
  ["qwen3.5-2b-q4km"]="Qwen3.5-2B-Q4_K_M.gguf"
)

for model in "${!MODELS[@]}"; do
  gguf="${MODELS[$model]}"
  if [[ ! -f "$MODELS_DIR/$gguf" ]]; then
    warn "GGUF absent : $gguf — import de $model ignoré"
    continue
  fi

  info "import de $model depuis $gguf..."
  curl -sf -X POST "$OLLAMA_HOST/api/create" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$model\",
      \"modelfile\": \"FROM /models/$gguf\nPARAMETER temperature 0\n\"
    }" && ok "$model importé" || warn "import de $model a échoué"
done

ok "import terminé"
