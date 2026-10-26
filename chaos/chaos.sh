#!/usr/bin/env bash
# FARCI — chaos engineering dispatcher (FARCI §43)
#
# Interface unique : apply et revert (idempotents)
# État persisté dans .chaos/state.json (liste des pannes actives)

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=chaos/lib/chaos_lib.sh
source "$FARCI_ROOT/chaos/lib/chaos_lib.sh"

farci_load_env

usage() {
  cat <<'USAGE'
Usage : ./chaos/chaos.sh <commande> [options]

Commandes :
  list                    Lister les scénarios
  scenario-NN             Appliquer le scénario NN
  revert scenario-NN      Réparer un seul scénario
  status                  Pannes actives
  reset                   Réparer toutes les pannes actives

Options :
  --duration <secondes>   Auto-revert après N secondes
  --help                  Afficher cette aide

Exemples :
  ./chaos/chaos.sh list
  ./chaos/chaos.sh scenario-01
  ./chaos/chaos.sh scenario-01 --duration 60
  ./chaos/chaos.sh reset
USAGE
}

main() {
  local cmd="${1:-list}"
  shift || true
  [[ "$cmd" == -h || "$cmd" == --help || "$cmd" == help ]] && { usage; return 0; }

  case "$cmd" in
    list)
      chaos_list
      ;;
    status)
      chaos_status
      ;;
    reset)
      chaos_reset
      ;;
    scenario-*)
      chaos_apply "$cmd" "$@"
      exit "${CHAOS_CHECK_RC:-0}"
      ;;
    revert)
      chaos_revert "${1:-}" || { err "usage : revert scenario-NN"; exit 64; }
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      err "commande inconnue : $cmd"
      usage
      exit 64
      ;;
  esac
}

main "$@"
