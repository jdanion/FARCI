#!/usr/bin/env bash
# FARCI — verrouillage et téléchargement des dépendances Python.
#
# QUAND L'EXÉCUTER : une seule fois, AVANT le workshop, avec Internet.
# CE QUE ÇA FAIT :
#   1. résout requirements.in en un requirements.txt entièrement épinglé
#      (dépendances transitives comprises) ;
#   2. télécharge les paquets dans offline/wheels/ ;
#   3. calcule les empreintes SHA256, ajoutées à offline/MANIFEST.sha256.
#
# PENDANT LE WORKSHOP, on n'installe plus rien :
#   pip install --no-index --find-links=offline/wheels -r requirements.txt
#
# OPTIONS :
#   --dry-run    afficher ce qui serait fait, ne rien écrire
#   --resolve    seulement produire requirements.txt (pas de téléchargement)
#   --wheels     seulement télécharger les paquets
#
# Note : le verrouillage complet avec empreintes passe par pip-tools, qui est
# lui-même une dépendance. Sans réseau, cette étape est impossible : c'est
# précisément pourquoi elle fait partie du préchargement.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

MODE="all"
for arg in "$@"; do
  case "$arg" in
    --dry-run)  MODE="dry" ;;
    --resolve)  MODE="resolve" ;;
    --wheels)   MODE="wheels" ;;
    -h|--help)  sed -n '2,18p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *)          die "option inconnue : $arg" ;;
  esac
done

WHEELS_DIR="${FARCI_WHEELS_DIR:-$FARCI_DATA_DIR/offline/wheels}"
LOCK="$FARCI_ROOT/requirements.txt"
INPUT="$FARCI_ROOT/requirements.in"

need_python
[[ -r "$INPUT" ]] || die "requirements.in introuvable"

if [[ "$MODE" == "dry" ]]; then
  # La simulation n'exige aucun outil : c'est un plan, pas une action.
  section "simulation (rien ne sera écrit)"
  printf '  entrée      : %s\n' "$INPUT"
  printf '  verrou      : %s\n' "$LOCK"
  printf '  destination : %s\n' "$WHEELS_DIR"
  printf '  dépendances directes : %s\n' \
    "$(grep -cE '^[a-zA-Z]' "$INPUT" || echo 0)"
  if ! have pip3 && ! have pip; then
    printf '  pip         : %sABSENT — il le faudra pour l'"'"'opération réelle%s\n' \
      "$C_YELLOW" "$C_RESET"
  fi
  if ! have pip-compile; then
    printf '  pip-compile : %sABSENT — sans lui, pas de verrou transitif%s\n' \
      "$C_YELLOW" "$C_RESET"
  fi
  printf '\n'
  info "lancer sans --dry-run pour effectuer réellement le verrouillage"
  exit 0
fi

have pip3 || have pip || die "pip absent — l'installer avec : python3 -m ensurepip --upgrade"

if [[ "$MODE" == "all" || "$MODE" == "resolve" ]]; then
  section "résolution des dépendances"
  if have pip-compile; then
    pip-compile --quiet --output-file "$LOCK" --strip-extras "$INPUT" \
      && ok "requirements.txt verrouillé" \
      || die "échec de pip-compile"
  else
    warn "pip-compile absent — repli sur 'pip install --dry-run'."
    warn "Installer pip-tools AVANT le workshop :  pip install pip-tools"
    warn "Sans pip-tools, requirements.txt ne sera pas figé avec ses"
    warn "dépendances transitives : le mode air-gap sera incomplet."
    if [[ "$MODE" == "resolve" ]]; then
      exit 1
    fi
  fi
fi

if [[ "$MODE" == "all" || "$MODE" == "wheels" ]]; then
  section "téléchargement des paquets"
  mkdir -p "$WHEELS_DIR" || die "impossible de créer $WHEELS_DIR"
  # --only-binary : on ne télécharge que des wheels universels, jamais de code
  # source à compiler le jour J (le jour J, on n'a ni toolchain ni réseau).
  python3 -m pip download \
    --dest "$WHEELS_DIR" \
    --only-binary=:all: \
    -r "${LOCK:-$INPUT}" \
    && ok "$(find "$WHEELS_DIR" -name '*.whl' | wc -l) paquets dans $WHEELS_DIR" \
    || die "téléchargement incomplet — l'installation air-gap échouera"

  section "empreintes"
  ( cd "$WHEELS_DIR" && find . -name '*.whl' -print0 \
      | sort -z | xargs -0 sha256sum ) > "$WHEELS_DIR/SHA256SUMS"
  ok "empreintes écrites dans $WHEELS_DIR/SHA256SUMS"
  info "elles seront reprises par scripts/gen-manifest.sh dans offline/MANIFEST.sha256"
fi

printf '\n'
ok "opération terminée"
