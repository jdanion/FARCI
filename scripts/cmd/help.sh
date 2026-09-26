#!/usr/bin/env bash
# FARCI — ./bin/farci help
# Affiche les cibles, lues dans scripts/targets.def (source de vérité).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DEFINITIONS="$FARCI_ROOT/scripts/targets.def"
CMD_DIR="$FARCI_ROOT/scripts/cmd"

declare -A GROUP_TITLES=(
  [atelier]="Atelier"
  [qualité]="Qualité"
  [reseau]="Réseau"
  [nettoyage]="Nettoyage"
)
GROUP_ORDER=(atelier qualité reseau nettoyage)

group_title() {
  local key="$1"
  if [[ -n "${GROUP_TITLES[$key]:-}" ]]; then
    printf '%s' "${GROUP_TITLES[$key]}"
  else
    printf '%s' "$key"
  fi
}

# Aligne "nom" et "description" en colonnes, quelle que soit la largeur du nom.
render() {
  local name="$1" description="$2" status="$3"
  local width="${4:-22}"
  printf '  %s%-*s%s %s' "$C_BOLD" "$width" "$name" "$C_RESET" "$description"
  [[ -n "$status" ]] && printf ' %s%s%s' "$C_YELLOW" "$status" "$C_RESET"
  printf '\n'
}

total=0
missing=0

if [[ ! -r "$DEFINITIONS" ]]; then
  die "registre de cibles introuvable : $DEFINITIONS"
fi

# Bandeau : les trois étapes du workshop (FARCI §44)
printf '%s' "$C_BOLD"
cat <<'BANNER'
   ┌──────────────────────────────────────────────────────────────┐
   │  FARCI — Forge & Agents en Réseau pour le Calcul d'Inférence│
   └──────────────────────────────────────────────────────────────┘
BANNER
printf '%s' "$C_RESET"

cat <<'INTRO'

  ÉTAPE 1  Construire la plateforme
       │
       ▼
  ÉTAPE 2  Utiliser la plateforme pour une extraction clinique
       │
       ▼
  ÉTAPE 3  Casser la plateforme et observer sa résilience
INTRO

for group in "${GROUP_ORDER[@]}"; do
  rows="$(awk -F'\t' -v g="$group" 'NF>=4 && $1 !~ /^#/ && $2==g {print $1"\t"$3"\t"$4}' "$DEFINITIONS")"
  [[ -z "$rows" ]] && continue
  section "$(group_title "$group")"
  width="$(printf '%s\n' "$rows" | cut -f1 | awk '{ if (length($0)>m) m=length($0) } END { print m+2 }')"
  (( width < 22 )) && width=22
  while IFS=$'\t' read -r name description script; do
    [[ -z "$name" ]] && continue
    total=$(( total + 1 ))
    if [[ -f "$CMD_DIR/$script" ]]; then
      render "$name" "$description" "" "$width"
    else
      missing=$(( missing + 1 ))
      render "$name" "$description" "[script manquant : $script]" "$width"
    fi
  done <<< "$rows"
done

section "Tutoriels"
render "read <EQUIPE>" "lire le TUTORIAL.md d'une équipe" "" 22
render "docs" "ouvrir docs/ARCHITECTURE.md" "" 22
render "checklist" "checklist formateur (docs/INSTRUCTOR_GUIDE.md)" "" 22

cat <<'FOOTER'

  Sans make ? Utilisez ./bin/farci <cible> — c'est exactement le même code.

  Trois premières commandes utiles :
    1. ./bin/farci doctor        # ma machine est-elle prête ?
    2. ./bin/farci bootstrap     # préparer cette machine
    3. ./bin/farci status        # où en est la construction ?
FOOTER

if (( missing > 0 )); then
  err "$missing cible(s) déclarée(s) sans script exécutable"
  exit 1
fi
exit 0
