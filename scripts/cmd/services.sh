#!/usr/bin/env bash
# FARCI — accès au registre des services (./bin/farci services)
#
#   services            tableau de tous les services et de leurs variables
#   services --groups   répartition par groupes de dashboard (FARCI §13)

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

case "${1:---list}" in
  --list)    exec python3 "$FARCI_ROOT/scripts/services.py" list ;;
  --groups)  exec python3 "$FARCI_ROOT/scripts/services.py" groups ;;
  -h|--help) echo "usage: $0 [--list|--groups]"; exit 0 ;;
  *)         exec python3 "$FARCI_ROOT/scripts/services.py" list ;;
esac
