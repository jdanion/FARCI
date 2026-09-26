#!/usr/bin/env bash
# FARCI — handler de webhook (alternative bash)
#
# Ce script est appelé par le webhook receiver pour traiter les événements.
# Il vérifie la signature et déclenche GitOps.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"
GITOPS_SCRIPT="${FARCI_ROOT}/08-arcane-agents/gitops/gitops.sh"

# Lire le payload depuis stdin
payload="$(cat)"

# Vérifier la signature (si fournie en arg)
signature="${1:-}"
if [[ -n "$WEBHOOK_SECRET" && -n "$signature" ]]; then
  expected=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')
  if [[ "$signature" != "$expected" ]]; then
    err "signature invalide"
    exit 1
  fi
fi

# Extraire la branche (si présent dans le payload)
branch=$(echo "$payload" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    ref = data.get('ref', '')
    if ref.startswith('refs/heads/'):
        print(ref.replace('refs/heads/', ''))
    else:
        print('main')
except:
    print('main')
" 2>/dev/null || echo "main")

# Déclencher GitOps
info "déclenchement GitOps pour la branche $branch..."
exec bash "$GITOPS_SCRIPT" "$branch"
