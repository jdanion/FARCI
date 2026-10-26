#!/usr/bin/env bash
# FARCI — ./bin/farci seance : préparer une nouvelle séance, en une commande
#
#   ./bin/farci seance nouvelle                    tout remettre à zéro, sauf les extractions
#   ./bin/farci seance nouvelle --garder-equipes   garder noms, étudiants et adresses
#                                                  (même groupe, deuxième journée)
#   ./bin/farci seance nouvelle --tout             ranger aussi les extractions des étudiants
#
# À lancer sur le Pi (la machine qui porte l'accueil). Dans l'ordre :
#   1. sauvegarde de la séance qui se termine dans $FARCI_DATA_DIR/seances/<date>/
#      (adresses, équipes, scores du tableau ; avec --tout, les extractions)
#   2. oublie les adresses des équipes (config/network.env) et leurs noms et
#      étudiants (config/salle.json) : le Pi sert de nouveau toute la salle 🛟
#   3. reset-all : pannes de chaos réparées, fin des bascules, accueil rechargé
#   4. tableau à zéro (scores, badges, fil, chrono)
#   5. republie le partage (/rejoindre) s'il a déjà été publié
# Rien n'est perdu : tout ce qui est effacé est d'abord copié dans la sauvegarde.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

case "${1:-}" in
  -h|--help|"") usage; exit 0 ;;
  nouvelle) shift ;;
  *) err "commande inconnue : $1"; usage >&2; exit 64 ;;
esac

GARDER=0 TOUT=0
for arg in "$@"; do
  case "$arg" in
    --garder-equipes) GARDER=1 ;;
    --tout) TOUT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "option inconnue : $arg (voir ./bin/farci seance --help)" ;;
  esac
done

farci_load_env
FARCI="$FARCI_ROOT/bin/farci"
SAUVEGARDE="$FARCI_DATA_DIR/seances/$(date '+%Y%m%d-%H%M%S')"
ECHECS=0
echec() { warn "$1"; ECHECS=$(( ECHECS + 1 )); }

aggregator() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -xE 'farci-ref-aggregator|farci-health-aggregator' | head -1
}

section "1/5 sauvegarde de la séance qui se termine"
mkdir -p "$SAUVEGARDE"
for f in config/network.env config/salle.json config/rescue.env; do
  [[ -f "$FARCI_ROOT/$f" ]] && cp -p "$FARCI_ROOT/$f" "$SAUVEGARDE/"
done
agg="$(aggregator || true)"
if [[ -n "$agg" ]]; then
  docker exec "$agg" cat /data/tableau.json > "$SAUVEGARDE/tableau.json" 2>/dev/null || rm -f "$SAUVEGARDE/tableau.json"
fi
if (( TOUT )); then
  for d in datasets/extracted datasets/pseudonymized; do
    if compgen -G "$FARCI_ROOT/$d/[!.]*" >/dev/null; then
      mkdir -p "$SAUVEGARDE/$d"
      # On déplace les runs, pas les fichiers cachés du dossier (.gitignore).
      find "$FARCI_ROOT/$d" -mindepth 1 -maxdepth 1 ! -name '.*' -exec mv -t "$SAUVEGARDE/$d" {} +
      ok "$d rangé dans la sauvegarde"
    fi
  done
fi
ok "sauvegarde : $SAUVEGARDE"

section "2/5 équipes"
if (( GARDER )); then
  info "noms, étudiants et adresses gardés (--garder-equipes)"
else
  oubliees="$(FARCI_ROOT="$FARCI_ROOT" python3 - <<'PY'
import os, sys
root = os.environ["FARCI_ROOT"]
sys.path[:0] = [os.path.join(root, "scripts"), os.path.join(root, "01-network-dashboard", "health-aggregator")]
import salle, services
actuel = salle.lire_network_env()
variables = {str(s["ip_var"]) for s in services.services()} - {"REFERENCE_IP"}
changements = {v: "" for v in sorted(variables) if actuel.get(v)}
if changements:
    salle.ecrire_adresses(changements)
print(len(changements))
PY
)" || { echec "adresses non effacées : voir ci-dessus"; oubliees="?"; }
  ok "adresses des équipes oubliées : $oubliees (le Pi sert toute la salle 🛟)"
  rm -f "$FARCI_ROOT/config/salle.json"
  ok "noms des équipes et étudiants effacés"
fi

section "3/5 salle (reset-all)"
"$FARCI" reset-all || echec "reset-all a signalé un problème : voir ci-dessus"

section "4/5 tableau"
if [[ -n "$(aggregator || true)" ]]; then
  "$FARCI" tableau reset || echec "tableau non remis à zéro"
else
  echec "aucun agrégateur ne tourne ici : ./bin/farci dashboard-up, puis ./bin/farci tableau reset"
fi

section "5/5 partage (/rejoindre)"
if [[ -d "$FARCI_DATA_DIR/partage/farci.git" ]]; then
  "$FARCI" partage maj >/dev/null && ok "partage republié : version $(git -C "$FARCI_ROOT" rev-parse --short HEAD)" \
    || echec "partage non republié : ./bin/farci partage maj"
else
  info "rien de publié jusqu'ici (./bin/farci partage maj pour les étudiants sans git clone)"
fi

printf '\n'
if (( ECHECS )); then
  err "nouvelle séance préparée avec $ECHECS point(s) à reprendre (ci-dessus)"
  exit 1
fi
ok "nouvelle séance prête — séance précédente sauvegardée dans $SAUVEGARDE"
