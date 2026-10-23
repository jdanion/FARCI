#!/usr/bin/env bash
# FARCI — seed Uptime Kuma (création des moniteurs)
#
# Charge config/services.yaml et crée les moniteurs dans Uptime Kuma.
# Nécessite python-socketio (déjà dans requirements.in).

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

KUMA_URL="${UPTIME_KUMA_URL:?UPTIME_KUMA_IP/UPTIME_KUMA_PORT manquants : voir config/network.env}"

section "FARCI — seed Uptime Kuma"

info "URL Uptime Kuma: $KUMA_URL"

if ! python3 -c "import socketio" 2>/dev/null; then
  warn "python-socketio absent — installation..."
  pip3 install python-socketio
fi

exec python3 "$FARCI_ROOT/01-network-dashboard/uptime-kuma/seed/seed.py"
