#!/usr/bin/env bash
# FARCI — bootstrap Gitea : création org, utilisateur admin, dépôt
#
# Ce script est exécuté une fois après le démarrage de Gitea.
# Il crée l'organisation FARCI, l'utilisateur admin, et le dépôt farci.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# « Ensuite : » quand le script est lancé directement (scripts/suite.def).
[[ -n "${FARCI_SUITE_PARENT:-}" ]] || trap 'farci_suite 00-gitops/gitea/bootstrap.sh $?' EXIT
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GITEA_URL="${GITEA_URL:?GITEA_IP/GITEA_PORT manquants : voir config/network.env}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-farci-admin}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:?GITEA_ADMIN_PASSWORD requis}"
GITEA_ADMIN_EMAIL="${GITEA_ADMIN_EMAIL:-admin@farci.local}"

section "FARCI — bootstrap Gitea"

info "attente de Gitea..."
# /api/v1/* exige une connexion (REQUIRE_SIGNIN_VIEW) : on attend la sonde publique.
wait_http "$GITEA_URL/api/healthz" 60 "Gitea"

# Créer l'administrateur : l'API refuse cette création sans être déjà
# authentifié, on passe donc par la CLI de Gitea dans son conteneur.
info "création de l'administrateur..."
docker exec -u git farci-gitea gitea admin user create --admin \
  --username "$GITEA_ADMIN_USER" --password "$GITEA_ADMIN_PASSWORD" \
  --email "$GITEA_ADMIN_EMAIL" --must-change-password=false >/dev/null 2>&1 \
  || warn "administrateur peut-être déjà existant"

# Créer l'organisation FARCI
info "création de l'organisation FARCI..."
curl -sf -o /dev/null -X POST "$GITEA_URL/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" \
  -d "{
    \"username\": \"FARCI\",
    \"full_name\": \"FARCI Workshop\",
    \"description\": \"Forge du workshop FARCI\"
  }" || warn "organisation FARCI peut-être déjà existante"

# Créer le dépôt farci
info "création du dépôt farci..."
curl -sf -o /dev/null -X POST "$GITEA_URL/api/v1/orgs/FARCI/repos" \
  -H "Content-Type: application/json" \
  -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" \
  -d "{
    \"name\": \"farci\",
    \"description\": \"Dépôt principal du workshop FARCI\",
    \"private\": false,
    \"default_branch\": \"main\"
  }" || warn "dépôt farci peut-être déjà existant"

ok "Gitea bootstrap terminé"
