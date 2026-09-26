#!/usr/bin/env bash
# FARCI — installation des outils système (make, shellcheck, unzip)
#
# Ces outils ne sont pas indispensables au fonctionnement du workshop
# (bin/farci fonctionne sans make), mais ils améliorent l'expérience.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"

section "FARCI — installation des outils"

install_if_missing() {
  local cmd="$1" pkg="$2"
  if have "$cmd"; then
    ok "$cmd déjà présent"
    return 0
  fi
  info "installation de $pkg..."
  if have apt-get; then
    apt-get update -qq && apt-get install -y -qq "$pkg"
  elif have apk; then
    apk add --no-cache "$pkg"
  elif have yum; then
    yum install -y "$pkg"
  else
    warn "gestionnaire de paquets inconnu — installer $pkg manuellement"
    return 1
  fi
  ok "$cmd installé"
}

install_if_missing make make
install_if_missing shellcheck shellcheck
install_if_missing unzip unzip
install_if_missing jq jq

ok "outils installés"
