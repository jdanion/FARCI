#!/usr/bin/env bash
# FARCI — vérification des wheels Python (FARCI §10, §52)
#
# Vérifie que les wheels Python nécessaires sont présents dans offline/wheels
# et qu'ils peuvent être installés sans accès réseau.

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

section "FARCI — vérification des wheels Python"

WHEELS_DIR="$FARCI_WHEELS_DIR"

if [[ ! -d "$WHEELS_DIR" ]]; then
  err "répertoire des wheels absent : $WHEELS_DIR"
  printf 'Exécutez ./preload.sh --core pour télécharger les wheels.\n'
  exit 1
fi

wheel_count=$(find "$WHEELS_DIR" -name "*.whl" | wc -l)
info "$wheel_count wheel(s) trouvé(s) dans $WHEELS_DIR"

if [[ "$wheel_count" -eq 0 ]]; then
  warn "aucun wheel présent"
  exit 1
fi

# Vérifier que pip peut résoudre les dépendances sans réseau
info "test d'installation --no-index (dry-run)..."
if pip3 install --no-index --find-links="$WHEELS_DIR" --dry-run -r "$FARCI_ROOT/requirements.in" >/dev/null 2>&1; then
  ok "les wheels permettent une installation hors ligne"
else
  warn "pip n'a pas pu résoudre toutes les dépendances avec les wheels disponibles"
  warn "  → exécuter ./preload.sh --core pour compléter"
  exit 1
fi

# Vérifier aussi les requirements eval
if [[ -f "$FARCI_ROOT/requirements-eval.txt" ]]; then
  if pip3 install --no-index --find-links="$WHEELS_DIR" --dry-run -r "$FARCI_ROOT/requirements-eval.txt" >/dev/null 2>&1; then
    ok "requirements-eval.txt : OK"
  else
    warn "requirements-eval.txt : dépendances manquantes"
  fi
fi

ok "wheels Python vérifiés"
