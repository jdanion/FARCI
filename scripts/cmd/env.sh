#!/usr/bin/env bash
# FARCI — configuration effective
#
# Cibles qui partagent ce script (voir scripts/targets.def) :
#   env         afficher la configuration effective (défaut)
#   env-check   valider la configuration, sortir en 1 si quelque chose manque
#
# Options : --print | --check

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

# L'aide est traitée EN PREMIER : elle ne doit dépendre ni du nom de la cible
# ni de la configuration, sinon `farci env --help` échouerait.
case "${1:-}" in
  -h|--help)
    echo "usage: $0 [--print|--check]"
    exit 0 ;;
esac

# Le nom de la cible choisit l'action ; un argument explicite l'emporte.
ACTION=""
case "${FARCI_TARGET:-env}" in
  env)       ACTION="--print" ;;
  env-check) ACTION="--check" ;;
  *)
    die "ce script ne connaît pas la cible « $FARCI_TARGET » (voir scripts/targets.def)"
    ;;
esac

case "${1:-}" in
  --print) ACTION="--print" ;;
  --check) ACTION="--check" ;;
  *)       die "option inconnue : $1 (voir --help)" ;;
esac

if [[ "$ACTION" == "--check" ]]; then
  farci_check_env && ok "configuration valide"
  exit $?
fi

farci_print_env
