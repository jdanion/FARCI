#!/usr/bin/env bash
# FARCI — scénario 02 : plus aucun runtime
#
# Action    : l'accueil ne sert plus AUCUN runtime (équipe ni référence).
# Attendu   : la passerelle renvoie une erreur documentée, le pipeline compte
#             des erreurs d'appel et n'écrit rien ; le tableau dit ce qui manque.
# Leçon     : la résilience a une profondeur ; il faut savoir où elle s'arrête.

SCENARIO_TITLE="Plus aucun runtime (principal et secours)"
SCENARIO_ATTENDU="erreur explicite, aucun dossier écrit"

chaos_scenario_apply() {
  chaos_route block inference
}

chaos_scenario_check() {
  local code
  code="$(chaos_chat_code)"
  chaos_expect "la passerelle refuse proprement (HTTP $code, pas 200)" test "$code" != 200
}

chaos_scenario_revert() {
  chaos_route_clear inference
  ok "runtimes rendus à l'accueil"
}
