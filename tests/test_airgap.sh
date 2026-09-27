#!/usr/bin/env bash
# FARCI — test air-gap : images présentes, pas de pull

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/common.sh"

TEST_NAME="airgap"
test_start

# Vérifier que les images requises sont présentes
images=(
  "gitea/gitea:${GITEA_VERSION}"
  "ollama/ollama:${OLLAMA_VERSION}"
  "caddy:${CADDY_VERSION}"
)

missing=0
for img in "${images[@]}"; do
  if ! docker image inspect "$img" >/dev/null 2>&1; then
    missing=$((missing + 1))
  fi
done

if [[ "$missing" -eq 0 ]]; then
  test_pass "images présentes"
else
  test_fail "$missing image(s) manquante(s)"
fi

test_finish
