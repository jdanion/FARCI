#!/usr/bin/env bash
# FARCI — scénario 06 : arrêt de la gateway A
#
# Attendu : bascule vers B via Caddy, toujours la même adresse (Caddy /v1)

SCENARIO_TITLE="Passerelle A (LiteLLM) indisponible"

chaos_scenario_apply() {
  info "arrêt de la gateway A (LiteLLM)..."
  docker stop farci-litellm
}

chaos_scenario_revert() {
  info "redémarrage de la gateway A..."
  docker start farci-litellm
  ok "gateway A restaurée"
}
