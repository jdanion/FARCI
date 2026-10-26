#!/usr/bin/env bash
# FARCI — ./bin/farci rescue : basculer une brique sur la référence, en une commande
#
#   ./bin/farci rescue                    état des routes de l'accueil
#   ./bin/farci rescue <brique>           la référence sert seule cette brique
#   ./bin/farci rescue --off <brique>     rend la main à l'équipe
#
# Briques : inference (équipe 2), passerelle (3), documents (Docling, 4),
# eds (EDS-NLP, 4), observabilite (5). On accepte aussi equipe-2 … equipe-5
# (equipe-4 bascule Docling ET EDS-NLP).
#
# Sans rescue, l'accueil bascule DÉJÀ tout seul quand la brique de l'équipe
# ne répond pas. rescue sert quand elle répond MAL (modèle trop lent,
# réponses fausses, équipe qui veut réparer tranquillement). À lancer sur la
# machine qui porte l'accueil de la salle (le Pi) : effet en quelques secondes.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/lib/entry.sh
source "$FARCI_LIB_DIR/entry.sh"

usage() { sed -n '2,14p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

farci_load_env
SERVICES_PY="$FARCI_ROOT/scripts/services.py"
STATE="$FARCI_ROOT/config/rescue.env"

route_of() {
  case "$1" in
    inference|runtime|equipe-2|2)          echo inference ;;
    passerelle|gateway|equipe-3|3)         echo passerelle ;;
    documents|docling)                     echo documents ;;
    eds|eds-nlp)                           echo eds ;;
    equipe-4|4)                            echo documents; echo eds ;;
    observabilite|phoenix|equipe-5|5)      echo observabilite ;;
    reseau|accueil|caddy|equipe-1|1)
      info "l'accueil de la salle est déjà celui du Pi : rien à basculer pour l'équipe 1"
      exit 0 ;;
    webui|open-webui|equipe-7|7)
      info "faire ouvrir l'Open WebUI de la référence : ${REFERENCE_WEBUI_URL:-http://<REFERENCE_IP>:<OPEN_WEBUI_PORT>}"
      exit 0 ;;
    *) die "brique inconnue : $1 (inference | passerelle | documents | eds | observabilite)" ;;
  esac
}

current() { [[ -f "$STATE" ]] && sed -n 's/^FARCI_RESCUE=//p' "$STATE" || true; }

write_state() {
  printf '# Écrit par ./bin/farci rescue — routes servies par la référence seule\nFARCI_RESCUE=%s\n' "$1" > "$STATE"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "")
    section "Routes de l'accueil"
    python3 "$SERVICES_PY" routes | awk -F'\t' '{printf "  %-15s %s\n", $1, $2}'
    exit 0 ;;
  --off)
    [[ -n "${2:-}" ]] || die "usage : ./bin/farci rescue --off <brique>"
    routes="$(route_of "$2")"
    write_state "$(current | tr ',' '\n' | grep -vxF "$routes" | paste -sd, -)"
    ok "$(paste -sd, - <<< "$routes") : rendue(s) à l'équipe (si sa brique répond)"
    ;;
  *)
    routes="$(route_of "$1")"
    list="$(current)"
    while IFS= read -r route; do
      grep -qx "$route" <<< "${list//,/$'\n'}" || list="${list:+$list,}$route"
    done <<< "$routes"
    write_state "$list"
    ok "$(paste -sd, - <<< "$routes") : servie(s) par la référence 🛟"
    ;;
esac

farci_reload_entry
