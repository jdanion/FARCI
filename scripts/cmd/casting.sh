#!/usr/bin/env bash
# FARCI — ./bin/farci casting
# Répartit les étudiants dans les équipes selon leur matériel (casting/).
#
#   ./bin/farci casting                          exemple intégré
#   ./bin/farci casting --students eleves.json   vraie promotion
#   ./bin/farci casting --no-optional            rôles cœur seulement

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

exec python3 "$FARCI_ROOT/casting/casting.py" "$@"
