#!/usr/bin/env bash
# FARCI — smoke test Docling
#
# Convertit un PDF de test et vérifie la présence de titres et tableaux.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

DOCLING_URL="${DOCLING_URL:-http://192.168.50.40:5001}"
TEST_PDF="${1:-$FARCI_ROOT/datasets/raw/patient_1234567890123_cro.pdf}"

section "FARCI — smoke test Docling"

if [[ ! -f "$TEST_PDF" ]]; then
  err "PDF de test introuvable : $TEST_PDF"
  exit 1
fi

info "conversion de $TEST_PDF..."
response=$(curl -sf -X POST "$DOCLING_URL/v1/convert/file" \
  -F "file=@$TEST_PDF" \
  -F "to_formats=md,json" \
  -F "do_ocr=false" \
  -F "do_table_structure=true")

if [[ -z "$response" ]]; then
  err "réponse vide de Docling"
  exit 1
fi

# Vérifier la présence de titres et tableaux
if echo "$response" | grep -q "COMPTE RENDU"; then
  ok "titre détecté"
else
  warn "titre non détecté"
fi

if echo "$response" | grep -q "table"; then
  ok "tableau détecté"
else
  warn "tableau non détecté"
fi

ok "smoke test terminé"
