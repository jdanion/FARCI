#!/usr/bin/env bash
# FARCI — vérification des images Docker locales (FARCI §7.2)
#
# Vérifie que toutes les images requises sont présentes localement et
# qu'elles correspondent aux versions figées dans versions.env.

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

farci_load_versions
# shellcheck source=scripts/lib/images.sh
source "$FARCI_ROOT/scripts/lib/images.sh"

section "FARCI — vérification des images Docker"

# Par défaut la chaîne cœur ; --all pour inclure les briques bonus.
scope=core
[[ "${1:-}" == "--all" ]] && scope=all
mapfile -t IMAGES < <(farci_images "$scope")

missing=0
present=0

for img in "${IMAGES[@]}"; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    ok "$img"
    present=$((present + 1))
  else
    warn "MANQUANTE : $img"
    missing=$((missing + 1))
  fi
done

printf '\n'
printf '%d présente(s), %d manquante(s)\n' "$present" "$missing"

if (( missing > 0 )); then
  printf 'Exécutez ./preload.sh --core pour télécharger les images manquantes.\n'
  exit 1
fi

ok "toutes les images requises sont présentes"
