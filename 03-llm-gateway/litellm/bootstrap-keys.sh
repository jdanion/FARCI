#!/usr/bin/env bash
# FARCI — bootstrap des clés API LiteLLM
#
# Crée les clés API pour les étudiants et le formateur.
# Ces clés sont stockées dans la base SQLite de LiteLLM.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

LITELLM_URL="${GATEWAY_A_IP:-192.168.50.30}:4000"

section "FARCI — bootstrap clés LiteLLM"

# Clé standard (10 RPM, étudiants)
STANDARD_KEY="sk-standard-$(openssl rand -hex 12)"
info "création de la clé standard..."
curl -sf -X POST "http://$LITELLM_URL/key/generate" \
  -H "Authorization: Bearer sk-priority-placeholder" \
  -H "Content-Type: application/json" \
  -d "{
    \"key_alias\": \"standard\",
    \"rpm_limit\": 10
  }" && ok "clé standard créée" || warn "clé standard peut-être déjà existante"

# Clé priority (120 RPM, formateur)
PRIORITY_KEY="sk-priority-$(openssl rand -hex 12)"
info "création de la clé priority..."
curl -sf -X POST "http://$LITELLM_URL/key/generate" \
  -H "Authorization: Bearer sk-priority-placeholder" \
  -H "Content-Type: application/json" \
  -d "{
    \"key_alias\": \"priority\",
    \"rpm_limit\": 120
  }" && ok "clé priority créée" || warn "clé priority peut-être déjà existante"

ok "bootstrap terminé"
