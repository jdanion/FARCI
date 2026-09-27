#!/usr/bin/env bash
# FARCI — scénario 07 : arrêt de l'observabilité
#
# Attendu : extraction réussie, traces perdues uniquement

chaos_scenario_apply() {
  local duration="${1:-}"
  info "arrêt de Phoenix et Langfuse..."
  docker stop farci-phoenix 2>/dev/null || warn "Phoenix introuvable"
  docker stop farci-langfuse 2>/dev/null || warn "Langfuse introuvable"
  echo '{"scenario":"07","action":"stop","target":"phoenix,langfuse"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    info "auto-revert dans ${duration}s..."
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  info "redémarrage de Phoenix et Langfuse..."
  docker start farci-phoenix 2>/dev/null || warn "Phoenix introuvable"
  docker start farci-langfuse 2>/dev/null || warn "Langfuse introuvable"
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "observabilité restaurée"
}
