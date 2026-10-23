#!/usr/bin/env bash
# FARCI — ./bin/farci verify-manifest
# Vérifie les empreintes SHA256 de $FARCI_DATA_DIR/offline contre
# MANIFEST.sha256 (produit par ./bin/farci gen-manifest ou ./preload.sh).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,4p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

farci_load_env
need sha256sum
[[ -f "$FARCI_MANIFEST" ]] || die "manifeste absent : $FARCI_MANIFEST (./bin/farci gen-manifest)"

section "FARCI — vérification du manifeste"
if (cd "$FARCI_OFFLINE_DIR" && sha256sum --quiet -c "$FARCI_MANIFEST"); then
  ok "$(wc -l < "$FARCI_MANIFEST") fichier(s) conformes au manifeste"
else
  die "des artefacts ne correspondent pas au manifeste : relancer ./preload.sh --core"
fi
