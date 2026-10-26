#!/usr/bin/env bash
# FARCI — ./bin/farci room : qui héberge quoi dans la salle
#
#   ./bin/farci room                      briques, IP déclarées, qui rend le service
#   ./bin/farci room set <cible> <ip>     déclare la machine d'une équipe
#   ./bin/farci room unset <cible>        oublie une machine (la référence reprend)
#   ./bin/farci room set reference <ip>   CHANGEMENT DE RÉSEAU (plan B du Wi-Fi) :
#                                         nouvelle IP du Pi, sous-réseau /24 déduit ;
#                                         à lancer sur CHAQUE poste
#
# <cible> : un numéro d'équipe (2, equipe-2 : toutes ses briques cœur) ou un
# service (gateway-bifrost, inference-llamacpp…). L'équipe lit son IP avec
# ./bin/farci doctor ; le formateur la déclare ICI, sur le Pi, et l'accueil
# de la salle se recharge. Les postes étudiants n'ont rien à changer.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/lib/entry.sh
source "$FARCI_LIB_DIR/entry.sh"

usage() { sed -n '2,12p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

NETWORK_ENV="$FARCI_ROOT/config/network.env"

# Variables d'IP visées par une cible (une par ligne).
ip_vars_of() {
  FARCI_ROOT="$FARCI_ROOT" python3 - "$1" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["FARCI_ROOT"], "scripts"))
import services
target = sys.argv[1].removeprefix("equipe-").lstrip("0") or "0"
rows = services.services()
if target.isdigit():
    picked = [s for s in rows if str(s.get("team")) == target and s.get("tier") == "core"]
else:
    picked = [s for s in rows if s["id"] == sys.argv[1]]
if not picked:
    sys.exit(f"cible inconnue : {sys.argv[1]} (numéro d'équipe ou id de service : ./bin/farci services)")
for var in dict.fromkeys(str(s["ip_var"]) for s in picked):
    print(var)
PY
}

set_var() {
  local var="$1" value="$2"
  [[ -f "$NETWORK_ENV" ]] || die "config/network.env absent : cp config/network.env.example config/network.env"
  if grep -q "^${var}=" "$NETWORK_ENV"; then
    sed -i.bak "s|^${var}=.*|${var}=${value}|" "$NETWORK_ENV" && rm -f "$NETWORK_ENV.bak"
  else
    printf '%s=%s\n' "$var" "$value" >> "$NETWORK_ENV"
  fi
}

show() {
  farci_load_env
  FARCI_ROOT="$FARCI_ROOT" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["FARCI_ROOT"], "scripts"))
import services
room = services.room_state(float(os.environ.get("FARCI_HEALTH_TIMEOUT", "2")))
labels = {"equipe": "✅ équipe", "reference": "🛟 référence", None: "—"}
print(f"  {'SERVICE':<20} {'ÉQUIPE':>3} {'VARIABLE':<20} {'IP DÉCLARÉE':<16} SERVI PAR")
by_id = {s["id"]: s for s in services.services()}
for r in room["services"]:
    s = by_id[r["id"]]
    ip = os.environ.get(str(s["ip_var"]), "") or "-"
    print(f"  {r['id']:<20} {str(s.get('team')):>3}    {str(s['ip_var']):<20} {ip:<16} {labels[r['served_by']]}")
print(f"\n  Accueil de la salle : {os.environ.get('FARCI_ENTRY_URL', '?')}   "
      f"pipeline des équipes : {room['pipeline']['state']}, service rendu : {room['service_rendu']['state']}")
PY
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") show ;;
  set)
    [[ $# -eq 3 ]] || die "usage : ./bin/farci room set <cible> <ip>"
    [[ "$3" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "adresse IPv4 attendue : $3"
    cp "$NETWORK_ENV" "$NETWORK_ENV.avant"
    if [[ "$2" == "reference" ]]; then
      # Nouveau réseau : nouvelle adresse du Pi, et les machines déclarées
      # sur l'ancien réseau ne sont plus valables (à redéclarer sur le Pi).
      set_var REFERENCE_IP "$3"; ok "REFERENCE_IP=$3"
      set_var FARCI_SUBNET "${3%.*}.0/24"; ok "FARCI_SUBNET=${3%.*}.0/24"
      while IFS= read -r var; do
        [[ -n "$(grep "^${var}=" "$NETWORK_ENV" | cut -d= -f2-)" ]] || continue
        set_var "$var" ""; warn "$var oubliée (ancien réseau) : la redéclarer avec room set"
      done < <(grep -oE '^[A-Z0-9_]+_IP=' "$NETWORK_ENV" | tr -d '=' | grep -vx REFERENCE_IP)
    else
      while IFS= read -r var; do set_var "$var" "$3"; ok "$var=$3"; done < <(ip_vars_of "$2")
    fi
    # Vérifier dans un environnement neuf ; en cas d'erreur, on remet l'ancien fichier.
    if ! env -i "PATH=$PATH" "HOME=$HOME" bash -c \
         "source '$FARCI_ROOT/scripts/dev-env.sh' && farci_load_env && python3 '$FARCI_ROOT/scripts/services.py' check-network"; then
      mv "$NETWORK_ENV.avant" "$NETWORK_ENV"
      die "adresse refusée : config/network.env inchangé"
    fi
    rm -f "$NETWORK_ENV.avant"
    farci_reload_entry
    ;;
  unset)
    [[ $# -eq 2 ]] || die "usage : ./bin/farci room unset <cible>"
    while IFS= read -r var; do set_var "$var" ""; ok "$var oubliée (la référence reprend)"; done < <(ip_vars_of "$2")
    farci_reload_entry
    ;;
  *) usage >&2; exit 64 ;;
esac
