#!/usr/bin/env bash
# FARCI — recette finale (Definition of Done globale, §60)
#
# Vérifie que toutes les exigences du FARCI sont satisfaites.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

section "FARCI — recette finale"

passed=0
failed=0

check() {
  local name="$1"
  local command="$2"
  local expected="$3"

  info "Vérification : $name"
  if eval "$command" >/dev/null 2>&1; then
    ok "$name"
    passed=$((passed + 1))
  else
    err "$name"
    failed=$((failed + 1))
  fi
}

# §4 IP modifiables
check "§4 IP modifiables" \
  "./bin/farci lint-ips"

# §6 pas de latest
check "§6 pas de latest" \
  "test \$(grep -c 'latest' versions.env || true) -eq 0"

# §7 air-gap
check "§7 air-gap" \
  "./verify-airgap.sh"

# §14 agrégat
check "§14 agrégat" \
  "curl -sf --max-time 5 \"\$FARCI_STATUS_URL\""

# §16/§18 contrats
check "§16/§18 contrats" \
  "./tests/run-all.sh"

# §19 fallback
check "§19 fallback" \
  "./tests/test_failover.sh"

# §28 structured output
check "§28 structured output" \
  "./bin/farci test-unit"

# §34 score
check "§34 score" \
  "./bin/farci evaluate --extracted-dir datasets/gold"

# §38 rate limit
check "§38 rate limit" \
  "./chaos/chaos.sh scenario-03"

# §45 tutos
check "§45 tutos" \
  "./bin/farci lint-docs"

# §49 statut
check "§49 statut" \
  "./bin/farci status"

# §51 manifeste
check "§51 manifeste" \
  "test -f \$FARCI_MANIFEST"

# §52 aucun CDN
check "§52 aucun CDN" \
  "./bin/farci lint-offline"

# §0.1 dépôt léger
check "§0.1 dépôt léger" \
  "test \$(git count-objects -vH | grep 'size-pack' | awk '{print \$2}') -lt 8000"

# §0.2 poids partagés
check "§0.2 poids partagés" \
  "test -f \$FARCI_MODELS_DIR/Ornith-1.5-9B-Q5_K_M.gguf"

# Contrat reasoning
check "contrat reasoning" \
  "./bin/farci test-unit"

printf '\n'
printf 'Résultat : %d passé(s), %d échoué(s)\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
  err "recette échouée"
  exit 1
fi

ok "recette réussie — Definition of Done atteinte"
