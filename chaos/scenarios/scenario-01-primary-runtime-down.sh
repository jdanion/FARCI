#!/usr/bin/env bash
# FARCI — scénario 01 : arrêt du runtime primaire
#
# Attendu : gateway 200, en-tête fallback, client inchangé

chaos_scenario_apply() {
  local duration="${1:-}"
  info "arrêt du runtime primaire (Ollama)..."
  docker stop farci-ollama
  echo '{"scenario":"01","action":"stop","target":"farci-ollama"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    info "auto-revert dans ${duration}s..."
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  info "redémarrage du runtime primaire..."
  docker start farci-ollama
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "runtime primaire restauré"
}
