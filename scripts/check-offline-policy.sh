#!/usr/bin/env bash
# FARCI — vérification de la politique air-gap (FARCI §52)
#
# Recherche les violations de la politique air-gap dans le code source :
# - URLs de CDN (cdnjs, unpkg, googleapis, etc.)
# - URLs de polices distantes
# - URLs JavaScript distantes
# - pull_policy: always dans les compose

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

VIOLATIONS=()

check_cdn_urls() {
  info "recherche de URLs de CDN..."
  local patterns=(
    "cdnjs\.cloudflare\.com"
    "unpkg\.com"
    "cdn\.jsdelivr\.net"
    "googleapis\.com"
    "fonts\.gstatic\.com"
    "cdn\.tailwindcss\.com"
    "ajax\.googleapis\.com"
  )

  for pat in "${patterns[@]}"; do
    while IFS= read -r line; do
      [[ -n "$line" ]] && VIOLATIONS+=("$line")
    done < <(grep -rn "$pat" "$FARCI_ROOT" \
      --include="*.html" --include="*.js" --include="*.css" \
      --include="*.vue" --include="*.ts" --include="*.tsx" \
      --include="*.py" --include="*.md" --include="*.yml" --include="*.yaml" \
      --exclude-dir=.git --exclude-dir=node_modules \
      2>/dev/null || true)
  done
}

check_pull_policy() {
  info "recherche de pull_policy: always..."
  while IFS= read -r line; do
    [[ -n "$line" ]] && VIOLATIONS+=("$line")
  done < <(grep -rn "pull_policy:.*always" "$FARCI_ROOT" \
    --include="docker-compose.yml" --include="compose.yml" \
    --exclude-dir=.git \
    2>/dev/null || true)
}

check_remote_build() {
  info "recherche de build: distants..."
  while IFS= read -r line; do
    [[ -n "$line" ]] && VIOLATIONS+=("$line")
  done < <(grep -rn "build:" "$FARCI_ROOT" \
    --include="docker-compose.yml" --include="compose.yml" \
    --exclude-dir=.git \
    2>/dev/null | grep -v "build: \." | grep -v "build: \.\/" || true)
}

main() {
  section "FARCI — vérification de la politique air-gap"

  check_cdn_urls
  check_pull_policy
  check_remote_build

  printf '\n'
  if (( ${#VIOLATIONS[@]} == 0 )); then
    ok "aucune violation de la politique air-gap détectée"
    return 0
  fi

  err "${#VIOLATIONS[@]} violation(s) détectée(s) :"
  for v in "${VIOLATIONS[@]}"; do
    printf '  %s\n' "$v"
  done
  return 1
}

main "$@"
