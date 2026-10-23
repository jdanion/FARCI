#!/usr/bin/env bash
# FARCI — tableau de progression du workshop (FARCI §49)
#
#   ./bin/farci status              sonde les services et affiche le tableau
#   ./bin/farci status --no-probe   n'interroge rien (utile hors ligne)
#   ./bin/farci status --strict     sort en code 1 si le pipeline n'est pas READY
#   ./bin/farci status --watch      rafraîchit en continu (écran de l'amphithéâtre)
#   ./bin/farci status --all        détaille aussi les briques bonus
#   ./bin/farci status --json       état de chaque service et du pipeline
#
# Les lignes du tableau viennent de config/services.yaml (champ status_rows) :
# il n'existe pas de deuxième liste à maintenir. Les lignes « core » sont
# affichées, les « bonus » résumées en une ligne. « CLINICAL PIPELINE » suit la
# règle unique de scripts/services.py (pipeline_state), la même que le
# health-aggregator : services critiques + au moins un runtime (FARCI §14).
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
ALL=0
TIMEOUT="${FARCI_HEALTH_TIMEOUT:-3}"

usage() {
  sed -n '2,19p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --no-probe) PROBE=0 ;;
    --strict)   STRICT=1 ;;
    --watch)    WATCH=1 ;;
    --json)     JSON=1 ;;
    --all)      ALL=1 ;;
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

states_json() {
  local id first=1
  printf '{'
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    (( first )) || printf ','
    first=0
    printf '"%s":"%s"' "$id" "${STATES[$id]:-UNKNOWN}"
  done < <(python3 "$SERVICES_PY" ids)
  printf '}'
}

# Lit l'état du pipeline calculé par services.py : PIPELINE_STATE, PIPELINE_MISSING.
compute_pipeline() {
  local result
  result="$(states_json | python3 "$SERVICES_PY" pipeline)"
  PIPELINE_STATE="$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
  PIPELINE_MISSING="$(printf '%s' "$result" | python3 -c 'import json,sys; print(" → ".join(json.load(sys.stdin)["missing"]))')"
}

print_json() {
  local result
  result="$(states_json | python3 "$SERVICES_PY" pipeline)"
  printf '{"services": %s, "pipeline": %s}\n' "$(states_json)" "$result"
}

draw() {
  compute_pipeline
  local pipeline_colour
  case "$PIPELINE_STATE" in
    READY)    pipeline_colour="$C_GREEN" ;;
    DEGRADED) pipeline_colour="$C_YELLOW" ;;
    *)        pipeline_colour="$C_RED" ;;
  esac

  printf '\n'
  printf '╔%s╗\n' "$BAR"
  boxed "FARCI WORKSHOP" "$(date '+%H:%M')"
  printf '╠%s╣\n' "$BAR"

  local label tier raw state colour bonus_up=0 bonus_total=0 bonus_names=""
  while IFS=$'\t' read -r label tier raw; do
    [[ -z "$label" ]] && continue
    local -a ids
    IFS=',' read -r -a ids <<< "$raw"
    state="$(row_state "${ids[@]}")"
    if [[ "$tier" == "bonus" && "$ALL" == "0" ]]; then
      bonus_total=$(( bonus_total + 1 ))
      if [[ "$state" == UP* ]]; then
        bonus_up=$(( bonus_up + 1 ))
        bonus_names+="${bonus_names:+, }$label"
      fi
      continue
    fi
    colour="$(colour_for "$state")"
    printf '%s' "$colour"
    [[ "$tier" == "bonus" ]] && label="$label (bonus)"
    boxed "$label" "$(label_for "$state")"
    printf '%s' "$C_RESET"
  done < <(python3 "$SERVICES_PY" status-rows)

  if (( bonus_total > 0 )); then
    printf '%s' "$C_DIM"
    boxed "Bonus" "$bonus_up/$bonus_total UP"
    printf '%s' "$C_RESET"
  fi

  printf '╠%s╣\n' "$BAR"
  printf '%s' "$pipeline_colour"
  boxed "CLINICAL PIPELINE" "$PIPELINE_STATE"
  printf '%s' "$C_RESET"
  printf '╚%s╝\n' "$BAR"

  if [[ -n "$bonus_names" ]]; then
    printf '  Bonus en service : %s\n' "$bonus_names"
  fi
  if [[ "$PIPELINE_STATE" != "READY" ]]; then
    printf "\n  Il manque, dans l'ordre de montage :\n    %s\n" "$PIPELINE_MISSING"
  fi
  printf '\n'

  [[ "$PIPELINE_STATE" == "READY" ]]
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
