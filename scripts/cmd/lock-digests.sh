#!/usr/bin/env bash
# FARCI — verrouille les empreintes SHA256 des images Docker (FARCI §6)
#
# Interroge le registre Docker pour obtenir le digest SHA256 de chaque
# image et génère versions.lock.env. Ce fichier permet de vérifier que
# les images n'ont pas été modifiées entre le préchargement et le workshop.
#
# Usage :
#   scripts/lock-digests.sh              verrouiller toutes les images
#   scripts/lock-digests.sh --check      vérifier les digests existants

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

LOCK_MODE="lock"

usage() {
  cat <<'USAGE'
Usage : scripts/lock-digests.sh [--check]

Options :
  --check    Vérifier les digests existants sans les recalculer
  -h, --help Afficher cette aide
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) LOCK_MODE="check" ;;
      -h|--help) usage; exit 0 ;;
      *)       err "option inconnue : $1"; usage; exit 64 ;;
    esac
    shift
  done
}

# Liste des images à verrouiller (doit correspondre à versions.env)
farci_load_versions
# shellcheck source=scripts/lib/images.sh
source "$FARCI_ROOT/scripts/lib/images.sh"
mapfile -t LOCK_IMAGES < <(farci_images all)

get_digest() {
  local image="$1"
  docker image inspect "$image" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 || echo ""
}

main() {
  parse_args "$@"

  section "FARCI — verrouillage des digests"

  if [[ "$LOCK_MODE" == "check" ]]; then
    local lock_file="$FARCI_ROOT/versions.lock.env"
    if [[ ! -f "$lock_file" ]]; then
      warn "versions.lock.env absent — exécutez scripts/lock-digests.sh"
      return 0
    fi
    info "vérification des digests..."
    local mismatch=0
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      local image="${key%_DIGEST}"
      local current
      current="$(get_digest "$image")"
      if [[ "$current" != "$value" ]]; then
        warn "digest mismatch : $image"
        warn "  attendu : $value"
        warn "  actuel  : $current"
        mismatch=$((mismatch + 1))
      fi
    done < "$lock_file"
    (( mismatch == 0 )) && ok "tous les digests sont conformes" || err "$mismatch mismatch"
    return $mismatch
  fi

  local lock_file="$FARCI_ROOT/versions.lock.env"
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  info "interrogation du registre Docker..."
  for image in "${LOCK_IMAGES[@]}"; do
    local key="${image%%:*}"
    local tag="${image##*:}"
    local varname="${key^^}_DIGEST"
    varname="${varname//\//_}"
    varname="${varname//./_}"

    local digest
    digest="$(get_digest "$image")"
    if [[ -z "$digest" ]]; then
      warn "digest introuvable pour $image — l'image n'est peut-être pas tirée"
      continue
    fi
    printf '%s=%s\n' "$varname" "$digest" >> "$tmp"
    ok "$image → $digest"
  done

  mv "$tmp" "$lock_file"
  trap - EXIT
  ok "versions.lock.env généré"
}

main "$@"
