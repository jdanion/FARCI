#!/usr/bin/env bash
# FARCI — scénario 06 : passerelle de l'équipe indisponible
#
# Action    : l'accueil ignore la passerelle de l'équipe 3 (ou l'équipe
#             l'arrête : ./bin/farci down 03-llm-gateway/litellm).
# Attendu   : la passerelle suivante (Bifrost si l'équipe l'a monté, sinon la
#             référence) répond, À LA MÊME ADRESSE.
# Leçon     : le client ne connaît qu'un point d'entrée logique.

SCENARIO_TITLE="Passerelle de l'équipe indisponible"
SCENARIO_ATTENDU="l'extraction répond toujours (200), même adresse"

chaos_scenario_apply() {
  chaos_route exclude passerelle
}

chaos_scenario_check() {
  local code
  code="$(chaos_chat_code)"
  chaos_expect "extraction servie par une autre passerelle (HTTP $code)" test "$code" = 200
}

chaos_scenario_revert() {
  chaos_route_clear passerelle
  ok "passerelle de l'équipe 3 rendue à l'accueil"
}
