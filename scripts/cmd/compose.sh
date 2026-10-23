#!/usr/bin/env bash
# FARCI — démarrer, arrêter, lire les journaux d'une brique
#
#   ./bin/farci up   02-inference/ollama     docker compose up -d
#   ./bin/farci down 02-inference/ollama     docker compose down
#   ./bin/farci logs 02-inference/ollama     docker compose logs -f --tail 100
#
# Pourquoi ne pas taper `docker compose up` dans le dossier ? Parce que les
# compose ne contiennent ni adresse ni version : elles viennent de
# config/network.env, versions.env et .env. Ce script les charge (une seule
# implémentation : scripts/dev-env.sh), crée le réseau `farci` s'il manque,
# puis appelle docker compose. Il n'y a pas d'autre magie.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,12p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "")        usage >&2; exit 64 ;;
esac

farci_load_env
farci_load_versions

dir="${1%/}"; shift
[[ "$dir" = /* ]] || dir="$FARCI_ROOT/$dir"
compose_file=""
for candidate in docker-compose.yml docker-compose.yaml compose.yaml; do
  [[ -f "$dir/$candidate" ]] && { compose_file="$dir/$candidate"; break; }
done
[[ -n "$compose_file" ]] || die "aucun docker-compose.yml dans $dir"

need docker "Docker est requis pour démarrer une brique"
docker info >/dev/null 2>&1 || die "Docker ne répond pas : est-il démarré ? (./bin/farci doctor)"

ensure_network() {
  local name="$FARCI_DOCKER_NETWORK"
  docker network inspect "$name" >/dev/null 2>&1 && return 0
  [[ -n "${FARCI_SUBNET:-}" ]] || die "FARCI_SUBNET manquant (config/network.env)"
  info "création du réseau Docker $name ($FARCI_SUBNET)"
  docker network create --subnet "$FARCI_SUBNET" "$name" >/dev/null
}

case "${FARCI_TARGET:-up}" in
  up)
    ensure_network
    # Air-gap : une image absente est une erreur franche, jamais un
    # téléchargement silencieux (docs/AIRGAP.md). Préparation avec Internet :
    # FARCI_ALLOW_PULL=1 ./bin/farci up <dossier>
    pull=never
    [[ "${FARCI_ALLOW_PULL:-0}" == "1" ]] && pull=missing
    docker compose -f "$compose_file" up -d --pull "$pull" "$@" \
      || die "démarrage impossible — image absente ? ./bin/farci verify-images"
    ok "brique démarrée : ${dir#"$FARCI_ROOT"/} — suivre : ./bin/farci status"
    ;;
  down)
    docker compose -f "$compose_file" down "$@"
    ;;
  logs)
    docker compose -f "$compose_file" logs -f --tail 100 "$@"
    ;;
  *)
    die "cible inattendue pour compose.sh : ${FARCI_TARGET}"
    ;;
esac
