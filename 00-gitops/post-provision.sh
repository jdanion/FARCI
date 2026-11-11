#!/usr/bin/env bash
# FARCI — post-provisionnement Gitea : protection des branches communes
#
# À lancer après ./bin/farci forge-sync push (les branches doivent exister) :
# 1. main   : copie de GitHub, seul l'administrateur y pousse (forge-sync)
# 2. seance : on n'y entre que par une Pull Request relue (1 approbation)
# Les branches poste/* des étudiants ne sont pas protégées : chacun la sienne.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# « Ensuite : » quand le script est lancé directement (scripts/suite.def).
[[ -n "${FARCI_SUITE_PARENT:-}" ]] || trap 'farci_suite 00-gitops/post-provision.sh $?' EXIT
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

GITEA_URL="${GITEA_URL:?GITEA_IP/GITEA_PORT manquants : voir config/network.env}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-farci-admin}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:?GITEA_ADMIN_PASSWORD requis}"

section "FARCI — post-provisionnement Gitea"

# protect <branche> <JSON de la règle> : crée la règle, ou la met à jour.
protect() {
  local branch="$1" rule="$2" api="$GITEA_URL/api/v1/repos/FARCI/farci/branch_protections"
  curl -sf -o /dev/null -X POST "$api" -H "Content-Type: application/json" \
    -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" -d "{\"rule_name\": \"$branch\", $rule}" \
  || curl -sf -o /dev/null -X PATCH "$api/$branch" -H "Content-Type: application/json" \
    -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASSWORD" -d "{$rule}" \
  || { warn "protection de $branch : échec (branche absente ? ./bin/farci forge-sync push d'abord)"; return 0; }
  ok "branche $branch protégée"
}

# main : la copie de GitHub. Seul l'administrateur y pousse (forge-sync, en
# avance rapide) ; personne d'autre, pas même par Pull Request.
info "protection de la branche main..."
protect main "\"enable_push\": true, \"enable_push_whitelist\": true,
  \"push_whitelist_usernames\": [\"$GITEA_ADMIN_USER\"],
  \"enable_merge_whitelist\": true, \"merge_whitelist_usernames\": [\"$GITEA_ADMIN_USER\"]"

# seance : la branche commune de la salle. On n'y entre que par une Pull
# Request relue par quelqu'un d'autre ; les branches poste/* restent libres.
info "protection de la branche ${FARCI_SESSION_BRANCH:-seance}..."
protect "${FARCI_SESSION_BRANCH:-seance}" "\"enable_push\": false, \"required_approvals\": 1,
  \"dismiss_stale_approvals\": true, \"block_on_rejected_reviews\": true"

ok "post-provisionnement terminé"
