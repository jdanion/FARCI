#!/usr/bin/env bash
# FARCI — test Docling : conversion d'un PDF du dataset
#
# Le dataset versionné est en .txt ; les PDF sont produits à la demande par
# ./bin/farci generate-dataset --pdf. Sans PDF, le test est SKIP.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="docling"
test_start
test_need_service DOCLING_URL /health

TEST_PDF="$(find "$FARCI_ROOT/datasets/raw" -name '*.pdf' -print -quit 2>/dev/null || true)"
if [[ -z "$TEST_PDF" ]]; then
  test_skip "aucun PDF (./bin/farci generate-dataset --pdf)"
  test_finish
  exit $?
fi

response=$(curl -sf --max-time 120 -X POST "$DOCLING_URL/v1/convert/file" \
  -F "files=@$TEST_PDF" \
  -F "to_formats=md" 2>/dev/null || echo "")

if [[ -n "$response" ]]; then
  test_pass "docling"
else
  test_fail "docling ne convertit pas $(basename "$TEST_PDF")"
fi

test_finish
