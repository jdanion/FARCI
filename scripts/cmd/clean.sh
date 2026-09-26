#!/usr/bin/env bash
# FARCI — ./bin/farci clean
#
# Par DÉFAUT : n'efface rien, affiche ce qui serait supprimé. Le dépôt contient
# des choses qu'il est coûteux de refaire (extractions d'étudiants), et un rm
# imprudent le jour J serait irrécupérable.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DRY=1
ALL=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) DRY=0 ;;
    --all)    ALL=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *) die "option inconnue : $arg" ;;
  esac
done

# Cibles "volatiles" : recalculables, sans valeur pédagogique.
declare -a VOLATILE=(
  "__pycache__"
  "*.pyc"
  ".pytest_cache"
  ".chaos"
  "logs"
)

# Cibles "de travail" : produites par les étudiants, à confirmer explicitement.
declare -a TRAVAIL=(
  "datasets/extracted"
  "datasets/pseudonymized"
)

# Cibles "lourdes" : jamais supprimées automatiquement.
declare -a LOURD=(
  "offline"
)

purge() {
  local base="$1" pattern
  for pattern in "${base}"; do
    # shellcheck disable=SC2086
    find "$FARCI_ROOT" -path "$FARCI_ROOT/.git" -prune -o -name "$pattern" -print 2>/dev/null
  done
}

show_or_remove() {
  local label="$1" paths=("$2" "$3")
  local found=0 item
  for item in "${paths[@]}"; do
    [[ -z "$item" ]] && continue
    while IFS= read -r found_path; do
      [[ -z "$found_path" ]] && continue
      found=1
      if (( DRY )); then
        printf '  %s%-40s%s %s\n' "$C_DIM" "${found_path#$FARCI_ROOT/}" "$C_RESET" "($label)"
      else
        rm -rf "$found_path" && ok "supprimé : ${found_path#$FARCI_ROOT/}"
      fi
    done < <(purge "$item")
  done
  (( found )) || info "$label : rien à faire"
}

section "artefacts volatils (suppression sans danger)"
show_or_remove "volatil" "__pycache__" "*.pyc"
show_or_remove "volatil" ".pytest_cache" ""

section "état du chaos"
if [[ -e "$FARCI_ROOT/.chaos" ]]; then
  if (( DRY )); then
    warn ".chaos présent (scénarios peut-être encore appliqués) :"
    ls -1 "$FARCI_ROOT/.chaos" 2>/dev/null | sed 's/^/        /' >&2
  else
    rm -rf "$FARCI_ROOT/.chaos" && ok "état du chaos réinitialisé"
  fi
else
  info "aucun scénario de chaos en cours"
fi

if (( ALL )); then
  section "travail étudiant (--all : CONFIRMEZ que c'est voulu)"
  if (( DRY )); then
    for item in "${TRAVAIL[@]}"; do
      if [[ -d "$FARCI_ROOT/$item" ]] && [[ -n "$(ls -A "$FARCI_ROOT/$item" 2>/dev/null)" ]]; then
        warn "${item}/ contient des fichiers :"
        ls -1 "$FARCI_ROOT/$item" 2>/dev/null | head -5 | sed 's/^/        /' >&2
      fi
    done
  else
    for item in "${TRAVAIL[@]}"; do
      if [[ -d "$FARCI_ROOT/$item" ]]; then
        rm -rf "${FARCI_ROOT:?}/$item"/* 2>/dev/null || true
        ok "vidé : $item/"
      fi
    done
  fi
  printf '\n'
  info "réécrire avec --yes pour appliquer :  ./bin/farci clean --all --yes"
else
  info "pour inclure les extractions d'étudiants : ./bin/farci clean --all"
fi

section "répertoires lourds (jamais supprimés automatiquement)"
for item in "${LOURD[@]}"; do
  if [[ -e "$FARCI_ROOT/$item" || -L "$FARCI_ROOT/$item" ]]; then
    size="$(du -shL "$FARCI_ROOT/$item" 2>/dev/null | cut -f1 || echo '?')"
    line="  ${item}/ — ${size} — conservé (re-télécharger prend des heures)"
    printf '%s\n' "$line"
  else
    printf '  %s/ — absent\n' "$item"
  fi
done

if (( DRY )); then
  printf '\n'
  info "mode simulation : rien n'a été supprimé"
  info "appliquer :      ./bin/farci clean --yes"
fi
exit 0
