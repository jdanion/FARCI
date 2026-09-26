#!/usr/bin/env bash
# FARCI — aide contextuelle : ./bin/farci read <EQUIPE>
#
# Affiche le TUTORIAL.md d'une équipe. Trivial en apparence, mais utile : les
# étudiants ne doivent pas avoir à deviner quels dossiers existent déjà.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Arguments : read [equipe] [fichier]
EQUIPE="${1:-}"
FILE="${2:-TUTORIAL.md}"

if [[ "$EQUIPE" == "-h" || "$EQUIPE" == "--help" ]]; then
  sed -n '2,6p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

if [[ -n "$EQUIPE" && "$EQUIPE" != "--list" && "$EQUIPE" != "-l" ]]; then
  # Chercher le dossier qui commence par le numéro ou le nom de l'équipe.
  candidate="$(find "$FARCI_ROOT" -maxdepth 1 -type d \
                 \( -name "${EQUIPE}*" -o -name "*${EQUIPE}*" \) \
                 -not -name '.git' -not -name 'offline' | sort | head -1)"
  if [[ -z "$candidate" ]]; then
    err "aucune équipe ne correspond à « $EQUIPE »"
    printf '\n  Équipes disponibles :\n' >&2
    find "$FARCI_ROOT" -maxdepth 1 -type d -name '[0-9][0-9]-*' | sort | sed "s|$FARCI_ROOT/|    |" >&2
    exit 1
  fi
  target="$candidate/$FILE"
  if [[ ! -r "$target" ]]; then
    err "$target n'existe pas encore"
    note "Cette équipe n'a pas encore livré son fichier (les phases arrivent progressivement)."
    printf '\n  Fichiers présents dans %s :\n' "$(basename "$candidate")" >&2
    find "$candidate" -maxdepth 1 -type f -printf '    %f\n' 2>/dev/null | sort >&2
    exit 1
  fi
  exec cat "$target"
fi

printf '\n  Tutoriels par équipe (FARCI §45) :\n\n'
for dir in $(find "$FARCI_ROOT" -maxdepth 1 -type d -name '[0-9][0-9]-*' | sort); do
  team="$(basename "$dir")"
  if [[ -r "$dir/$FILE" ]]; then
    status="${C_GREEN}prêt${C_RESET}"
  else
    status="${C_DIM}à venir${C_RESET}"
  fi
  printf '    %-34s %b\n' "$team" "$status"
done
printf '\n  Ouvrir :  ./bin/farci read <EQUIPE>     (ex. : read inference)\n'
printf '  Docs    :  ls %s/docs/\n\n' "$FARCI_ROOT"
exit 0
