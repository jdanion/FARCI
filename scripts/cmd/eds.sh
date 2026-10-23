#!/usr/bin/env bash
# FARCI — ./bin/farci eds : utiliser le service EDS-NLP (AP-HP) de la salle
#
#   ./bin/farci eds pseudo  <fichier> [--sans-contexte]   pseudonymiser (EDS-Pseudo)
#   ./bin/farci eds entites <fichier> [--sans-pseudo]     entités par LLM (EDS-NLP)
#   ./bin/farci eds compare [--subset quick|full] [--limit N]   entités contre le gold
#
# Le service est joint par l'accueil de la salle (FARCI_EDS_URL) : celui de
# l'équipe 4, ou la doublure du Pi. Python standard seulement sur ce poste.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
  sed -n '2,10p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

farci_load_env
need_python
exec python3 "$FARCI_ROOT/04-clinical-documents/eds-nlp/client.py" "$@"
