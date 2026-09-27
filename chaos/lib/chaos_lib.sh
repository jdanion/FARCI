#!/usr/bin/env bash
# FARCI — bibliothèque chaos (chaos/lib/chaos_lib.sh)
# Sourced par chaos.sh et les scénarios.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "chaos_lib.sh est une bibliothèque : utilisez 'source chaos/lib/chaos_lib.sh'" >&2
  exit 64
fi

CHAOS_STATE_DIR="${FARCI_ROOT}/.chaos"
CHAOS_STATE_FILE="${CHAOS_STATE_DIR}/state.json"

chaos_init() {
  mkdir -p "$CHAOS_STATE_DIR"
  if [[ ! -f "$CHAOS_STATE_FILE" ]]; then
    echo '{}' > "$CHAOS_STATE_FILE"
  fi
}

chaos_list() {
  printf 'Scénarios disponibles :\n'
  for f in "$FARCI_ROOT"/chaos/scenarios/scenario-*.sh; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f" .sh)"
    printf '  %s\n' "$name"
  done
}

chaos_status() {
  chaos_init
  if [[ ! -s "$CHAOS_STATE_FILE" ]]; then
    printf 'Aucun chaos actif.\n'
    return 0
  fi
  cat "$CHAOS_STATE_FILE"
}

chaos_reset() {
  chaos_init
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "chaos reset"
}

chaos_apply() {
  local scenario="$1"
  shift
  local script="$FARCI_ROOT/chaos/scenarios/scenario-${scenario}.sh"

  if [[ ! -f "$script" ]]; then
    err "scénario inconnu : scenario-${scenario}"
    return 1
  fi

  chaos_init
  # shellcheck source=/dev/null
  source "$script"
  chaos_scenario_apply "$@"
}

chaos_revert() {
  local scenario="$1"
  local script="$FARCI_ROOT/chaos/scenarios/scenario-${scenario}.sh"

  if [[ ! -f "$script" ]]; then
    err "scénario inconnu : scenario-${scenario}"
    return 1
  fi

  chaos_init
  # shellcheck source=/dev/null
  source "$script"
  chaos_scenario_revert
}
