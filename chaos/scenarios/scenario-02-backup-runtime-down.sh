#!/usr/bin/env bash
# FARCI — scénario 02 : arrêt du runtime secondaire
#
# Attendu : Kuma CLINICAL AI PIPELINE 🔴, gateway 503 documenté

SCENARIO_TITLE="Panne du runtime de secours (llama.cpp)"

chaos_scenario_apply() {
  info "arrêt du runtime secondaire (llama.cpp)..."
  docker stop farci-llamacpp
}

chaos_scenario_revert() {
  info "redémarrage du runtime secondaire..."
  docker start farci-llamacpp
  ok "runtime secondaire restauré"
}
