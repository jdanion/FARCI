#!/usr/bin/env bash
# FARCI — préchargement air-gap (FARCI §7, §52)
#
# Télécharge TOUTES les artefacts nécessaires au workshop : images Docker,
# poids de modèles, wheels Python, outils système. Une fois exécuté, le
# workshop fonctionne SANS accès Internet.
#
# Usage :
#   ./preload.sh                    CE poste : la brique de son équipe, selon
#                                   la machine (défaut, voir --poste)
#   ./preload.sh --equipe 2         idem, en précisant l'équipe
#   ./preload.sh --all              tout télécharger, poste formateur (~40 Go)
#   ./preload.sh --core             toutes les briques cœur (~26 Go)
#   ./preload.sh --models-ci        modèle CI uniquement (1.2 Go)
#   ./preload.sh --reference        pile de référence, À LANCER SUR LE PI (arm64)
#   ./preload.sh --pi               idem (profil « pi » : un seul modèle, Qwen3.5-2B Q4)
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
# « Ensuite : » quand le script est lancé directement (scripts/suite.def).
PRELOAD_ARGV=("$@")
[[ -n "${FARCI_SUITE_PARENT:-}" ]] || trap 'farci_suite preload $? "${PRELOAD_ARGV[@]}" --equipe "${PRELOAD_EQUIPE:-}"' EXIT
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/preload_lib.sh
source "$FARCI_ROOT/scripts/preload_lib.sh"
# shellcheck source=scripts/lib/machine.sh
source "$FARCI_ROOT/scripts/lib/machine.sh"

farci_load_env
farci_load_versions
# shellcheck source=scripts/lib/images.sh
source "$FARCI_ROOT/scripts/lib/images.sh"

# --------------------------------------------------------------------------
# Options
# --------------------------------------------------------------------------
PRELOAD_MODE="poste"
PRELOAD_EQUIPE="${FARCI_EQUIPE:-}"
PRELOAD_ONLY=""
PRELOAD_DRY_RUN=0
PRELOAD_SKIP_EXISTING=0
PRELOAD_PARALLEL=1
PRELOAD_VERIFY=0

usage() {
  cat <<'USAGE'
Usage : ./preload.sh [OPTIONS]

Options :
  --poste             [défaut] Ce poste : la brique de son équipe, seulement ce
                      que la machine pourra servir (Ollama + modèle 9B et
                      Langfuse : GPU NVIDIA ou 32 Go de RAM ; sinon llama.cpp
                      + modèle 2B, Phoenix seul). Équipe : --equipe ou
                      FARCI_EQUIPE (config/workshop.env)
  --equipe <0-8>      L'équipe de ce poste (implique --poste)
  --all               Tout télécharger, poste formateur (~40 Go)
  --core              Toutes les briques cœur (~26 Go)
  --models-ci         Modèle CI uniquement (Qwen3.5-2B, ~1.2 Go)
  --reference         Pile de référence (reference/) : à lancer SUR la machine
                      de référence (Pi 5, arm64), car une image se télécharge
                      pour l'architecture de la machine qui la tire
  --pi                Alias de --reference : profil « pi », un seul petit
                      modèle (Qwen3.5-2B Q4_K_M, ~1,3 Go)
  --only <groupe>     Exécuter un seul groupe (voir --list)
  --list              Lister les groupes disponibles
  --dry-run           Simuler sans rien télécharger
  --skip-existing     Ignorer les fichiers déjà présents
  --parallel <n>      Téléchargements en parallèle (défaut: 1)
  --verify            Vérifier après le préchargement
  -h, --help          Afficher cette aide

Exemples :
  ./preload.sh --equipe 2 --dry-run
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
      --poste)     PRELOAD_MODE="poste" ;;
      --equipe)    PRELOAD_MODE="poste"; PRELOAD_EQUIPE="${2:?--equipe requiert un numéro (0 à 8)}"; shift ;;
      --all)       PRELOAD_MODE="all" ;;
      --core)      PRELOAD_MODE="core" ;;
      --models-ci) PRELOAD_MODE="models-ci" ;;
      --reference|--pi) PRELOAD_MODE="reference" ;;
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
    poste)
      PRELOAD_PROFIL="$(farci_machine)"
      local -a team_groups=()
      if [[ -n "$PRELOAD_EQUIPE" ]]; then
        mapfile -t team_groups < <(poste_groups "$PRELOAD_EQUIPE" "$PRELOAD_PROFIL") \
          || { err "équipe inconnue : $PRELOAD_EQUIPE (0 à 8)"; exit 64; }
        (( ${#team_groups[@]} )) || { err "équipe inconnue : $PRELOAD_EQUIPE (0 à 8)"; exit 64; }
      fi
      SELECTED_GROUPS=("${team_groups[@]}" "wheels" "manifest")
      ;;
    all)
      SELECTED_GROUPS=("${PRELOAD_GROUPS[@]}")
      ;;
    core)
      SELECTED_GROUPS=("${PRELOAD_CORE_GROUPS[@]}")
      ;;
    models-ci)
      SELECTED_GROUPS=("models_ci")
      ;;
    reference)
      SELECTED_GROUPS=("reference" "build_eds_nlp" "models_ci" "gitops" "wheels" "partage" "manifest")
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
  if [[ "$PRELOAD_MODE" == "poste" && -z "$PRELOAD_ONLY" ]]; then
    printf 'Machine : %s — %s\n' "$( [[ "$PRELOAD_PROFIL" == grosse ]] && echo "grosse configuration" || echo "configuration légère")" \
      "$(farci_machine_why)"
    if [[ -z "$PRELOAD_EQUIPE" ]]; then
      warn "équipe inconnue : seules les dépendances Python seront téléchargées"
      printf '  → ./preload.sh --equipe <0-8>   (ou FARCI_EQUIPE dans config/workshop.env)\n'
    elif [[ "$PRELOAD_EQUIPE" == 2 && "$PRELOAD_PROFIL" != grosse ]]; then
      info "Ollama + modèle 9B réservés aux grosses configurations : llama.cpp + modèle 2B ici"
    elif [[ "$PRELOAD_EQUIPE" == 5 && "$PRELOAD_PROFIL" != grosse ]]; then
      info "Langfuse réservé aux grosses configurations : Phoenix seul ici"
    fi
  fi
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
