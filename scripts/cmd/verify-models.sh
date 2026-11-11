#!/usr/bin/env bash
# FARCI — vérification des poids de modèles (FARCI §9)
#
#   ./bin/farci verify-models          les fichiers GGUF présents sur ce poste
#   ./bin/farci verify-models --urls   AVEC Internet : chaque adresse de
#                                      models/models.env répond-elle encore ?
#
# Le modèle de secours (Qwen3.5-2B) est le seul exigé : les autres dépendent
# de la machine (02-inference/ollama/create-model.sh liste).

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

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

# --urls : une requête d'en-tête par adresse, aucun téléchargement.
if [[ "${1:-}" == "--urls" ]]; then
  section "FARCI — adresses des modèles (models/models.env)"
  failed=0
  while IFS='=' read -r key url; do
    [[ "$key" == *_URL ]] || continue
    code="$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 20 "$url" 2>/dev/null)" || true
    if [[ "$code" == 200 ]]; then
      ok "$(basename "$url")"
    else
      err "$(basename "$url") : HTTP ${code:-000} — $url"
      failed=$(( failed + 1 ))
    fi
  done < <(emit_env_file "$FARCI_ROOT/models/models.env")
  (( failed == 0 )) || die "$failed adresse(s) à corriger dans models/models.env (dépôt renommé ? fichier absent ?)"
  ok "toutes les adresses répondent"
  exit 0
fi

section "FARCI — vérification des poids de modèles"

MODELS_DIR="$FARCI_MODELS_DIR"

if [[ ! -d "$MODELS_DIR" ]]; then
  err "répertoire des modèles absent : $MODELS_DIR"
  printf 'Exécutez ./preload.sh --equipe 2 (ou --models-ci) pour télécharger les poids.\n'
  exit 1
fi

# Le catalogue (models/models.env) : fichier, puis à quoi il sert.
CATALOG=(
  "Qwen3.5-2B-Q4_K_M.gguf|secours, toute machine"
  "Qwen3.5-4B-Q4_K_M.gguf|4B, à comparer avec Gemma (8 Go de RAM)"
  "gemma-4-E4B-it-Q4_K_M.gguf|4B, à comparer avec Qwen (12 Go de RAM)"
  "medgemma-4b-it-UD-Q4_K_XL.gguf|4B spécialisé médecine (8 Go de RAM)"
  "Ornith-1.5-9B-Q5_K_M.gguf|principal, grosse configuration"
  "Ornith-1.5-35B-Q4_K_M.gguf|mélange d'experts, machine puissante"
)

present=0
for entry in "${CATALOG[@]}"; do
  f="${entry%%|*}"
  if [[ -f "$MODELS_DIR/$f" ]]; then
    ok "$f ($(du -h "$MODELS_DIR/$f" | cut -f1)) — ${entry#*|}"
    present=$((present + 1))
  else
    info "absent : $f — ${entry#*|}"
  fi
done

printf '\n%d modèle(s) présent(s) sur %d\n' "$present" "${#CATALOG[@]}"

if [[ ! -f "$MODELS_DIR/Qwen3.5-2B-Q4_K_M.gguf" ]]; then
  warn "le modèle de secours manque : ./preload.sh --models-ci"
  exit 1
fi

ok "poids de modèles vérifiés"
