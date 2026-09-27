#!/usr/bin/env bash
# FARCI — test Docling : conversion PDF

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="docling"
test_start

DOCLING_URL="${DOCLING_URL:-http://192.168.50.40:5001}"
TEST_PDF="${FARCI_ROOT}/datasets/raw/patient_1234567890123_cro.pdf"

if [[ ! -f "$TEST_PDF" ]]; then
  test_skip "pdf absent"
  test_finish
  exit 0
fi

response=$(curl -sf -X POST "$DOCLING_URL/v1/convert/file" \
  -F "file=@$TEST_PDF" \
  -F "to_formats=md,json" 2>/dev/null || echo "")

if [[ -n "$response" ]]; then
  test_pass "docling"
else
  test_fail "docling ne répond pas"
fi

test_finish
