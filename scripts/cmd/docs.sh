#!/usr/bin/env bash
# FARCI — aides contextuelles : docs, checklist
# Deux raccourcis qui évitent de demander « où est-ce que c'est écrit ? ».

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

WHAT="${1:-}"

# L'aide d'abord : elle ne doit dépendre ni du nom de la cible ni de la config.
case "${WHAT}" in
  -h|--help)
    cat <<'USAGE'
  usage : ./bin/farci <docs|contracts|flow|airgap|chaos|checklist|list>
USAGE
    exit 0 ;;
esac

# Deux cibles partagent ce script (voir scripts/targets.def).
case "${FARCI_TARGET:-docs}" in
  docs)      WHAT="${WHAT:-docs}" ;;
  checklist) WHAT="${WHAT:-checklist}" ;;
  *)         die "ce script ne connaît pas la cible « $FARCI_TARGET » (voir scripts/targets.def)" ;;
esac

show_doc() {
  local name="$1" file="$FARCI_ROOT/docs/$name"
  if [[ ! -r "$file" ]]; then
    err "docs/$name introuvable"
    exit 1
  fi
  exec cat "$file"
}

case "$WHAT" in
  docs|architecture)   show_doc ARCHITECTURE.md ;;
  contracts)           show_doc CONTRACTS.md ;;
  flow|workshop-flow)  show_doc WORKSHOP_FLOW.md ;;
  airgap)              show_doc AIRGAP.md ;;
  chaos)               show_doc CHAOS.md ;;
  checklist|formateur|instructor) show_doc INSTRUCTOR_GUIDE.md ;;
  -h|--help)
    cat <<'USAGE'
  usage : ./bin/farci <docs|contracts|flow|airgap|chaos|checklist|list>
USAGE
    exit 0 ;;
  list)
    printf '\n  Documentation disponible :\n\n'
    for f in "$FARCI_ROOT"/docs/*.md; do
      [[ -r "$f" ]] || continue
      printf '    %-28s %s lignes\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')"
    done
    printf '\n'
    exit 0 ;;
  *)
    err "document inconnu : $WHAT"
    printf '  disponibles : docs contracts flow airgap chaos checklist list\n' >&2
    exit 64 ;;
esac
