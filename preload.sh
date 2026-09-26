#!/usr/bin/env bash
# FARCI — préchargement air-gap (FARCI §7, §52)
#
# Télécharge TOUTES les artefacts nécessaires au workshop : images Docker,
# poids de modèles, wheels Python, outils système. Une fois exécuté, le
# workshop fonctionne SANS accès Internet.
#
# Usage :
#   ./preload.sh --all              tout télécharger (~57 Go)
#   ./preload.sh --core             strict nécessaire (~26 Go)
#   ./preload.sh --models-ci        modèle CI uniquement (1.2 Go)
#   ./preload.sh --only <groupe>     un seul groupe
#   ./preload.sh --dry-run          simuler sans rien télécharger
#   ./preload.sh --skip-existing    ignorer les fichiers déjà présents
#
# Après le préchargement :
#   ./verify-airgap.sh              vérifier que tout est en place
#   ./verify-airgap.sh --strict     vérifier avec coupure réseau (unshare)

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/preload_lib.sh
source "$FARCI_ROOT/scripts/preload_lib.sh"

farci_load_env

# --------------------------------------------------------------------------
# Options
# --------------------------------------------------------------------------
PRELOAD_MODE="core"
PRELOAD_ONLY=""
PRELOAD_DRY_RUN=0
PRELOAD_SKIP_EXISTING=0
PRELOAD_PARALLEL=1
PRELOAD_VERIFY=0

usage() {
  cat <<'USAGE'
Usage : ./preload.sh [OPTIONS]

Options :
  --all               Tout télécharger (~57 Go)
  --core              Strict nécessaire pour make health (~26 Go) [défaut]
  --models-ci         Modèle CI uniquement (Qwen3.5-2B, ~1.2 Go)
  --only <groupe>     Exécuter un seul groupe (voir --list)
  --list              Lister les groupes disponibles
  --dry-run           Simuler sans rien télécharger
  --skip-existing     Ignorer les fichiers déjà présents
  --parallel <n>      Téléchargements en parallèle (défaut: 1)
  --verify            Vérifier après le préchargement
  -h, --help          Afficher cette aide

Exemples :
  ./preload.sh --dry-run --core
  ./preload.sh --only models_ci
  ./preload.sh --all --parallel 4
USAGE
}

list_groups() {
  printf 'Groupes disponibles :\n'
  for g in "${PRELOAD_GROUPS[@]}"; do
    printf '  %s\n' "$g"
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)       PRELOAD_MODE="all" ;;
      --core)      PRELOAD_MODE="core" ;;
      --models-ci) PRELOAD_MODE="models-ci" ;;
      --only)      PRELOAD_ONLY="${2:?--only requiert un nom de groupe}"; shift ;;
      --list)      list_groups; exit 0 ;;
      --dry-run)   PRELOAD_DRY_RUN=1 ;;
      --skip-existing) PRELOAD_SKIP_EXISTING=1 ;;
      --parallel)  PRELOAD_PARALLEL="${2:?--parallel requiert un nombre}"; shift ;;
      --verify)    PRELOAD_VERIFY=1 ;;
      -h|--help)   usage; exit 0 ;;
      *)           err "option inconnue : $1"; usage; exit 64 ;;
    esac
    shift
  done
}

# --------------------------------------------------------------------------
# Sélection des groupes
# --------------------------------------------------------------------------
select_groups() {
  case "$PRELOAD_MODE" in
    all)
      SELECTED_GROUPS=("${PRELOAD_GROUPS[@]}")
      ;;
    core)
      SELECTED_GROUPS=("${PRELOAD_CORE_GROUPS[@]}")
      ;;
    models-ci)
      SELECTED_GROUPS=("models_ci")
      ;;
    *)
      err "mode inconnu : $PRELOAD_MODE"
      exit 64
      ;;
  esac

  if [[ -n "$PRELOAD_ONLY" ]]; then
    SELECTED_GROUPS=("$PRELOAD_ONLY")
  fi
}

# --------------------------------------------------------------------------
# Exécution
# --------------------------------------------------------------------------
main() {
  parse_args "$@"
  select_groups

  section "FARCI — préchargement air-gap"
  printf 'Mode : %s\n' "$PRELOAD_MODE"
  printf 'Groupes : %s\n' "${SELECTED_GROUPS[*]}"
  [[ "$PRELOAD_DRY_RUN" == "1" ]] && printf '%s[DRY-RUN]%s Aucun fichier ne sera téléchargé.\n' "$C_YELLOW" "$C_RESET"
  printf 'Data dir : %s\n' "$FARCI_DATA_DIR"
  printf '\n'

  if [[ "$PRELOAD_DRY_RUN" == "0" ]]; then
    need docker "preload.sh nécessite Docker"
    need curl
    need sha256sum
  fi

  local failed=0
  for group in "${SELECTED_GROUPS[@]}"; do
    printf '\n%s[%s]%s\n' "$C_BOLD" "$group" "$C_RESET"
    if ! run_group "$group"; then
      err "groupe échoué : $group"
      failed=$((failed + 1))
    fi
  done

  printf '\n'
  if (( failed > 0 )); then
    err "$failed groupe(s) en échec"
    exit 1
  fi

  ok "préchargement terminé"

  if [[ "$PRELOAD_VERIFY" == "1" ]]; then
    printf '\n'
    "$FARCI_ROOT/verify-airgap.sh"
  fi
}

main "$@"
