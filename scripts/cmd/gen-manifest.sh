#!/usr/bin/env bash
# FARCI — génère offline/MANIFEST.sha256 (FARCI §51)
#
# Calcule le sha256 de tous les fichiers du répertoire offline/ et écrit
# le manifeste. Ce manifeste permet de vérifier l'intégrité des artefacts
# avant le workshop.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

OFFLINE_DIR="$FARCI_OFFLINE_DIR"
MANIFEST_FILE="$FARCI_MANIFEST"

section "FARCI — génération du manifeste"

if [[ ! -d "$OFFLINE_DIR" ]]; then
  err "répertoire offline absent : $OFFLINE_DIR"
  printf 'Exécutez d'\''abord ./bootstrap.sh puis ./preload.sh --core\n'
  exit 1
fi

manifest_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp"' EXIT

# Calculer le sha256 de chaque fichier (sauf le manifeste lui-même)
while IFS= read -r -d '' file; do
  rel="${file#"$OFFLINE_DIR"/}"
  [[ "$rel" == "MANIFEST.sha256" ]] && continue
  sha256sum "$file" | awk -v r="$rel" '{print $1 "  " r}'
done < <(find "$OFFLINE_DIR" -type f -print0) >> "$manifest_tmp"

# Trier pour un manifeste déterministe
sort -k2 "$manifest_tmp" > "$MANIFEST_FILE"

count=$(wc -l < "$MANIFEST_FILE")
ok "manifeste généré : $MANIFEST_FILE ($count fichiers)"

if [[ "$count" -eq 0 ]]; then
  warn "le manifeste est vide — aucun artefact n'\''est encore présent"
  warn "Exécutez ./preload.sh --core pour télécharger les artefacts"
fi
