#!/usr/bin/env bash
# FARCI — ./bin/farci network-check
# Vérifie que le registre des services et les adresses sont cohérents :
#   - chaque service référence des variables d'environnement, pas des IP ;
#   - chaque variable est définie dans config/network.env ;
#   - chaque adresse est dans le sous-réseau déclaré ;
#   - aucun couple (adresse, port) n'est utilisé deux fois.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,7p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

if [[ ! -r "$FARCI_ROOT/config/network.env" ]]; then
  warn "config/network.env absent — les adresses ne sont pas encore définies."
  warn "Créer le fichier :  cp config/network.env.example config/network.env"
  warn "Puis vérifier :      ./bin/farci network-check"
  exit 2
fi

python3 "$FARCI_ROOT/scripts/services.py" check-network
