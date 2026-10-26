#!/usr/bin/env bash
# FARCI — exporte les soumissions Open WebUI vers datasets/extracted/
#
# Normalise les JSON exportés par Open WebUI vers le format attendu.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

# L'Open WebUI de CETTE machine, sauf si OPEN_WEBUI_IP est déclarée.
WEBUI_URL="${OPEN_WEBUI_URL:-http://127.0.0.1:${OPEN_WEBUI_PORT:?OPEN_WEBUI_PORT manquant (config/network.env)}}"
OUTPUT_DIR="${1:-$FARCI_ROOT/datasets/extracted/webui}"

section "FARCI — export Open WebUI"

info "récupération des conversations..."
conversations=$(curl -sf "$WEBUI_URL/api/v1/chats/all" \
  -H "Authorization: Bearer sk-standard-placeholder" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data:
    print(c.get('id', ''))
" 2>/dev/null || echo "")

mkdir -p "$OUTPUT_DIR"

for conv_id in $conversations; do
  info "export de $conv_id..."
  curl -sf "$WEBUI_URL/api/v1/chats/$conv_id" \
    -H "Authorization: Bearer sk-standard-placeholder" | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Extraire le dernier message assistant
for msg in reversed(data.get('messages', [])):
    if msg.get('role') == 'assistant':
        content = msg.get('content', '')
        # Parser le JSON
        try:
            parsed = json.loads(content)
            print(json.dumps(parsed, ensure_ascii=False, indent=2))
        except json.JSONDecodeError:
            pass
        break
" > "$OUTPUT_DIR/$conv_id.json" 2>/dev/null || warn "export de $conv_id a échoué"
done

ok "export terminé → $OUTPUT_DIR"
