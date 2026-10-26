#!/usr/bin/env bash
# FARCI — enregistre l'act_runner auprès de Gitea
#
# Le runner est déjà configuré via docker-compose.yml avec le token
# d'enregistrement. Ce script vérifie qu'il est bien enregistré.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# « Ensuite : » quand le script est lancé directement (scripts/suite.def).
[[ -n "${FARCI_SUITE_PARENT:-}" ]] || trap 'farci_suite 00-gitops/runner/register-runner.sh $?' EXIT
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GITEA_URL="${GITEA_URL:?GITEA_IP/GITEA_PORT manquants : voir config/network.env}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-farci-admin}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:?GITEA_ADMIN_PASSWORD requis}"

section "FARCI — enregistrement act_runner"

info "vérification du runner..."
runners=$(curl -sf "$GITEA_URL/api/v1/admin/runners" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data:
    print(f\"  {r['name']} ({r['status']})\")
" 2>/dev/null || echo "  (aucun runner ou erreur)")

if echo "$runners" | grep -q "farci-runner"; then
  ok "runner farci-runner enregistré"
else
  warn "runner farci-runner non trouvé"
  warn "  → vérifier que le conteneur act_runner est démarré"
  warn "  → vérifier GITEA_RUNNER_TOKEN dans .env"
fi
