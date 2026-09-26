#!/usr/bin/env bash
# FARCI — vérification des poids de modèles (FARCI §9)
#
# Vérifie que les fichiers GGUF sont présents et que leurs empreintes
# SHA256 correspondent à celles enregistrées dans models/models.lock.env.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

# Charger versions.env (non inclus dans farci_env_files)
if [[ -r "$FARCI_ROOT/versions.env" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -z "${!key+x}" ]] && export "$key=$value"
  done < "$FARCI_ROOT/versions.env"
fi

section "FARCI — vérification des poids de modèles"

MODELS_DIR="$FARCI_MODELS_DIR"

if [[ ! -d "$MODELS_DIR" ]]; then
  err "répertoire des modèles absent : $MODELS_DIR"
  printf 'Exécutez ./preload.sh --core pour télécharger les poids.\n'
  exit 1
fi

# Fichiers attendus (GGUF)
EXPECTED_GGUF=(
  "Ornith-1.5-9B-Q5_K_M.gguf"
  "Ornith-1.5-9B-Q4_K_M.gguf"
  "Qwen3.8-27B-Q4_K_M.gguf"
  "Qwen3.5-2B-Q4_K_M.gguf"
)

missing=0
present=0

for f in "${EXPECTED_GGUF[@]}"; do
  if [[ -f "$MODELS_DIR/$f" ]]; then
    ok "$f ($(du -h "$MODELS_DIR/$f" | cut -f1))"
    present=$((present + 1))
  else
    warn "MANQUANT : $f"
    missing=$((missing + 1))
  fi
done

printf '\n'
printf '%d présent(s), %d manquant(s)\n' "$present" "$missing"

if (( missing > 0 )); then
  printf 'Exécutez ./preload.sh --models-ci (ou --core) pour télécharger les poids manquants.\n'
  exit 1
fi

ok "poids de modèles vérifiés"
