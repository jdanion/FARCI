#!/usr/bin/env bash
# FARCI — scénario 02 : arrêt du runtime secondaire
#
# Attendu : Kuma CLINICAL AI PIPELINE 🔴, gateway 503 documenté

chaos_scenario_apply() {
  local duration="${1:-}"
  info "arrêt du runtime secondaire (llama.cpp)..."
  docker stop farci-llamacpp
  echo '{"scenario":"02","action":"stop","target":"farci-llamacpp"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    info "auto-revert dans ${duration}s..."
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  info "redémarrage du runtime secondaire..."
  docker start farci-llamacpp
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "runtime secondaire restauré"
}
