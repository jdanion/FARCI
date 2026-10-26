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
# implémentation : scripts/dev-env.sh), calcule les amonts de l'accueil,
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

need_docker

# Amonts de l'accueil (UP_*) : « brique de l'équipe, puis référence »,
# calculés depuis config/network.env et config/rescue.env. Seules les
# composes qui embarquent un Caddy les lisent ; les exporter ne coûte rien.
while IFS= read -r line; do
  [[ "$line" == UP_*=* ]] && export "${line?}"
done < <(python3 "$FARCI_ROOT/scripts/services.py" upstreams)

# Un échec de `compose up` a plusieurs causes fréquentes : dire laquelle.
explain_failure() {
  local log="$1" names
  local missing=0 ids id ghosts=""
  names="$(grep -oE 'container name "/[^"]+" is already in use' "$log" | sed -E 's|.*"/([^"]+)".*|\1|' | sort -u | tr '\n' ' ')"
  ids="$(grep -oE 'in use by container "[0-9a-f]+"' "$log" | grep -oE '[0-9a-f]{12,}' | cut -c1-12 | sort -u)"
  grep -qiE 'no such image|pull access denied|image .* not found|not found: manifest' "$log" && missing=1
  rm -f "$log"
  # Un nom peut rester réservé par un conteneur « fantôme » (création
  # interrompue) que `docker ps -a` ne montre pas : seul un redémarrage du
  # service Docker le libère.
  for id in $ids; do
    docker inspect "$id" >/dev/null 2>&1 || ghosts+="$id "
  done
  if [[ -n "$ghosts" ]]; then
    die "nom réservé par un conteneur fantôme (${ghosts% }) invisible dans docker ps -a : sudo systemctl restart docker, puis docker ps -a --filter name=farci- -q | xargs -r docker rm -f, puis relancer"
  elif [[ -n "$names" ]]; then
    die "un ancien conteneur porte déjà ce nom (lancé autrement, par exemple avec sudo ou un autre nom de projet) : docker rm -f ${names% } — puis relancer"
  elif (( missing )); then
    die "image absente : ./bin/farci verify-images, puis ./preload.sh (avec Internet) ou docker load"
  fi
  die "démarrage impossible : voir le message de Docker ci-dessus"
}

case "${FARCI_TARGET:-up}" in
  up)
    # Air-gap : une image absente est une erreur franche, jamais un
    # téléchargement silencieux (docs/AIRGAP.md). Préparation avec Internet :
    # FARCI_ALLOW_PULL=1 ./bin/farci up <dossier>
    pull=never
    [[ "${FARCI_ALLOW_PULL:-0}" == "1" ]] && pull=missing
    log="$(mktemp)"
    if ! docker compose -f "$compose_file" up -d --pull "$pull" "$@" 2>&1 | tee "$log"; then
      explain_failure "$log"
    fi
    rm -f "$log"
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
