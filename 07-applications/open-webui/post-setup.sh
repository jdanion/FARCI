#!/usr/bin/env bash
# FARCI — vérification d'Open WebUI après démarrage
#
#   07-applications/open-webui/post-setup.sh
#
# Rien à configurer à la main : la connexion à la passerelle (l'accueil de la
# salle, /v1) est donnée par docker-compose.yml, sans compte (WEBUI_AUTH=False).
# Ce script attend l'interface, vérifie que la passerelle propose bien
# med-extraction, et affiche l'adresse à ouvrir.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env
export no_proxy='*' NO_PROXY='*'

# L'Open WebUI de CETTE machine, sauf si OPEN_WEBUI_IP est déclarée.
WEBUI_URL="${OPEN_WEBUI_URL:-http://127.0.0.1:${OPEN_WEBUI_PORT:?OPEN_WEBUI_PORT manquant (config/network.env)}}"
GATEWAY_URL="${FARCI_GATEWAY_URL:?REFERENCE_IP/ENTRY_PORT manquants : voir config/network.env}"

section "FARCI — vérification d'Open WebUI"

info "attente d'Open WebUI (le premier démarrage est long)..."
wait_http "$WEBUI_URL/health" 120 "Open WebUI"

if curl -sf --max-time 10 "$GATEWAY_URL/models" | grep -q '"med-extraction"'; then
  ok "la passerelle propose med-extraction ($GATEWAY_URL)"
else
  warn "la passerelle ne répond pas ou ne propose pas med-extraction : ./bin/farci test"
fi

ok "ouvrir $WEBUI_URL dans un navigateur (aucun compte à créer)"
