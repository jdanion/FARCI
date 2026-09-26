#!/usr/bin/env bash
# FARCI — agrégateur de tests (FARCI §54)
#
# Exécute tous les tests et affiche un tableau de résumé.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

section "FARCI — suite de tests"

printf '╔══════════════════════════════════════════════════════════════╗\n'
printf '║ TEST                    │ RÉSULTAT │ DURÉE   │ DÉTAIL      ║\n'
printf '╠══════════════════════════════════════════════════════════════╣\n'

tests=(
  "test_airgap.sh"
  "test_gitops.sh"
  "test_network.sh"
  "test_inference_contract.sh"
  "test_gateway_contract.sh"
  "test_docling.sh"
  "test_observability.sh"
  "test_failover.sh"
)

for test in "${tests[@]}"; do
  test_path="$FARCI_ROOT/tests/$test"
  if [[ -f "$test_path" ]]; then
    output=$(bash "$test_path" 2>/dev/null || true)
    while IFS=$'\t' read -r name result duration detail; do
      [[ -z "$name" ]] && continue
      printf '║ %-23s │ %-8s │ %-7s │ %-12s ║\n' "$name" "$result" "$duration" "$detail"
    done <<< "$output"
  fi
done

printf '╚══════════════════════════════════════════════════════════════╝\n'
