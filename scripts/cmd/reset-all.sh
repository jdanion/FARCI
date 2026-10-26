#!/usr/bin/env bash
# FARCI — ./bin/farci reset-all : retour à un état propre connu
#
#   ./bin/farci reset-all          sur le Pi (ou la machine qui porte l'accueil)
#
# Dans l'ordre : répare les pannes de chaos actives, rend toutes les briques
# aux équipes (fin des rescue), recharge l'accueil de la salle, puis affiche
# le tableau. Ne touche ni aux adresses déclarées (room), ni aux extractions
# des étudiants (datasets/extracted/).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/lib/entry.sh
source "$FARCI_LIB_DIR/entry.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,10p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

farci_load_env

section "1/4 pannes de chaos"
"$FARCI_ROOT/chaos/chaos.sh" reset || warn "une panne n'a pas pu être réparée : voir ci-dessus"

section "2/4 bascules forcées"
rm -f "$FARCI_ROOT/config/rescue.env"
ok "toutes les briques sont rendues aux équipes"

section "3/4 accueil de la salle"
if have docker && docker info >/dev/null 2>&1; then
  farci_reload_entry
else
  warn "Docker indisponible sur cette machine : accueil non rechargé"
fi

section "4/4 tableau"
exec "$FARCI_ROOT/bin/farci" status
