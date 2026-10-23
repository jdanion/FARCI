#!/usr/bin/env bash
# FARCI — ./bin/farci replay : le runtime rejoué, sans Docker (plan C)
#
#   ./bin/farci replay                     écoute sur REPLAY_PORT (8090)
#   ./bin/farci replay --port 18090 --delay 0
#
# Un runtime conforme au contrat OpenAI qui renvoie les réponses enregistrées
# (reference/replay/recordings.json). Python standard seulement : il tourne
# sur n'importe quel poste, même sans Docker ni modèle. Pour extraire sans
# réseau du tout : ./bin/farci extract --replay.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,11p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

farci_load_env
need_python
exec python3 "$FARCI_ROOT/reference/replay/server.py" "$@"
