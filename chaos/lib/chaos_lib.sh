#!/usr/bin/env bash
# FARCI — bibliothèque chaos (chaos/lib/chaos_lib.sh)
# Sourcée par chaos.sh. C'est elle, et elle seule, qui tient l'état.
#
# Contrat d'un scénario (chaos/scenarios/scenario-NN-<nom>.sh) :
#   SCENARIO_TITLE="..."            une ligne, affichée par `list`
#   SCENARIO_ATTENDU="..."          le résultat attendu, annoncé AVANT la panne
#   chaos_scenario_apply            casse (idempotent)
#   chaos_scenario_check            vérifie l'attendu (code 0 = conforme)
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
  # shellcheck source=/dev/null
  ( SCENARIO_TITLE=""; source "$1"; printf '%s' "$SCENARIO_TITLE" )
}

# Exécute apply/revert d'un scénario dans un sous-shell en mode « set -e » :
# la première commande en échec arrête le scénario. Le code de retour est
# rendu dans CHAOS_RC et la fonction renvoie toujours 0 : appelée à gauche
# d'un || ou dans un if, bash désactiverait set -e jusque dans le sous-shell.
chaos_run() {
  local script="$1" action="$2"
  set +e
  # shellcheck source=/dev/null
  ( set -e; source "$script"; eval "$action" )
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
  # shellcheck source=/dev/null
  info "attendu : $( ( SCENARIO_ATTENDU=""; source "$script"; printf '%s' "$SCENARIO_ATTENDU" ) )"
  chaos_state add "$id" >/dev/null
  # shellcheck disable=SC2034  # lu par chaos/chaos.sh
  CHAOS_CHECK_RC=0
  chaos_run "$script" "chaos_scenario_apply; if declare -F chaos_scenario_check >/dev/null; then chaos_scenario_check; fi"
  if (( CHAOS_RC != 0 )); then
    warn "le scénario ne s'est pas déroulé comme attendu (code $CHAOS_RC) : c'est aussi une découverte"
    # shellcheck disable=SC2034  # lu par chaos/chaos.sh
    CHAOS_CHECK_RC=$CHAOS_RC
  fi

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

# ---------------------------------------------------------------------------
# Pannes simulées À L'ACCUEIL (sur la machine du formateur)
# ---------------------------------------------------------------------------
# Les briques des équipes tournent sur leurs portables : depuis le Pi, on ne
# les arrête pas, on coupe leur route à l'accueil. Deux gestes :
#   exclude <route>  l'accueil ignore la brique de l'ÉQUIPE (la suivante sert)
#   block   <route>  l'accueil ne sert PLUS PERSONNE sur cette route
# L'état est dans .chaos/routes.env, lu par scripts/services.py (upstreams).
CHAOS_ROUTES_FILE="${CHAOS_STATE_DIR}/routes.env"

chaos_route() {
  local action="$1" route="$2" key list
  case "$action" in
    exclude) key=FARCI_CHAOS_EXCLUDE ;;
    block)   key=FARCI_CHAOS_BLOCK ;;
    *) err "chaos_route : exclude | block"; return 64 ;;
  esac
  chaos_init
  touch "$CHAOS_ROUTES_FILE"
  list="$(sed -n "s/^${key}=//p" "$CHAOS_ROUTES_FILE")"
  grep -qx "$route" <<< "${list//,/$'\n'}" || list="${list:+$list,}$route"
  grep -v "^${key}=" "$CHAOS_ROUTES_FILE" > "$CHAOS_ROUTES_FILE.tmp" || true
  printf '%s=%s\n' "$key" "$list" >> "$CHAOS_ROUTES_FILE.tmp"
  mv "$CHAOS_ROUTES_FILE.tmp" "$CHAOS_ROUTES_FILE"
  chaos_reload
}

# Retire une route des deux listes (réparation).
chaos_route_clear() {
  local route="$1" key list
  [[ -f "$CHAOS_ROUTES_FILE" ]] || return 0
  for key in FARCI_CHAOS_EXCLUDE FARCI_CHAOS_BLOCK; do
    list="$(sed -n "s/^${key}=//p" "$CHAOS_ROUTES_FILE" | tr ',' '\n' | grep -vx "$route" | paste -sd, - || true)"
    grep -v "^${key}=" "$CHAOS_ROUTES_FILE" > "$CHAOS_ROUTES_FILE.tmp" || true
    [[ -n "$list" ]] && printf '%s=%s\n' "$key" "$list" >> "$CHAOS_ROUTES_FILE.tmp"
    mv "$CHAOS_ROUTES_FILE.tmp" "$CHAOS_ROUTES_FILE"
  done
  chaos_reload
}

chaos_reload() {
  # shellcheck source=scripts/lib/entry.sh
  source "$FARCI_ROOT/scripts/lib/entry.sh"
  farci_reload_entry >/dev/null
  # Caddy écarte un amont 20 s après un échec : on laisse le temps à la
  # nouvelle configuration d'être celle que voient les clients.
  sleep 2
}

# --- assertions, partagées par les scénarios -------------------------------
CHAOS_DOSSIER="${FARCI_ROOT}/datasets/raw/patient_1234567890123_crap.txt"

# Code HTTP d'une extraction d'un dossier par la passerelle de la salle.
chaos_chat_code() {
  local model="${1:-med-extraction}" body
  body="$(python3 -c 'import json,sys; print(json.dumps({"model": sys.argv[1], "messages": [{"role": "user", "content": open(sys.argv[2], encoding="utf-8").read()}]}))' "$model" "$CHAOS_DOSSIER")"
  curl -s --noproxy '*' -o /dev/null -w '%{http_code}' --max-time 120 \
    -X POST "${FARCI_GATEWAY_URL:?FARCI_GATEWAY_URL manquante (REFERENCE_IP)}/chat/completions" \
    -H "Content-Type: application/json" -H "Authorization: Bearer ${GATEWAY_KEY_STANDARD:-farci}" \
    -d "$body" || true
}

# Extraction réelle de N dossiers dans un dossier temporaire ; affiche le bilan.
#   chaos_extract <n> [modèle]  ->  « écrits rejetés erreurs »
chaos_extract() {
  local n="$1" model="${2:-med-extraction}" tmp out
  tmp="$(mktemp -d)"
  # On lit LA LIGNE DU BILAN, pas la dernière ligne : quand l'observabilité
  # est coupée (scénario 07), OpenTelemetry écrit son échec d'export APRÈS
  # le bilan, à la sortie du programme.
  out="$(python3 "$FARCI_ROOT/07-applications/python/run_pipeline.py" --limit "$n" \
           --model "$model" --output "$tmp" 2>&1 | grep -E 'dossier\(s\) écrit\(s\)' | tail -1 || true)"
  rm -rf "$tmp"
  python3 -c 'import re,sys; m=[int(x) for x in re.findall(r"(\d+)", sys.argv[1])[:3]]; print(*(m+[0,0,0])[:3])' "$out"
}

# chaos_expect <description> <commande…> : PASS/FAIL lisible, code de retour.
chaos_expect() {
  local description="$1"; shift
  if "$@"; then ok "ATTENDU : $description"; return 0; fi
  err "INATTENDU : $description"
  return 1
}
