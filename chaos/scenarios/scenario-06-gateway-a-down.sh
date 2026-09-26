#!/usr/bin/env bash
# FARCI — scénario 06 : arrêt de la gateway A
#
# Attendu : bascule vers B via Caddy, toujours http://192.168.50.15/v1

chaos_scenario_apply() {
  local duration="${1:-}"
  info "arrêt de la gateway A (LiteLLM)..."
  docker stop farci-litellm
  echo '{"scenario":"06","action":"stop","target":"farci-litellm"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    info "auto-revert dans ${duration}s..."
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  info "redémarrage de la gateway A..."
  docker start farci-litellm
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "gateway A restaurée"
}
