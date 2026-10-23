#!/usr/bin/env bash
# FARCI — scénario 07 : arrêt de l'observabilité
#
# Attendu : extraction réussie, traces perdues uniquement

SCENARIO_TITLE="Observabilité indisponible (Phoenix, Langfuse)"

chaos_scenario_apply() {
  info "arrêt de Phoenix et Langfuse..."
  docker stop farci-phoenix 2>/dev/null || warn "Phoenix introuvable"
  docker stop farci-langfuse 2>/dev/null || warn "Langfuse introuvable"
}

chaos_scenario_revert() {
  info "redémarrage de Phoenix et Langfuse..."
  docker start farci-phoenix 2>/dev/null || warn "Phoenix introuvable"
  docker start farci-langfuse 2>/dev/null || warn "Langfuse introuvable"
  ok "observabilité restaurée"
}
