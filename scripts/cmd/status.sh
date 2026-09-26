#!/usr/bin/env bash
# FARCI — tableau de progression du workshop (FARCI §49)
#
#   ./bin/farci status              sonde les services et affiche le tableau
#   ./bin/farci status --no-probe   n'interroge rien (utile hors ligne)
#   ./bin/farci status --strict     sort en code 1 si le pipeline n'est pas READY
#   ./bin/farci status --watch      rafraîchit en continu (écran de l'amphithéâtre)
#   ./bin/farci status --json       une ligne par service, pour les scripts
#
# Les lignes du tableau viennent de config/services.yaml (champ status_rows) :
# il n'existe pas de deuxième liste à maintenir. La ligne « CLINICAL PIPELINE »
# est calculée à partir des services marqués critical: true (FARCI §14).
#
# En l'état, un atelier qui démarre affiche volontairement tous les services en
# rouge : c'est le point de départ du §13 (🔴 🔴 🔴 🔴 🔴 🔴 🔴).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

PROBE=1
STRICT=0
WATCH=0
JSON=0
TIMEOUT="${FARCI_HEALTH_TIMEOUT:-3}"

usage() {
  sed -n '2,17p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --no-probe) PROBE=0 ;;
    --strict)   STRICT=1 ;;
    --watch)    WATCH=1 ;;
    --json)     JSON=1 ;;
    --timeout)  shift; TIMEOUT="${1:-3}" ;;
    -h|--help)  usage; exit 0 ;;
    *)          err "option inconnue : $1"; usage >&2; exit 64 ;;
  esac
  shift
done

SERVICES_PY="$FARCI_ROOT/scripts/services.py"

# Largeur intérieure du cadre. Les libellés sont volontairement en ASCII pour
# que l'alignement ne dépende pas de la locale du navigateur de l'amphithéâtre.
INNER=42
LABEL_W=27
VALUE_W=12
BAR="$(printf '═%.0s' $(seq 1 "$INNER"))"

declare -A STATES=()

# --- sonde un service ------------------------------------------------------
# Essaie chaque chemin candidat dans l'ordre : c'est l'application concrète de
# l'idée de « contrat ». Le même service peut s'appeler /v1/models (llama.cpp)
# ou /api/tags (Ollama) ; le client ne le sait pas et n'a pas à le savoir.
probe_service() {
  local service_id="$1" base path
  if [[ "$PROBE" == "0" ]]; then
    printf 'UNKNOWN'; return 0
  fi
  base="$(python3 "$SERVICES_PY" url "$service_id" 2>/dev/null || true)"
  if [[ -z "$base" ]]; then
    printf 'UNKNOWN'; return 0
  fi
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    [[ "$(http_code "$base$path" "$TIMEOUT")" == "200" ]] && { printf 'UP'; return 0; }
  done < <(python3 "$SERVICES_PY" health "$service_id" 2>/dev/null || true)
  printf 'DOWN'
}

# --- état d'un ensemble de services ----------------------------------------
# UP       : tous les services de la ligne répondent
# DEGRADED : au moins un répond, mais la ligne est incomplète
# DOWN     : aucun ne répond
# UNKNOWN  : sonde impossible (adresse non configurée, ou --no-probe)
row_state() {
  local id up=0 total=0 unknown=0
  for id in "$@"; do
    total=$(( total + 1 ))
    case "${STATES[$id]:-DOWN}" in
      UP)      up=$(( up + 1 )) ;;
      UNKNOWN) unknown=$(( unknown + 1 )) ;;
    esac
  done
  if (( total == 0 )) || (( unknown == total )); then
    printf 'UNKNOWN'
  elif (( up == total )); then
    printf 'UP'
  elif (( up > 0 )); then
    printf 'DEGRADED'
  else
    printf 'DOWN'
  fi
  printf ' %d/%d' "$up" "$total"
}

label_for() {
  case "$1" in
    UP*)      printf 'UP' ;;
    DEGRADED*) printf 'DEGRADED' ;;
    UNKNOWN*) printf 'UNKNOWN' ;;
    *)        printf 'DOWN' ;;
  esac
}

colour_for() {
  case "$1" in
    UP*)      printf '%s' "$C_GREEN" ;;
    DEGRADED*) printf '%s' "$C_YELLOW" ;;
    UNKNOWN*) printf '%s' "$C_DIM" ;;
    *)        printf '%s' "$C_RED" ;;
  esac
}

boxed() { printf '║ %-*s %*s ║\n' "$LABEL_W" "$1" "$VALUE_W" "$2"; }

snapshot() {
  # Les sondes sont parallèles : 15 services × 3 s en série donneraient une
  # attente de 45 s, ce qui est inacceptable pour un écran d'amphithéâtre.
  local results id
  results="$(mktemp -d)"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    ( probe_service "$id" > "$results/$id" 2>/dev/null ) &
  done < <(python3 "$SERVICES_PY" ids)
  wait
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    STATES["$id"]="$(cat "$results/$id" 2>/dev/null || printf 'UNKNOWN')"
  done < <(python3 "$SERVICES_PY" ids)
  rm -rf "$results"
}

print_json() {
  local id state
  printf '{\n'
  local first=1
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    state="${STATES[$id]:-UNKNOWN}"
    (( first )) || printf ',\n'
    first=0
    printf '  "%s": "%s"' "$id" "$state"
  done < <(python3 "$SERVICES_PY" ids)
  printf '\n}\n'
}

draw() {
  local -a critical_ids
  mapfile -t critical_ids < <(python3 "$SERVICES_PY" critical)

  local pipeline_state pipeline_label
  pipeline_state="$(row_state "${critical_ids[@]}")"
  case "$pipeline_state" in
    UP*)       pipeline_label="READY" ;;
    DEGRADED*) pipeline_label="DEGRADED" ;;
    *)         pipeline_label="NOT READY" ;;
  esac

  printf '\n'
  printf '╔%s╗\n' "$BAR"
  boxed "FARCI WORKSHOP" "$(date '+%H:%M')"
  printf '╠%s╣\n' "$BAR"

  local label raw state colour
  while IFS=$'\t' read -r label raw; do
    [[ -z "$label" ]] && continue
    local -a ids
    IFS=',' read -r -a ids <<< "$raw"
    state="$(row_state "${ids[@]}")"
    colour="$(colour_for "$state")"
    printf '%s' "$colour"
    boxed "$label" "$(label_for "$state")"
    printf '%s' "$C_RESET"
  done < <(python3 "$SERVICES_PY" status-rows)

  printf '╠%s╣\n' "$BAR"
  printf '%s' "$(colour_for "$pipeline_state")"
  boxed "CLINICAL PIPELINE" "$pipeline_label"
  printf '%s' "$C_RESET"
  printf '╚%s╝\n' "$BAR"

  if [[ "$pipeline_state" != UP* ]]; then
    printf '\n  Chaîne minimale incomplète. Enchaîner dans cet ordre :\n'
    printf '    caddy → gateway → 1 runtime → docling → observabilité\n'
  fi
  printf '\n'

  [[ "$pipeline_state" == UP* ]]
}

if (( WATCH )); then
  while true; do
    printf '\033[H\033[2J'
    snapshot
    draw || true
    sleep "${FARCI_STATUS_INTERVAL:-5}"
  done
fi

snapshot

if (( JSON )); then
  print_json
  exit 0
fi

if draw; then
  (( STRICT )) && exit 0
  exit 0
fi
(( STRICT )) && exit 1
exit 0
