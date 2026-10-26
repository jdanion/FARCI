#!/usr/bin/env bash
# FARCI — tableau de progression du workshop (FARCI §49)
#
#   ./bin/farci status              sonde la salle et affiche le tableau
#   ./bin/farci status --watch      rafraîchit en continu (écran de la salle)
#   ./bin/farci status --all        détaille aussi les briques bonus
#   ./bin/farci status --json       état de chaque service et du pipeline
#   ./bin/farci status --strict     code 1 si le pipeline des équipes n'est pas READY
#   ./bin/farci status --no-probe   n'interroge rien (utile hors ligne)
#
# Chaque ligne dit qui rend le service : ✅ l'équipe, 🛟 la référence du
# formateur, ou personne. Les lignes et les règles viennent de
# config/services.yaml ; le calcul est celui du health-aggregator
# (scripts/services.py, room_state) : les deux ne peuvent pas diverger.
#
# Au démarrage, tout est rouge (ou 🛟) : c'est le point de départ du §13.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env
need_python

WATCH=0
ARGS=()
while (( $# > 0 )); do
  case "$1" in
    --watch)   WATCH=1 ;;
    --timeout) shift; export FARCI_HEALTH_TIMEOUT="${1:-3}" ;;
    --all|--json|--strict|--no-probe) ARGS+=("$1") ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *)         err "option inconnue : $1"; exit 64 ;;
  esac
  shift
done

BOARD="$FARCI_ROOT/scripts/board.py"

if (( WATCH )); then
  while true; do
    frame="$(python3 "$BOARD" "${ARGS[@]}" 2>&1 || true)"
    printf '\033[H\033[2J%s\n' "$frame"
    sleep "${FARCI_STATUS_INTERVAL:-5}"
  done
fi

exec python3 "$BOARD" "${ARGS[@]}"
