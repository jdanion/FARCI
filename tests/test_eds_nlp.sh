#!/usr/bin/env bash
# FARCI — test EDS-NLP (équipe 4) : le service pseudonymise un dossier
#
# Contrat : POST /v1/pseudonymiser avec le contexte patient ; aucun nom ni
# IPP du contexte ne doit rester dans le texte rendu. Sans EDS_NLP_IP
# déclarée, on teste le service de CETTE machine (EDS_NLP_PORT).

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="eds-nlp"
test_start
test_local_default EDS_NLP_URL EDS_NLP_PORT
test_need_service EDS_NLP_URL /health

payload='{"texte": "Patient : Jean Dupont\nIPP : 1234567890123\nNé le 15/03/1958.", "contexte": {"NOM": ["Dupont"], "PRENOM": ["Jean"], "IPP": ["1234567890123"]}}'
response=$(curl -sf --max-time 30 -X POST "$EDS_NLP_URL/v1/pseudonymiser" \
  -H "Content-Type: application/json" -d "$payload" 2>/dev/null || echo "")

if [[ -z "$response" ]]; then
  test_fail "POST /v1/pseudonymiser ne répond pas"
elif printf '%s' "$response" | python3 -c '
import json, sys
texte = json.load(sys.stdin)["texte"]
sys.exit(0 if "[NOM]" in texte and not any(x in texte for x in ("Dupont", "Jean", "1234567890123")) else 1)'; then
  test_pass "pseudonymisation"
else
  test_fail "identité encore visible : $response"
fi

test_finish
