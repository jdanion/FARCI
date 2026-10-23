#!/usr/bin/env bash
# FARCI — benchmark tokens/s CPU vs GPU
#
# Mesure le débit d'inférence pour comparer les runtimes et les quantifications.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

MODEL="${1:-ornith-1.5-9b-q5km}"
QUANT="${2:-q5km}"
BASE_URL="${3:-${INFERENCE_A_URL:?INFERENCE_A_IP/INFERENCE_A_PORT manquants : voir config/network.env}/v1}"

section "FARCI — benchmark $MODEL ($QUANT)"

PROMPT="Extract clinical data from: Patient 67M, pancreatic adenocarcinoma, DPC, pT3 pN1, 28mm tumor."

info "test de latence..."
start=$(date +%s%N)
response=$(curl -sf -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
    \"temperature\": 0,
    \"max_tokens\": 256
  }")
end=$(date +%s%N)

latency_ms=$(( (end - start) / 1000000 ))
tokens=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")

if [[ "$tokens" -gt 0 ]]; then
  tps=$(python3 -c "print(f'{($tokens / ($latency_ms / 1000)):.1f}')")
  ok "latence: ${latency_ms}ms, tokens: $tokens, débit: ${tps} tok/s"
else
  warn "impossible de calculer le débit"
fi
