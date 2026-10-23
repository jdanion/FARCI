#!/usr/bin/env bash
# FARCI — bibliothèque chaos (chaos/lib/chaos_lib.sh)
# Sourcée par chaos.sh. C'est elle, et elle seule, qui tient l'état.
#
# Contrat d'un scénario (chaos/scenarios/scenario-NN-<nom>.sh) :
#   SCENARIO_TITLE="..."            une ligne, affichée par `list`
#   chaos_scenario_apply            casse (idempotent)
#   chaos_scenario_revert           répare (idempotent)
#
# État : .chaos/state.json = liste des scénarios actifs. Il survit à un
# redémarrage de la machine, ce qui permet à `reset` de tout réparer.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "chaos_lib.sh est une bibliothèque : utilisez 'source chaos/lib/chaos_lib.sh'" >&2
  exit 64
fi

CHAOS_DIR="${FARCI_ROOT}/chaos/scenarios"
CHAOS_STATE_DIR="${FARCI_ROOT}/.chaos"
CHAOS_STATE_FILE="${CHAOS_STATE_DIR}/state.json"

chaos_init() {
  mkdir -p "$CHAOS_STATE_DIR"
  [[ -s "$CHAOS_STATE_FILE" ]] || echo '{"active": []}' > "$CHAOS_STATE_FILE"
}

# Lit ou modifie la liste des scénarios actifs.
#   chaos_state list | add NN | remove NN
chaos_state() {
  chaos_init
  python3 - "$CHAOS_STATE_FILE" "$@" <<'PY'
import json, sys
path, action = sys.argv[1], sys.argv[2]
try:
    state = json.load(open(path, encoding="utf-8"))
    active = [str(x) for x in state.get("active", [])]
except (OSError, ValueError, AttributeError):
    active = []
if action == "add" and sys.argv[3] not in active:
    active.append(sys.argv[3])
elif action == "remove":
    active = [x for x in active if x != sys.argv[3]]
if action != "list":
    json.dump({"active": sorted(active)}, open(path, "w", encoding="utf-8"))
print("\n".join(sorted(active)))
PY
}

# scenario-01 | 01 | 1  ->  chemin du script
chaos_script() {
  local id="${1#scenario-}" match
  [[ "$id" =~ ^[0-9]+$ ]] || return 1
  id="$(printf '%02d' "$((10#$id))")"
  match="$(compgen -G "$CHAOS_DIR/scenario-${id}-*.sh" | head -1 || true)"
  [[ -n "$match" ]] && printf '%s\n' "$match"
}

chaos_id() { basename "$1" | sed -E 's/^scenario-([0-9]+)-.*/\1/'; }

chaos_title() {
  ( SCENARIO_TITLE=""; source "$1"; printf '%s' "$SCENARIO_TITLE" )
}

# Exécute apply/revert d'un scénario dans un sous-shell en mode « set -e » :
# la première commande en échec arrête le scénario. Le code de retour est
# rendu dans CHAOS_RC et la fonction renvoie toujours 0 : appelée à gauche
# d'un || ou dans un if, bash désactiverait set -e jusque dans le sous-shell.
chaos_run() {
  local script="$1" action="$2"
  set +e
  ( set -e; source "$script"; "$action" )
  CHAOS_RC=$?
  set -e
  return 0
}

chaos_list() {
  local f
  printf 'Scénarios disponibles :\n'
  for f in "$CHAOS_DIR"/scenario-*.sh; do
    [[ -f "$f" ]] || continue
    printf '  scenario-%s  %s\n' "$(chaos_id "$f")" "$(chaos_title "$f")"
  done
}

chaos_status() {
  local active id
  active="$(chaos_state list)"
  if [[ -z "$active" ]]; then
    ok "aucune panne active"
    return 0
  fi
  warn "pannes actives :"
  while IFS= read -r id; do
    printf '  scenario-%s  %s\n' "$id" "$(chaos_title "$(chaos_script "$id")")"
  done <<< "$active"
}

chaos_apply() {
  local script id duration=""
  script="$(chaos_script "$1")" || { err "scénario inconnu : $1 (./bin/farci chaos list)"; return 64; }
  [[ -n "$script" ]] || { err "scénario inconnu : $1 (./bin/farci chaos list)"; return 64; }
  shift
  while (( $# > 0 )); do
    case "$1" in
      --duration) duration="${2:-}"; shift 2 ;;
      *) err "option inconnue : $1"; return 64 ;;
    esac
  done
  [[ -z "$duration" || "$duration" =~ ^[0-9]+$ ]] || { err "--duration attend des secondes"; return 64; }

  id="$(chaos_id "$script")"
  section "scenario-$id — $(chaos_title "$script")"
  chaos_state add "$id" >/dev/null
  chaos_run "$script" chaos_scenario_apply
  (( CHAOS_RC == 0 )) || warn "l'application du scénario a échoué (code $CHAOS_RC)"

  if [[ -n "$duration" ]]; then
    info "réparation automatique dans ${duration}s (Ctrl+C : la panne reste, ./bin/farci chaos reset)"
    sleep "$duration"
    chaos_revert "$id"
  else
    info "pour réparer : ./bin/farci chaos reset"
  fi
}

chaos_revert() {
  local script id
  script="$(chaos_script "$1")" || return 64
  [[ -n "$script" ]] || return 64
  id="$(chaos_id "$script")"
  chaos_run "$script" chaos_scenario_revert
  if (( CHAOS_RC != 0 )); then
    err "scenario-$id : la réparation a échoué (code $CHAOS_RC) — la panne reste listée"
    return 0
  fi
  chaos_state remove "$id" >/dev/null
  ok "scenario-$id réparé"
}

chaos_reset() {
  local active id
  active="$(chaos_state list)"
  if [[ -z "$active" ]]; then
    ok "rien à réparer"
    return 0
  fi
  while IFS= read -r id; do
    chaos_revert "$id"
  done <<< "$active"
  # Ce qui n'a pas pu être réparé reste dans l'état : on le dit, code 1.
  if [[ -n "$(chaos_state list)" ]]; then
    chaos_status
    return 1
  fi
}
