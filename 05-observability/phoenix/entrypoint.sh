#!/usr/bin/env bash
# FARCI — entrypoint Phoenix
# Configure les options avant de démarrer.

set -euo pipefail

export PHOENIX_WORKING_DIR="${PHOENIX_WORKING_DIR:-/phoenix}"
export PHOENIX_SERVER_HTTP_ENDPOINT="${PHOENIX_SERVER_HTTP_ENDPOINT:-http://0.0.0.0:6006}"

exec python -m phoenix.server.main serve
