#!/usr/bin/env bash
# FARCI — la pile d'une machine seule (Pi, poste de démonstration)
#
#   ./bin/farci core-up        démarre la pile de référence (reference/) + Docling
#   ./bin/farci dashboard-up   accueil + agrégateur de santé ; affiche les adresses
#   ./bin/farci health         tableau, puis code 0 si le service rendu est READY
#
# Les noms viennent du cahier des charges (FARCI.md : make core-up,
# make dashboard-up, make health). Sur une machine seule, la « chaîne cœur »
# est la pile de référence : chaque brique y est servie par la référence (🛟).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,10p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

farci_load_env
FARCI="$FARCI_ROOT/bin/farci"

addresses() {
  printf '\n  Accueil de la salle   %s/livez\n' "${FARCI_ENTRY_URL:-?}"
  printf '  État (JSON)           %s\n' "${FARCI_STATUS_URL:-?}"
  printf '  Passerelle (OpenAI)   %s/models\n' "${FARCI_GATEWAY_URL:-?}"
  printf '  EDS-NLP               %s/health\n' "${FARCI_EDS_URL:-?}"
  printf '  Open WebUI            %s\n' "${REFERENCE_WEBUI_URL:-?}"
  printf '  Phoenix (traces)      http://%s:%s\n\n' "${REFERENCE_IP:-?}" "${PHOENIX_PORT:-?}"
}

case "${FARCI_TARGET:-}" in
  core-up)
    "$FARCI" up reference
    # Docling est dans CLINICAL PIPELINE READY : sans lui, le service rendu
    # reste DEGRADED. Image lourde (~2 Go) : son échec n'arrête pas le reste.
    "$FARCI" up reference docling || warn "Docling n'a pas démarré : ./bin/farci logs reference docling"
    addresses
    ;;
  dashboard-up)
    "$FARCI" up reference caddy health-aggregator
    addresses
    info "tableau en continu : ./bin/farci status --watch"
    ;;
  health)
    python3 "$FARCI_ROOT/scripts/board.py" || true
    python3 "$FARCI_ROOT/scripts/board.py" --json | python3 -c '
import json, sys
state = json.load(sys.stdin)["service_rendu"]
print("service rendu à la salle :", state["state"], "— il manque :", ", ".join(state.get("missing", [])) or "rien")
sys.exit(0 if state["state"] == "READY" else 1)'
    ;;
  *) die "ce script ne connaît pas la cible « ${FARCI_TARGET:-} » (voir scripts/targets.def)" ;;
esac
