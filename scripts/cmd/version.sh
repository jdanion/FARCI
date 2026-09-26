#!/usr/bin/env bash
# FARCI — ./bin/farci version
# Affiche la version du dépôt et les versions figées (versions.env).
# Le pipeline llamacpp n'est pas une image : c'est un numéro de build compilé
# localement, d'où une ligne dédiée.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

FARCI_VERSION="0.1.0"

printf '%sFARCI %s%s  (socle du dépôt, phase 0)\n' "$C_BOLD" "$FARCI_VERSION" "$C_RESET"
printf 'racine : %s\n\n' "$FARCI_ROOT"

if [[ ! -r "$FARCI_ROOT/versions.env" ]]; then
  warn "versions.env introuvable"
  exit 0
fi

printf '%s%-34s %s%s\n' "$C_BOLD" "COMPOSANT" "VERSION" "$C_RESET"
printf '%s%-34s %s%s\n' "$C_DIM" "----------------------------------" "-------------" "$C_RESET"

emit_env_file "$FARCI_ROOT/versions.env" | while IFS='=' read -r key value; do
  printf '%-34s %s\n' "$key" "$value"
done

printf '\n%s# Client tools%s\n' "$C_DIM" "$C_RESET"
printf '%-34s %s\n' "python3" "$(python3 -V 2>&1 | awk '{print $2}')"
have docker && printf '%-34s %s\n' "docker" "$(docker --version | awk '{print $3}' | tr -d ,)"
have docker && docker compose version >/dev/null 2>&1 \
  && printf '%-34s %s\n' "docker compose" "$(docker compose version --short 2>/dev/null || echo installé)"
have git && printf '%-34s %s\n' "git" "$(git --version | awk '{print $3}')"
have make && printf '%-34s %s\n' "make" "$(make --version | head -1 | awk '{print $3}')" \
              || printf '%-34s %s\n' "make" "${C_YELLOW}absent (utilisez ./bin/farci)${C_RESET}"
have jq && printf '%-34s %s\n' "jq" "$(jq --version)" \
           || printf '%-34s %s\n' "jq" "${C_DIM}absent (non requis : stdlib python)${C_RESET}"

if [[ -r "$FARCI_ROOT/versions.lock.env" ]]; then
  locked="$(grep -c '_DIGEST=' "$FARCI_ROOT/versions.lock.env" || true)"
  printf '\n%s# empreintes%s : %s images figées\n' "$C_DIM" "$C_RESET" "$locked"
else
  printf '\n%s# empreintes : non figées — exécuter scripts/lock-digests.sh (phase 1, avec Internet)%s\n' \
    "$C_DIM" "$C_RESET"
fi
