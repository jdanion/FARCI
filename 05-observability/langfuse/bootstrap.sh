#!/usr/bin/env bash
# FARCI — bootstrap Langfuse
#
# Vérifie que Langfuse est accessible et crée un projet de test.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

LANGFUSE_URL="${LANGFUSE_URL:?OBSERVABILITY_B_IP/LANGFUSE_PORT manquants : voir config/network.env}"

section "FARCI — bootstrap Langfuse"

info "vérification de Langfuse..."
if curl -sf "$LANGFUSE_URL/api/public/health" >/dev/null 2>&1; then
  ok "Langfuse répond"
else
  warn "Langfuse ne répond pas"
  exit 1
fi

info "création d'un projet de test..."
curl -sf -X POST "$LANGFUSE_URL/api/public/projects" \
  -H "Content-Type: application/json" \
  -d '{"name": "farci-workshop"}' || warn "projet peut-être déjà existant"

ok "bootstrap Langfuse terminé"
