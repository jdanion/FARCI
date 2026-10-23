#!/usr/bin/env bash
# FARCI — ./bin/farci ci
# Ce que la CI exécute, et rien d'autre : la même commande en local et sur le
# runner (Gitea Actions ou GitHub Actions). Sans réseau, sans Docker, sans GPU.
#
#   1. selftest   registre des cibles, parseurs maison, --help de chaque cible
#   2. lint       versions, adresses, documentation, air-gap, shell, Python
#   3. test-unit  évaluation, parité du schéma, sortie structurée, pseudonymisation
#   4. évaluation de contrôle : gold contre gold = score parfait
#   5. dataset    le gold se régénère à l'identique depuis le registre

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,11p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

FARCI="$FARCI_ROOT/bin/farci"
failures=()

step() {
  local name="$1"; shift
  section "ci : $name"
  if "$@"; then
    ok "$name"
  else
    err "$name"
    failures+=("$name")
  fi
}

gold_is_reproducible() {
  local tmp rc=0
  tmp="$(mktemp -d)"
  python3 "$FARCI_ROOT/datasets/tools/build_gold.py" --output "$tmp" >/dev/null || rc=1
  diff -r --exclude=.gitkeep "$tmp" "$FARCI_ROOT/datasets/gold" || rc=1
  rm -rf "$tmp"
  return "$rc"
}

step "selftest"          "$FARCI" selftest
step "lint"              "$FARCI" lint --quiet
step "tests unitaires"   "$FARCI" test-unit
step "gold contre gold"  "$FARCI" evaluate --extracted-dir "$FARCI_ROOT/datasets/gold" --min-f1 1.0
step "gold reproductible" gold_is_reproducible

printf '\n'
if (( ${#failures[@]} )); then
  err "CI en échec : ${failures[*]}"
  exit 1
fi
ok "CI verte"
