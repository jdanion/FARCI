#!/usr/bin/env bash
# FARCI — démonstration de failover gateway
#
# Monte le primaire, fait une requête, coupe le primaire,
# refait une requête et vérifie que le fallback répond.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GATEWAY_URL="${GATEWAY_A_URL:?GATEWAY_A_IP/GATEWAY_PORT manquants : voir config/network.env}"
PRIMARY="${PRIMARY:-farci-ollama}"
SECONDARY="${SECONDARY:-farci-llamacpp}"

section "FARCI — démonstration de failover"

# 1. Requête normale
info "1. Requête normale (primaire)..."
start=$(date +%s%N)
response=$(curl -sf -X POST "$GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-placeholder" \
  -d '{
    "model": "med-extraction",
    "messages": [{"role": "user", "content": "test"}],
    "max_tokens": 16
  }') && ok "primaire répond" || warn "primaire ne répond pas"

# 2. Couper le primaire
info "2. Coupure du primaire ($PRIMARY)..."
docker stop "$PRIMARY" 2>/dev/null || warn "conteneur introuvable"

# 3. Requête avec fallback
info "3. Requête avec fallback ($SECONDARY)..."
start=$(date +%s%N)
response=$(curl -sf -X POST "$GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-placeholder" \
  -d '{
    "model": "med-extraction",
    "messages": [{"role": "user", "content": "test fallback"}],
    "max_tokens": 16
  }') && {
  end=$(date +%s%N)
  latency=$(( (end - start) / 1000000 ))
  ok "fallback répond en ${latency}ms"
} || warn "fallback ne répond pas"

# 4. Restaurer le primaire
info "4. Restauration du primaire..."
docker start "$PRIMARY" 2>/dev/null || warn "conteneur introuvable"

ok "démonstration terminée"
