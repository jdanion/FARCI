#!/usr/bin/env bash
# FARCI — scénario 05 : arrêt de Docling
#
# Attendu : pipeline document 🔴, gateway 🟢, inference 🟢

SCENARIO_TITLE="Docling indisponible"

chaos_scenario_apply() {
  info "arrêt de Docling..."
  docker stop farci-docling
}

chaos_scenario_revert() {
  info "redémarrage de Docling..."
  docker start farci-docling
  ok "Docling restauré"
}
