#!/usr/bin/env bash
# FARCI — ./bin/farci rehearse : la répétition générale de J-1, en moins de 15 min
#
#   ./bin/farci rehearse                 tout ce qui s'applique à cette machine
#   ./bin/farci rehearse --poste         seulement le poste (sans la salle)
#   ./bin/farci rehearse --sans-chaos    sur le Pi : ne pas jouer les pannes
#   ./bin/farci rehearse --budget 20     budget total en minutes (défaut 15)
#
# Trois parties, enchaînées selon la machine :
#   POSTE    outillage, configuration, images, plan C (extraction rejouée + score)
#   SALLE    si l'accueil (REFERENCE_IP) répond : service rendu, contrat de la
#            passerelle, EDS-NLP (avertissement), extraction réelle de 3
#            dossiers par l'accueil
#   SECOURS  sur la machine qui porte l'accueil (le Pi) : rescue, scénarios de
#            chaos de la séance, reset-all
#
# Chaque étape a un budget de temps et une gravité : BLOQUANT (la séance ne
# peut pas se tenir) ou AVERTISSEMENT (à corriger, la séance tient). Verdict
# final PASS / FAIL, code de sortie 0 / 1, rapport dans datasets/reports/.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,18p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

ONLY_POSTE=0
CHAOS=1
BUDGET_MIN=15
while (( $# > 0 )); do
  case "$1" in
    --poste)      ONLY_POSTE=1 ;;
    --sans-chaos) CHAOS=0 ;;
    --budget)     shift; BUDGET_MIN="${1:?--budget requiert un nombre de minutes}" ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "option inconnue : $1"; usage >&2; exit 64 ;;
  esac
  shift
done

farci_load_env
need_python
export no_proxy='*' NO_PROXY='*'

FARCI="$FARCI_ROOT/bin/farci"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/farci-rehearse.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
STARTED=$SECONDS
declare -a ROWS=()
BLOCKING_FAILS=0
WARNINGS=0

# run_step <nom> <BLOQUANT|AVERTISSEMENT> <budget_s> <piste> <commande…>
# Lance la commande avec un budget de temps, journalise sa sortie, et range
# le résultat. En cas d'échec : les dernières lignes et la piste de réparation.
run_step() {
  local name="$1" gravity="$2" budget="$3" hint="$4"; shift 4
  local log="$WORK/$name.log" start=$SECONDS rc result pid dog
  printf '%s▸ %-22s%s' "$C_BOLD" "$name" "$C_RESET"
  ( "$@" ) >"$log" 2>&1 &
  pid=$!
  ( sleep "$budget"; pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  dog=$!
  wait "$pid"; rc=$?
  pkill -P "$dog" 2>/dev/null; kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  local took=$(( SECONDS - start ))
  if (( rc == 0 )); then
    result="PASS"
    printf ' %sPASS%s  %ss\n' "$C_GREEN" "$C_RESET" "$took"
  else
    (( rc == 143 )) && printf 'budget de %ss dépassé\n' "$budget" >> "$log"
    if [[ "$gravity" == "BLOQUANT" ]]; then
      result="FAIL"; BLOCKING_FAILS=$((BLOCKING_FAILS + 1))
      printf ' %sFAIL%s  %ss\n' "$C_RED" "$C_RESET" "$took"
    else
      result="WARN"; WARNINGS=$((WARNINGS + 1))
      printf ' %sWARN%s  %ss\n' "$C_YELLOW" "$C_RESET" "$took"
    fi
    tail -n 8 "$log" | sed 's/^/      │ /'
    printf '      └ %s\n' "$hint"
  fi
  ROWS+=("$(printf '%-22s %-5s %4ss  %s' "$name" "$result" "$took" "$([[ $result == PASS ]] || printf '%s' "$hint")")")
}

skip_step() {
  printf '%s▸ %-22s%s %sSKIP%s  %s\n' "$C_BOLD" "$1" "$C_RESET" "$C_DIM" "$C_RESET" "$2"
  ROWS+=("$(printf '%-22s %-5s %4s   %s' "$1" "SKIP" "-" "$2")")
}

# --- étapes composées -------------------------------------------------------

# Plan C : extraction rejouée du jeu rapide, puis score contre le gold.
step_plan_c() {
  "$FARCI" extract --replay --subset quick --output "$WORK/extracted/rehearse-replay" \
    && "$FARCI" evaluate --extracted-dir "$WORK/extracted" --runs rehearse-replay \
         --subset quick --min-f1 0.9
}

# Le service rendu à la salle (équipes ou référence). Docling est à part :
# optionnel sur le Pi, il est livré par l'équipe 4 le jour J.
#   step_service_rendu sans-docling | docling
room_json() { python3 "$FARCI_ROOT/scripts/board.py" --json; }
step_service_rendu() {
  room_json | python3 -c '
import json, sys
room = json.load(sys.stdin)
missing = room["service_rendu"].get("missing", [])
print("service rendu :", room["service_rendu"]["state"], "— il manque :", ", ".join(missing) or "rien")
if sys.argv[1] == "docling":
    sys.exit(1 if "docling" in missing else 0)
sys.exit(1 if [m for m in missing if m != "docling"] else 0)' "$1"
}

# Trois dossiers par l'accueil : au moins un écrit, aucune erreur d'appel.
step_extraction_salle() {
  local out
  out="$("$FARCI" extract --subset quick --limit 3 --output "$WORK/extracted/rehearse-salle" 2>&1)"
  printf '%s\n' "$out"
  python3 - "$out" <<'PY'
import re, sys
m = re.search(r"(\d+) dossier\(s\) écrit\(s\), (\d+) rejeté\(s\).*?(\d+) erreur\(s\)", sys.argv[1])
if not m:
    sys.exit("bilan d'extraction introuvable")
written, rejected, errors = map(int, m.groups())
sys.exit(0 if written >= 1 and errors == 0 else 1)
PY
}

# rescue : la ligne Inference passe à la référence, puis revient.
served_by_inference() {
  room_json | python3 -c '
import json, sys
room = json.load(sys.stdin)
print(next(s["served_by"] for s in room["services"] if s["id"] == "inference-ollama"))'
}
step_rescue() {
  "$FARCI" rescue inference >/dev/null || return 1
  sleep 2
  local served
  served="$(served_by_inference)"
  "$FARCI" rescue --off inference >/dev/null || return 1
  echo "pendant rescue, Inference servie par : $served"
  [[ "$served" == "reference" ]]
}

# Après reset-all : ni panne, ni bascule forcée.
step_reset_all() {
  "$FARCI" reset-all || return 1
  room_json | python3 -c '
import json, sys
room = json.load(sys.stdin)
left = room["rescue"] + room["chaos"]["exclues"] + room["chaos"]["coupees"]
print("restant :", ", ".join(left) or "rien")
sys.exit(1 if left else 0)'
}

entry_alive() { [[ "$(http_code "${FARCI_ENTRY_URL:-}/livez" 3)" == "200" ]]; }
carries_entry() { docker ps --format '{{.Names}}' 2>/dev/null | grep -qxE 'farci-ref-caddy|farci-caddy'; }

# --- déroulé ---------------------------------------------------------------

section "Répétition générale — poste ($(hostname))"
run_step outillage      BLOQUANT 120 "./bin/farci selftest : il dit quelle cible est cassée" "$FARCI" selftest
run_step tests-unitaires BLOQUANT 240 "./bin/farci test-unit -k <nom> pour isoler ; pydantic : wheels hors ligne (./bin/farci verify-wheels)" "$FARCI" test-unit
run_step configuration  BLOQUANT 30  "config/network.env : REFERENCE_IP et FARCI_SUBNET (./bin/farci env)" "$FARCI" env-check
if carries_entry; then
  run_step images       BLOQUANT 120 "sur le Pi : ./preload.sh --reference (avec Internet)" "$FARCI" verify-images --reference
else
  run_step images       BLOQUANT 120 "./preload.sh --core, ou docker load depuis la clé USB" "$FARCI" verify-images
  run_step modeles      AVERTISSEMENT 60 "./preload.sh --models-ci au minimum (modèle de secours)" "$FARCI" verify-models
fi
run_step plan-c         BLOQUANT 180 "./bin/farci extract --replay doit toujours marcher : voir tests/test_replay.py" step_plan_c

if (( ONLY_POSTE )); then
  skip_step salle "--poste"
elif ! entry_alive; then
  run_step accueil BLOQUANT 10 "accueil injoignable : Wi-Fi du Pi ? ./bin/farci up reference sur le Pi ? (reference/README.md)" entry_alive
else
  section "Répétition générale — salle (${FARCI_ENTRY_URL})"
  run_step accueil        BLOQUANT 10  "" entry_alive
  run_step service-rendu  BLOQUANT 60  "./bin/farci status : la liste « Il manque »" step_service_rendu sans-docling
  run_step documents      AVERTISSEMENT 60 "pas de Docling dans la salle : ./bin/farci up reference docling, sinon l'équipe 4 le livrera" step_service_rendu docling
  run_step contrat-passerelle BLOQUANT 150 "./bin/farci logs reference litellm ; ./bin/farci status" "$FARCI_ROOT/tests/test_gateway_contract.sh"
  run_step eds-nlp AVERTISSEMENT 60 "EDS-NLP hors READY : ./bin/farci up reference eds-nlp, ou l'équipe 4 le livrera" \
    env EDS_NLP_URL="${FARCI_EDS_URL:-}" "$FARCI_ROOT/tests/test_eds_nlp.sh"
  run_step extraction-salle BLOQUANT 300 "plus lent que 5 min : rescue inference le jour J ; erreurs : ./bin/farci logs reference" step_extraction_salle

  if ! carries_entry; then
    skip_step secours "à jouer sur la machine qui porte l'accueil (le Pi)"
  else
    section "Répétition générale — secours (sur cette machine)"
    run_step rescue BLOQUANT 90 "./bin/farci rescue : config/rescue.env, puis ./bin/farci up reference" step_rescue
    if (( CHAOS )); then
      for scenario in 01 04 05 06 07; do
        run_step "chaos-$scenario" BLOQUANT 120 "docs/CHAOS.md, scénario $scenario ; ./bin/farci chaos reset" \
          "$FARCI" chaos "scenario-$scenario"
        "$FARCI" chaos reset >/dev/null 2>&1
      done
    else
      skip_step chaos "--sans-chaos"
    fi
    run_step reset-all BLOQUANT 120 "./bin/farci chaos status ; rm config/rescue.env ; ./bin/farci up reference" step_reset_all
  fi
fi

# --- verdict ---------------------------------------------------------------

TOTAL=$(( SECONDS - STARTED ))
if (( BLOCKING_FAILS > 0 )); then VERDICT="FAIL"; else VERDICT="PASS"; fi
REPORT_DIR="$FARCI_ROOT/datasets/reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/rehearse-$(date +%Y%m%d-%H%M).txt"
{
  printf 'FARCI — répétition générale du %s sur %s\n\n' "$(date '+%Y-%m-%d %H:%M')" "$(hostname)"
  printf 'ÉTAPE                  ÉTAT  DURÉE  PISTE\n'
  printf '%s\n' "${ROWS[@]}"
  printf '\nDurée totale : %d min %02d s (budget %d min)\n' $((TOTAL / 60)) $((TOTAL % 60)) "$BUDGET_MIN"
  printf 'Verdict : %s (%d bloquant(s), %d avertissement(s))\n' "$VERDICT" "$BLOCKING_FAILS" "$WARNINGS"
} > "$REPORT"

section "Verdict"
cat "$REPORT"
printf '\nRapport : %s\n' "${REPORT#"$FARCI_ROOT"/}"
if (( TOTAL > BUDGET_MIN * 60 )); then
  warn "la répétition a dépassé son budget : le jour J, ces vérifications seront trop longues"
fi
if [[ "$VERDICT" == "PASS" ]]; then
  ok "PASS : la séance peut se tenir"
  exit 0
fi
err "FAIL : corriger les étapes BLOQUANT ci-dessus, puis relancer ./bin/farci rehearse"
exit 1
