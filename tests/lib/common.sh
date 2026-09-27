#!/usr/bin/env bash
# FARCI — bibliothèque de tests (tests/lib/common.sh)
# Helpers partagés par tous les tests.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "common.sh est une bibliothèque : utilisez 'source tests/lib/common.sh'" >&2
  exit 64
fi

FARCI_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FARCI_ROOT="$(cd "$FARCI_TESTS_DIR/../.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

# Résultats de test
TEST_RESULT="SKIP"
TEST_DETAIL=""
TEST_START=0

test_start() {
  TEST_START=$(date +%s%N)
  TEST_RESULT="SKIP"
  TEST_DETAIL=""
}

test_pass() {
  TEST_RESULT="PASS"
  TEST_DETAIL="${1:-}"
}

test_fail() {
  TEST_RESULT="FAIL"
  TEST_DETAIL="${1:-}"
}

test_skip() {
  TEST_RESULT="SKIP"
  TEST_DETAIL="${1:-}"
}

test_finish() {
  local end
  end=$(date +%s%N)
  local duration_ms=$(( (end - TEST_START) / 1000000 ))
  local duration_s
  duration_s=$(python3 -c "print(f'{$duration_ms / 1000:.1f}')")

  printf '%s\t%s\t%s\t%s\n' "$TEST_NAME" "$TEST_RESULT" "${duration_s}s" "$TEST_DETAIL"

  case "$TEST_RESULT" in
    PASS) return 0 ;;
    FAIL) return 1 ;;
    SKIP) return 2 ;;
  esac
}
