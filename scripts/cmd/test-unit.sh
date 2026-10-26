#!/usr/bin/env bash
# FARCI — ./bin/farci test-unit
# Tests unitaires Python (tests/test_*.py) : sans réseau, sans Docker, sans GPU.
# Écrits avec unittest (stdlib) : pytest n'est pas nécessaire, mais il sait
# aussi les exécuter. Les tests qui demandent pydantic sont SKIP s'il manque.
#
#   ./bin/farci test-unit
#   ./bin/farci test-unit -k evaluation

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
need_python

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,9p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

cd "$FARCI_ROOT/tests"
exec python3 -m unittest discover -s . -p 'test_*.py' "$@"
