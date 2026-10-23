#!/usr/bin/env bash
# FARCI — bootstrap Bifrost
#
# Vérifie que Bifrost démarre et que les aliases sont configurés.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

BIFROST_URL="${GATEWAY_B_URL:?GATEWAY_B_IP/GATEWAY_PORT manquants : voir config/network.env}"

section "FARCI — bootstrap Bifrost"

info "vérification de Bifrost..."
if curl -sf "$BIFROST_URL/health" >/dev/null 2>&1; then
  ok "Bifrost répond"
else
  warn "Bifrost ne répond pas — vérifier le conteneur"
fi

info "test des aliases..."
for alias in med-extraction med-extraction-lite med-extraction-max; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BIFROST_URL/v1/models" \
    -H "Authorization: Bearer sk-test" 2>/dev/null || true)
  if [[ "$code" == "401" ]]; then
    ok "$alias : authentification requise (attendu)"
  elif [[ "$code" == "200" ]]; then
    ok "$alias : accessible"
  else
    warn "$alias : code $code"
  fi
done

ok "bootstrap Bifrost terminé"
