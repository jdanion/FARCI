#!/usr/bin/env bash
# FARCI — scénario 01 : panne du runtime principal
#
# Action    : l'accueil ne joint plus le runtime de l'équipe 2 (ou l'équipe
#             l'arrête vraiment : ./bin/farci down 02-inference/ollama).
# Attendu   : une extraction répond toujours 200, par le même point d'entrée ;
#             le tableau montre Inference 🛟 REF.
# Leçon     : la redondance n'existe que si elle est exercée.

SCENARIO_TITLE="Panne du runtime principal"
SCENARIO_ATTENDU="l'extraction répond toujours (200), sans changer d'adresse"

chaos_scenario_apply() {
  info "l'accueil ignore le runtime de l'équipe 2 (la doublure prend le relais)"
  info "variante vivante : l'équipe 2 lance ./bin/farci down 02-inference/ollama"
  chaos_route exclude inference
}

chaos_scenario_check() {
  local code
  code="$(chaos_chat_code)"
  chaos_expect "extraction servie malgré la panne (HTTP $code)" test "$code" = 200
}

chaos_scenario_revert() {
  chaos_route_clear inference
  ok "runtime de l'équipe 2 rendu à l'accueil"
}
