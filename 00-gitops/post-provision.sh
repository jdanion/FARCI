#!/usr/bin/env bash
# FARCI — post-provisionnement Gitea : protection de la branche main
#
# Ce script est exécuté après le bootstrap pour :
# 1. Protéger la branche main (push direct interdit, PR obligatoire)
# 2. Activer les status checks
# 3. Configurer les reviewers

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GITEA_URL="${GITEA_ROOT_URL:-http://192.168.50.10:3000}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-farci-admin}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:?GITEA_ADMIN_PASSWORD requis}"

section "FARCI — post-provisionnement Gitea"

# Protéger la branche main
info "protection de la branche main..."
curl -sf -X PATCH "$GITEA_URL/api/v1/repos/FARCI/farci/branches/main/protection" \
  -H "Content-Type: application/json" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" \
  -d '{
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "enable_status_check": true,
    "block_on_rejected_reviews": true,
    "prevent_push": true,
    "enforce_admins": false
  }' || warn "protection de la branche main a échoué (peut-être déjà active)"

ok "post-provisionnement terminé"
