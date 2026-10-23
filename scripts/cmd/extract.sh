#!/usr/bin/env bash
# FARCI — ./bin/farci extract
# Parcours A (Python) : extrait tous les dossiers via la passerelle (Caddy /v1)
# et écrit datasets/extracted/<run>/patient_<IPP>.json.
#
#   ./bin/farci extract --subset quick
#   ./bin/farci extract --run equipe-3 --prompt v2

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
need_python

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  exec python3 "$FARCI_ROOT/07-applications/python/run_pipeline.py" --help
fi

farci_load_env
exec python3 "$FARCI_ROOT/07-applications/python/run_pipeline.py" "$@"
