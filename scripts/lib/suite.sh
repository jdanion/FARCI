#!/usr/bin/env bash
# FARCI — « et ensuite ? » (scripts/lib/suite.sh), sourcé par common.sh.
#
# À la fin de chaque commande, la ou les commandes à lancer ensuite, pour ne
# pas avoir à rouvrir le tutoriel. Le contenu est dans scripts/suite.def ;
# bin/farci appelle farci_suite après chaque cible, et les scripts lancés
# directement (./preload.sh, 00-gitops/gitea/bootstrap.sh…) dans un trap EXIT.
#
#   FARCI_SUITE=0   jamais        FARCI_SUITE=1   toujours (même hors terminal)
#   par défaut      seulement si la sortie d'erreur est un terminal
#
# Écrit sur la sortie d'erreur : `./bin/farci status --json | …` reste propre.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "suite.sh est une bibliothèque : source scripts/lib/suite.sh" >&2
  exit 64
fi

# {1} ou {1|défaut} : le premier argument de la commande, sinon <défaut>
# (<dossier> pour {1}, <valeur> pour {2}).
_farci_suite_arg() {
  local texte="$1" n="$2" valeur="$3" defaut
  [[ "$n" == 1 ]] && defaut=dossier || defaut=valeur
  if [[ -n "$valeur" && "$valeur" != -* ]]; then
    valeur="${valeur//\\/\\\\}"; valeur="${valeur//&/\\&}"; valeur="${valeur//#/\\#}"
    sed -E "s#\{$n(\|[^}]*)?\}#$valeur#g" <<< "$texte"
  else
    sed -E "s#\{$n\|([^}]*)\}#<\1>#g; s#\{$n\}#<$defaut>#g" <<< "$texte"
  fi
}

# farci_suite <clé> <code de sortie> [arguments de la commande…]
farci_suite() {
  local cible="$1" code="$2"; shift 2
  local def="${FARCI_ROOT:-.}/scripts/suite.def"
  case "${FARCI_SUITE:-auto}" in
    0) return 0 ;;
    1) ;;
    *) [[ -t 2 ]] || return 0 ;;
  esac
  [[ -r "$def" ]] || return 0
  (( code == 130 || code == 143 )) && return 0   # Ctrl+C, arrêt demandé
  local arg equipe="${FARCI_EQUIPE:-}" prev=""
  for arg in "$@"; do
    [[ "$arg" == -h || "$arg" == --help ]] && return 0
    [[ "$prev" == --equipe ]] && equipe="$arg"
    prev="$arg"
  done

  # Clés essayées, de la plus précise à la plus générale :
  #   « up 02-inference/ollama », « up 02-inference », puis « up ».
  local a1="${1:-}" a2="${2:-}" p
  a1="${a1#./}"; a1="${a1%/}"
  local -a keys=()
  if [[ -n "$a1" ]]; then
    p="$a1"
    while [[ -n "$p" ]]; do
      keys+=("$cible $p")
      if [[ "$p" == */* ]]; then p="${p%/*}"; else p=""; fi
    done
  fi
  keys+=("$cible")

  local quand=ok key lignes=""
  (( code == 0 )) || quand=echec
  for key in "${keys[@]}"; do
    lignes="$(awk -F'\t' -v k="$key" -v q="$quand" \
      '$1 !~ /^#/ && NF >= 4 && $1 == k && ($2 == q || $2 == "tout")' "$def")"
    [[ -n "$lignes" ]] && break
  done
  [[ -n "$lignes" ]] || return 0

  local titre="Ensuite :"
  [[ "$quand" == echec ]] && titre="Pour comprendre et réparer :"
  printf '\n%s➜ %s%s\n' "$C_BOLD" "$titre" "$C_RESET" >&2
  local cmd pourquoi
  while IFS=$'\t' read -r _ _ cmd pourquoi; do
    cmd="$(_farci_suite_arg "$cmd" 1 "$a1")"
    cmd="$(_farci_suite_arg "$cmd" 2 "$a2")"
    cmd="${cmd//\{equipe\}/${equipe:-<équipe>}}"
    cmd="${cmd//\{salle\}/${REFERENCE_IP:-<IP du Pi>}}"
    pourquoi="${pourquoi//\{equipe\}/${equipe:-<équipe>}}"
    pourquoi="${pourquoi//\{salle\}/${REFERENCE_IP:-<IP du Pi>}}"
    # Alignement à la main : printf compte les octets, pas les lettres (é).
    if (( ${#cmd} <= 42 )); then
      printf '  %s%*s %s%s%s\n' "$cmd" "$(( 42 - ${#cmd} ))" "" "$C_DIM" "$pourquoi" "$C_RESET" >&2
    else
      printf '  %s\n  %42s %s%s%s\n' "$cmd" "" "$C_DIM" "$pourquoi" "$C_RESET" >&2
    fi
  done <<< "$lignes"
  return 0
}
