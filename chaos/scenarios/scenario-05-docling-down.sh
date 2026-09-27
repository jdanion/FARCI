#!/usr/bin/env bash
# FARCI — scénario 05 : arrêt de Docling
#
# Attendu : pipeline document 🔴, gateway 🟢, inference 🟢

chaos_scenario_apply() {
  local duration="${1:-}"
  info "arrêt de Docling..."
  docker stop farci-docling
  echo '{"scenario":"05","action":"stop","target":"farci-docling"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    info "auto-revert dans ${duration}s..."
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  info "redémarrage de Docling..."
  docker start farci-docling
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "Docling restauré"
}
