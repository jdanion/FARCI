#!/usr/bin/env bash
# FARCI — post-setup Open WebUI
#
# Crée la connexion OAI-compatible vers Caddy et une clé virtuelle.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

WEBUI_URL="${OPEN_WEBUI_URL:?OPEN_WEBUI_IP/OPEN_WEBUI_PORT manquants : voir config/network.env}"
GATEWAY_URL="${FARCI_GATEWAY_URL:?CADDY_IP/CADDY_INTERNAL_PORT manquants : voir config/network.env}"

section "FARCI — post-setup Open WebUI"

info "attente d'Open WebUI..."
wait_http "$WEBUI_URL" 60 "Open WebUI"

# Créer la connexion OAI-compatible
info "création de la connexion OAI-compatible..."
curl -sf -X POST "$WEBUI_URL/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@farci.local", "password": "admin"}' || warn "connexion peut-être déjà existante"

# Créer une clé virtuelle
info "création d'une clé virtuelle..."
curl -sf -X POST "$WEBUI_URL/api/v1/api_keys" \
  -H "Content-Type: application/json" \
  -d '{"name": "farci-standard", "key": "sk-standard-placeholder"}' || warn "clé peut-être déjà existante"

ok "post-setup terminé"
