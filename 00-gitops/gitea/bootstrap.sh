#!/usr/bin/env bash
# FARCI — bootstrap Gitea : création org, utilisateur admin, dépôt
#
# Ce script est exécuté une fois après le démarrage de Gitea.
# Il crée l'organisation FARCI, l'utilisateur admin, et le dépôt farci.

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
GITEA_ADMIN_EMAIL="${GITEA_ADMIN_EMAIL:-admin@farci.local}"

section "FARCI — bootstrap Gitea"

info "attente de Gitea..."
wait_http "$GITEA_URL/api/v1/version" 60 "Gitea"

# Créer l'utilisateur admin
info "création de l'utilisateur admin..."
curl -sf -X POST "$GITEA_URL/api/v1/admin/users" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$GITEA_ADMIN_USER\",
    \"password\": \"$GITEA_ADMIN_PASSWORD\",
    \"email\": \"$GITEA_ADMIN_EMAIL\",
    \"must_change_password\": false
  }" || warn "utilisateur admin peut-être déjà existant"

# Créer l'organisation FARCI
info "création de l'organisation FARCI..."
curl -sf -X POST "$GITEA_URL/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" \
  -d "{
    \"username\": \"FARCI\",
    \"full_name\": \"FARCI Workshop\",
    \"description\": \"Forge du workshop FARCI\"
  }" || warn "organisation FARCI peut-être déjà existante"

# Créer le dépôt farci
info "création du dépôt farci..."
curl -sf -X POST "$GITEA_URL/api/v1/orgs/FARCI/repos" \
  -H "Content-Type: application/json" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" \
  -d "{
    \"name\": \"farci\",
    \"description\": \"Dépôt principal du workshop FARCI\",
    \"private\": false,
    \"default_branch\": \"main\"
  }" || warn "dépôt farci peut-être déjà existant"

ok "Gitea bootstrap terminé"
