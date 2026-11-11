#!/usr/bin/env bash
# FARCI — importe les poids locaux dans Ollama sous le nom logique `med-extraction`
#
#   02-inference/ollama/create-model.sh             choix automatique selon la RAM
#   02-inference/ollama/create-model.sh secours     Qwen3.5-2B          (~1,2 Go ; toute machine)
#   02-inference/ollama/create-model.sh qwen4b      Qwen3.5-4B          (~3 Go ; 8 Go de RAM)
#   02-inference/ollama/create-model.sh gemma4b     Gemma 4 E4B         (~5 Go ; 12 Go de RAM)
#   02-inference/ollama/create-model.sh medgemma4b  MedGemma 4B         (~3 Go ; 8 Go de RAM ; médical)
#   02-inference/ollama/create-model.sh principal   Ornith-1.5-9B       (~6,5 Go ; 16 Go de RAM)
#   02-inference/ollama/create-model.sh moe         Ornith-1.5-35B-A3B  (~22 Go ; GPU 24 Go ou 48 Go de RAM)
#   02-inference/ollama/create-model.sh liste       ce qui est présent sur ce poste
#
# Comparer deux modèles : importer l'un, extraire (./bin/farci extract --run
# qwen4b), importer l'autre, extraire (--run gemma4b), puis ./bin/farci
# evaluate classe les deux runs. L'application, elle, n'a pas changé.
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
  sed -n '2,20p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

CONTAINER="${OLLAMA_CONTAINER:-farci-ollama}"
# Le catalogue : choix → fichier (models/models.env) et alias propre au modèle.
declare -A GGUF=(
  [secours]="Qwen3.5-2B-Q4_K_M.gguf"
  [qwen4b]="Qwen3.5-4B-Q4_K_M.gguf"
  [gemma4b]="gemma-4-E4B-it-Q4_K_M.gguf"
  [medgemma4b]="medgemma-4b-it-UD-Q4_K_XL.gguf"
  [principal]="Ornith-1.5-9B-Q5_K_M.gguf"
  [moe]="Ornith-1.5-35B-Q4_K_M.gguf"
)
ORDER=(secours qwen4b gemma4b medgemma4b principal moe)
SECOURS="${GGUF[secours]}"
has() { docker exec "$CONTAINER" test -f "/gguf/$1"; }

choice="${1:-auto}"
if [[ "$choice" == "liste" ]]; then
  for c in "${ORDER[@]}"; do
    if has "${GGUF[$c]}"; then printf '  %-10s %s\n' "$c" "${GGUF[$c]}"
    else printf '  %-10s %s (absent : ./preload.sh --equipe 2)\n' "$c" "${GGUF[$c]}"; fi
  done
  exit 0
fi
if [[ "$choice" == "auto" ]]; then
  ram_gb="$(awk '/MemTotal/ {printf "%d", ($2 + 524288) / 1048576}' /proc/meminfo 2>/dev/null || echo 0)"
  if [[ "$(uname)" == "Darwin" ]]; then
    ram_gb="$(( $(sysctl -n hw.memsize) / 1073741824 ))"
  fi
  # Le plus grand modèle que la machine tient confortablement ET qui est là.
  # Le mélange d'experts (moe) n'est jamais choisi d'office.
  choice=secours
  (( ram_gb >= 8 )) && has "${GGUF[qwen4b]}" && choice=qwen4b
  (( ram_gb >= 16 )) && has "${GGUF[principal]}" && choice=principal
  info "RAM détectée : ${ram_gb} Go → modèle $choice"
fi
gguf="${GGUF[$choice]:-}"
[[ -n "$gguf" ]] || die "choix inconnu : $choice (secours | qwen4b | gemma4b | medgemma4b | principal | moe | liste)"

section "FARCI — import de $gguf sous le nom med-extraction"
docker exec "$CONTAINER" test -f "/gguf/$gguf" \
  || die "/gguf/$gguf absent dans $CONTAINER : ./bin/farci verify-models (FARCI_MODELS_DIR)"

import() {
  local name="$1" file="$2"
  docker exec "$CONTAINER" sh -c "printf 'FROM /gguf/%s\nPARAMETER temperature 0\nPARAMETER num_ctx 8192\n' '$file' > /tmp/Modelfile.$name && ollama create $name -f /tmp/Modelfile.$name" \
    && ok "$name ← $file" || die "import de $name échoué"
}

import med-extraction "$gguf"
# Le modèle de secours est aussi exposé sous son propre alias, s'il est là :
# c'est vers lui que la passerelle se replie.
if [[ "$gguf" != "$SECOURS" ]] && has "$SECOURS"; then
  import med-extraction-lite "$SECOURS"
fi
docker exec "$CONTAINER" ollama list
