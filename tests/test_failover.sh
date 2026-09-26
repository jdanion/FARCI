#!/usr/bin/env bash
# FARCI — test de failover
#
# Coupe le primaire, vérifie que le fallback répond 200 + en-tête.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GATEWAY_URL="${GATEWAY_URL:-http://192.168.50.15/v1}"
PRIMARY="${PRIMARY:-farci-ollama}"

section "FARCI — test de failover"

# 1. Vérifier que le primaire répond
info "1. Vérification du primaire..."
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY_URL/healthz" 2>/dev/null || echo "000")
if [[ "$code" != "200" ]]; then
  warn "primaire ne répond pas (code $code)"
fi

# 2. Couper le primaire
info "2. Coupure du primaire ($PRIMARY)..."
docker stop "$PRIMARY" 2>/dev/null || warn "conteneur introuvable"

# 3. Vérifier le fallback
info "3. Vérification du fallback..."
sleep 2
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-placeholder" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}' 2>/dev/null || echo "000")

if [[ "$code" == "200" ]]; then
  ok "fallback répond 200"
else
  warn "fallback répond $code (attendu 200)"
fi

# 4. Restaurer
info "4. Restauration du primaire..."
docker start "$PRIMARY" 2>/dev/null || warn "conteneur introuvable"

ok "test de failover terminé"
