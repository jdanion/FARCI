#!/usr/bin/env bash
# FARCI — ./bin/farci tableau : le tableau de la salle (écran projeté, iPad)
#
#   ./bin/farci tableau            adresses à ouvrir (iPad, vidéoprojecteur)
#   ./bin/farci tableau reset      scores, badges, fil et chrono à zéro (les noms d'équipe
#                                  et les adresses restent : ./bin/farci seance nouvelle)
#
# Le tableau est servi par l'agrégateur de santé de la machine qui porte
# l'accueil (le Pi : farci-ref-aggregator ; l'équipe 1 : farci-health-aggregator).
# Les points se gagnent seuls : une brique livrée = une brique servie par
# l'accueil (✅), pas une déclaration.
#
# Onglet formateur : /tableau/formateur — noms d'équipes, étudiants et adresse
# de chaque brique (écrit config/salle.json et config/network.env sur le Pi,
# comme ./bin/farci room set, puis recharge l'accueil).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

aggregator() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -xE 'farci-ref-aggregator|farci-health-aggregator' | head -1
}

case "${1:-}" in
  -h|--help) sed -n '2,16p' "$0" | sed 's/^#\{0,1\} \{0,1\}//' ;;
  "")
    section "Tableau de la salle"
    printf '  %s/\n' "${FARCI_ENTRY_URL:-http://<REFERENCE_IP>}"
    [[ -n "${REFERENCE_IP:-}" ]] && printf '  http://%s:%s/tableau   (sans passer par l'"'"'accueil)\n' "$REFERENCE_IP" "${HEALTH_AGGREGATOR_PORT:-8088}"
    printf '\n  iPad : Safari → Partager → « Sur l'"'"'écran d'"'"'accueil » pour le plein écran,\n'
    printf '  puis toucher « Plein écran · écran allumé ».\n'
    printf '\n  Onglet formateur (noms des équipes, étudiants, IP de chaque brique,\n'
    printf '  suivi UP/DOWN en direct) : %s/tableau/formateur\n' "${FARCI_ENTRY_URL:-http://<REFERENCE_IP>}"
    ;;
  reset)
    need_docker
    name="$(aggregator)"
    [[ -n "$name" ]] || die "aucun agrégateur ne tourne ici : ./bin/farci up reference"
    docker exec "$name" rm -f /data/tableau.json
    ok "tableau remis à zéro : scores, badges, fil et chrono (prochain sondage, quelques secondes)"
    info "les briques encore servies par une équipe regagnent leurs points au sondage suivant,"
    info "et les noms d'équipe restent (onglet formateur). Tout effacer : ./bin/farci seance nouvelle"
    ;;
  *) err "commande inconnue : $1"; exit 64 ;;
esac
