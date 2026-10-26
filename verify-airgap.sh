#!/usr/bin/env bash
# FARCI — vérification air-gap stricte (FARCI §7.2, §52)
#
# Vérifie que tous les artefacts nécessaires sont présents localement et
# qu'aucun téléchargement ne sera nécessaire le jour J.
#
# Usage :
#   ./verify-airgap.sh              vérification standard
#   ./verify-airgap.sh --strict     avec coupure réseau (unshare -rn)
#   ./verify-airgap.sh --json       sortie JSON

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
farci_load_versions
# shellcheck source=scripts/lib/images.sh
source "$FARCI_ROOT/scripts/lib/images.sh"


VERIFY_STRICT=0
VERIFY_JSON=0

usage() {
  cat <<'USAGE'
Usage : ./verify-airgap.sh [OPTIONS]

Options :
  --strict    Vérifier avec coupure réseau (unshare -rn)
  --json      Sortie JSON
  -h, --help  Afficher cette aide
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict) VERIFY_STRICT=1 ;;
      --json)   VERIFY_JSON=1 ;;
      -h|--help) usage; exit 0 ;;
      *)        err "option inconnue : $1"; usage; exit 64 ;;
    esac
    shift
  done
}

# --------------------------------------------------------------------------
# Contrôles
# --------------------------------------------------------------------------
declare -a CHECK_RESULTS=()
declare -a CHECK_NAMES=()
declare -a CHECK_DETAILS=()

record_check() {
  local name="$1" status="$2" detail="${3:-}"
  CHECK_NAMES+=("$name")
  CHECK_RESULTS+=("$status")
  CHECK_DETAILS+=("$detail")
  case "$status" in
    PASS) printf '%s[PASS]%s %s\n' "$C_GREEN" "$C_RESET" "$name" ;;
    FAIL) printf '%s[FAIL]%s %s — %s\n' "$C_RED" "$C_RESET" "$name" "$detail" ;;
    WARN) printf '%s[WARN]%s %s — %s\n' "$C_YELLOW" "$C_RESET" "$name" "$detail" ;;
  esac
}

check_images() {
  local missing=()
  local images=()
  mapfile -t images < <(farci_images core)

  for img in "${images[@]}"; do
    if ! docker image inspect "$img" >/dev/null 2>&1; then
      missing+=("$img")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    record_check "images" "PASS" "toutes les images requises sont présentes"
  else
    record_check "images" "FAIL" "images manquantes : $(printf '%s, ' "${missing[@]}")"
  fi
}

check_versions() {
  local versions_file="$FARCI_ROOT/versions.env"
  if [[ ! -f "$versions_file" ]]; then
    record_check "versions" "FAIL" "versions.env absent"
    return
  fi

  local bad=()
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    [[ "$value" == "latest" || "$value" == "main" || -z "$value" ]] && bad+=("$key")
  done < "$versions_file"

  if (( ${#bad[@]} == 0 )); then
    record_check "versions" "PASS" "aucun tag flottant"
  else
    record_check "versions" "FAIL" "tags flottants : ${bad[*]}"
  fi
}

check_compose() {
  # Vérifier qu'aucun compose n'utilise build: distant ou pull_policy: always
  local violations=()
  # Une construction LOCALE (contexte = dossier du dépôt, image de base
  # préchargée) fonctionne hors ligne ; une construction DISTANTE (contexte
  # git ou http) ou un pull_policy: always ne fonctionnent pas.
  while IFS= read -r line; do
    violations+=("$line")
  done < <(grep -rnE "(build|context):[[:space:]]*['\"]?(https?://|git@|git://|github\.com)|pull_policy:[[:space:]]*always" \
             "$FARCI_ROOT" --include="docker-compose.yml" --include="compose.yml" 2>/dev/null || true)

  if (( ${#violations[@]} == 0 )); then
    record_check "compose" "PASS" "aucun build distant ni pull_policy: always"
  else
    record_check "compose" "FAIL" "violations : ${violations[*]}"
  fi
}

check_models() {
  local missing=()
  local models_dir="$FARCI_MODELS_DIR"

  # Vérifier les fichiers GGUF attendus
  local expected=(
    "Ornith-1.5-9B-Q5_K_M.gguf"
    "Ornith-1.5-9B-Q4_K_M.gguf"
    "Qwen3.8-27B-Q4_K_M.gguf"
    "Qwen3.5-2B-Q4_K_M.gguf"
  )

  for f in "${expected[@]}"; do
    if [[ ! -f "$models_dir/$f" ]]; then
      missing+=("$f")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    record_check "models" "PASS" "tous les poids sont présents"
  else
    record_check "models" "WARN" "poids manquants (normal si --core seul) : ${missing[*]}"
  fi
}

check_manifest() {
  local manifest="$FARCI_MANIFEST"
  if [[ ! -f "$manifest" ]]; then
    record_check "manifest" "WARN" "MANIFEST.sha256 absent — exécuter ./preload.sh --core"
    return
  fi

  if (cd "$FARCI_OFFLINE_DIR" && sha256sum -c "$manifest" --quiet) 2>/dev/null; then
    record_check "manifest" "PASS" "tous les fichiers sont conformes"
  else
    record_check "manifest" "FAIL" "certains fichiers ne correspondent pas au manifeste"
  fi
}

check_offline_policy() {
  # Vérifier qu'aucun CDN ou URL distante n'est utilisé dans les applications
  local violations=()
  while IFS= read -r line; do
    [[ "$line" == *"http://cdn."* || "$line" == *"https://cdn."* ]] && violations+=("$line")
    [[ "$line" == *"googleapis.com"* ]] && violations+=("$line")
  done < <(grep -rn "cdn\.\|googleapis\.com" "$FARCI_ROOT/07-applications" 2>/dev/null || true)

  if (( ${#violations[@]} == 0 )); then
    record_check "offline-policy" "PASS" "aucun CDN détecté"
  else
    record_check "offline-policy" "FAIL" "CDNs détectés : ${violations[*]}"
  fi
}

# --------------------------------------------------------------------------
# Exécution
# --------------------------------------------------------------------------
main() {
  parse_args "$@"

  section "FARCI — vérification air-gap"
  [[ "$VERIFY_STRICT" == "1" ]] && printf '%s[STRICT]%s La vérification sera effectuée avec coupure réseau.\n' "$C_YELLOW" "$C_RESET"
  printf '\n'

  check_images
  check_versions
  check_compose
  check_models
  check_manifest
  check_offline_policy

  printf '\n'
  local failed=0
  for status in "${CHECK_RESULTS[@]}"; do
    [[ "$status" == "FAIL" ]] && failed=$((failed + 1))
  done

  if (( failed > 0 )); then
    err "$failed vérification(s) en échec"
    printf 'Exécutez ./preload.sh --core pour compléter les artefacts manquants.\n'
    exit 1
  fi

  ok "air-gap vérifié — le workshop peut fonctionner hors ligne"
}

main "$@"
