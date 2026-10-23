#!/usr/bin/env bash
# FARCI — agrégateur des tests d'intégration (FARCI §54)
#
#   ./bin/farci test                   tous les tests, SKIP si brique absente
#   FARCI_TESTS_STRICT=1 ./bin/farci test   recette : absent = FAIL
#
# Chaque test écrit une ligne « nom<TAB>résultat<TAB>durée<TAB>détail » et
# renvoie 0 (PASS), 1 (FAIL) ou 2 (SKIP). Code de sortie : 1 si un FAIL.

set -uo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,9p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

section "FARCI — tests d'intégration"

tests=(
  test_network.sh
  test_inference_contract.sh
  test_gateway_contract.sh
  test_docling.sh
  test_observability.sh
  test_gitops.sh
  test_airgap.sh
  test_failover.sh
)

failures=0
printf '%-22s %-6s %-7s %s\n' "TEST" "RÉSULTAT" "DURÉE" "DÉTAIL"
for test in "${tests[@]}"; do
  line="$(bash "$FARCI_ROOT/tests/$test" 2>/dev/null | tail -1)"
  [[ -z "$line" ]] && line="${test%.sh}	FAIL	-	aucune sortie"
  IFS=$'\t' read -r name result duration detail <<< "$line"
  printf '%-22s %-8s %-7s %s\n' "$name" "$result" "$duration" "$detail"
  [[ "$result" == "FAIL" ]] && failures=$(( failures + 1 ))
done

printf '\n'
if (( failures > 0 )); then
  err "$failures test(s) en échec"
  exit 1
fi
ok "aucun échec (les SKIP signalent une brique absente)"
