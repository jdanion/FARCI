#!/usr/bin/env bash
# FARCI — scénario 01 : arrêt du runtime primaire
#
# Attendu : gateway 200, en-tête fallback, client inchangé

SCENARIO_TITLE="Panne du runtime principal (Ollama)"

chaos_scenario_apply() {
  info "arrêt du runtime primaire (Ollama)..."
  docker stop farci-ollama
}

chaos_scenario_revert() {
  info "redémarrage du runtime primaire..."
  docker start farci-ollama
  ok "runtime primaire restauré"
}
