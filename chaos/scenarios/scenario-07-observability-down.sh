#!/usr/bin/env bash
# FARCI — scénario 07 : observabilité indisponible
#
# Action    : l'accueil ne reçoit plus AUCUNE trace (Phoenix d'équipe et de
#             référence injoignables).
# Attendu   : l'extraction réussit, seules les traces sont perdues ;
#             CLINICAL PIPELINE reste READY. Ce scénario doit rester VERT.
# Leçon     : l'observabilité n'est pas sur le chemin de production.

SCENARIO_TITLE="Observabilité indisponible"
SCENARIO_ATTENDU="extraction réussie, traces perdues"

chaos_scenario_apply() {
  chaos_route block observabilite
}

chaos_scenario_check() {
  local written errors
  read -r written _ errors <<< "$(chaos_extract 2)"
  chaos_expect "2 dossiers extraits sans observabilité ($written écrits, $errors erreurs)" test "$written" = 2
}

chaos_scenario_revert() {
  chaos_route_clear observabilite
  ok "observabilité rendue à l'accueil"
}
