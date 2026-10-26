#!/usr/bin/env bash
# FARCI — ./bin/farci partage : ce que le Pi distribue aux étudiants arrivés sans rien
#
#   ./bin/farci partage                       état du partage et adresses
#   ./bin/farci partage maj                   publie CE dépôt : farci.git (clonable),
#                                             farci.tar.gz, farci.zip, network.env
#   ./bin/farci partage wheels                AVEC Internet (préparation) : wheels
#                                             Python pour les postes étudiants
#                                             (Linux/WSL, Mac ; versions.env)
#   ./bin/farci partage offline-x86 <dossier> copie un offline/ préparé sur une
#                                             machine x86 (images des briques)
#
# Servi par l'accueil de la salle (Caddy, aucun service en plus) :
#   git clone http://<Pi>/farci.git farci     le dépôt (protocole HTTP « simple »)
#   http://<Pi>/partage/                      archives, network.env, wheels/,
#                                             offline-x86/
#   http://<Pi>/partage/offline-arm64/        l'offline/ du Pi lui-même (Mac Apple Silicon)
#   http://<Pi>/rejoindre                     la marche à suivre, pour l'étudiant
#
# Le Pi est arm64 : ses images ne servent pas aux portables x86. Pour eux,
# préparer offline/ sur une machine x86 avec Internet (./preload.sh --core),
# puis le copier ici avec `partage offline-x86`. Les wheels, elles, se
# téléchargent depuis le Pi pour toutes les plateformes (pip download --platform).

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

farci_load_env
SHARE="$FARCI_DATA_DIR/partage"
HOST="${REFERENCE_IP:-<REFERENCE_IP>}"
[[ "${ENTRY_PORT:-80}" == "80" ]] || HOST="$HOST:$ENTRY_PORT"

# network.env pour un poste étudiant : l'adresse du Pi et les ports, aucune IP
# d'équipe (seul le Pi les connaît).
student_network_env() {
  local src="$FARCI_ROOT/config/network.env"
  [[ -r "$src" ]] || src="$src.example"
  sed -E '/^REFERENCE_IP=|^FARCI_SUBNET=/!s/^([A-Z0-9_]+_IP)=.*/\1=/' "$src"
}

cmd_maj() {
  need git
  mkdir -p "$SHARE"
  local bare="$SHARE/farci.git" rev
  [[ -d "$bare" ]] || git init -q --bare "$bare"
  rev="$(git -C "$FARCI_ROOT" rev-parse --short HEAD)"
  # Une copie dérivée : on la remplace toujours par la version de ce dépôt.
  git -C "$bare" fetch -q --force "$FARCI_ROOT" HEAD:refs/heads/main
  git -C "$bare" symbolic-ref HEAD refs/heads/main
  git -C "$bare" gc -q --prune=now
  git -C "$bare" update-server-info
  git -C "$FARCI_ROOT" archive --format=tar.gz --prefix=farci/ -o "$SHARE/farci.tar.gz" HEAD
  git -C "$FARCI_ROOT" archive --format=zip --prefix=farci/ -o "$SHARE/farci.zip" HEAD
  student_network_env > "$SHARE/network.env"
  printf 'FARCI — partage de la salle\nversion : %s (%s)\npublié : %s\n' \
    "$rev" "$(git -C "$FARCI_ROOT" log -1 --format=%s)" "$(date '+%Y-%m-%d %H:%M')" > "$SHARE/VERSION.txt"
  ok "publié : version $rev"
  cmd_etat
}

cmd_wheels() {
  need python3
  farci_load_versions
  local dest="$SHARE/wheels" os arch tag py n=0 failed=0
  local -a tags pythons platforms
  IFS=, read -ra pythons <<< "${PARTAGE_PYTHONS:?PARTAGE_PYTHONS manquant (versions.env)}"
  IFS=, read -ra platforms <<< "${PARTAGE_PLATEFORMES:?PARTAGE_PLATEFORMES manquant (versions.env)}"
  mkdir -p "$dest"
  # pip ne prend qu'UNE wheel par paquet et par appel : un appel par famille
  # (système × processeur), avec toutes ses étiquettes compatibles.
  for os in manylinux macosx; do
    for arch in x86_64 aarch64 arm64; do
      tags=()
      for tag in "${platforms[@]}"; do
        [[ "$tag" == "$os"* && "$tag" == *"_$arch" ]] && tags+=(--platform "$tag")
      done
      (( ${#tags[@]} )) || continue
      for py in "${pythons[@]}"; do
        info "wheels $os $arch, Python $py…"
        if python3 -m pip download -q --dest "$dest" --only-binary=:all: --implementation cp \
             --python-version "$py" "${tags[@]}" -r "$FARCI_ROOT/requirements.in"; then
          n=$(( n + 1 ))
        else
          warn "échec : $os $arch, Python $py (Internet ? versions.env ?)"; failed=1
        fi
      done
    done
  done
  ok "wheels partagées : $n combinaison(s), $(du -sh "$dest" | cut -f1)"
  return "$failed"
}

cmd_offline_x86() {
  local src="${1:?usage : ./bin/farci partage offline-x86 <dossier offline préparé sur une machine x86>}"
  [[ -d "$src/images" || -d "$src/wheels" ]] || die "$src ne ressemble pas à un dossier offline/ (images/, wheels/, models/)"
  mkdir -p "$SHARE/offline-x86"
  info "copie de $src vers $SHARE/offline-x86 (plusieurs Go : quelques minutes)…"
  cp -a "$src"/. "$SHARE/offline-x86"/
  ok "offline x86 partagé : $(du -sh "$SHARE/offline-x86" | cut -f1)"
}

cmd_etat() {
  section "Partage de la salle"
  if [[ -f "$SHARE/VERSION.txt" ]]; then
    sed -n 2p "$SHARE/VERSION.txt" | sed 's/^/  /'
  else
    warn "rien de publié : ./bin/farci partage maj"
  fi
  local x86="absent (./bin/farci partage offline-x86 <dossier>)" arm="absent"
  local wheels="absent (./bin/farci partage wheels, avec Internet)"
  compgen -G "$SHARE/wheels/*.whl" >/dev/null && wheels="$(du -sh "$SHARE/wheels" | cut -f1)"
  printf '  wheels Python (tous postes) : %s\n' "$wheels"
  [[ -d "$SHARE/offline-x86" ]] && x86="$(du -sh "$SHARE/offline-x86" 2>/dev/null | cut -f1)"
  [[ -d "$FARCI_DATA_DIR/offline/images" ]] && arm="$(du -sh "$FARCI_DATA_DIR/offline" 2>/dev/null | cut -f1)"
  printf '  offline x86 (PC Intel/AMD) : %s\n' "$x86"
  printf '  offline arm64 (Pi, Mac Apple Silicon) : %s\n\n' "$arm"
  printf '  Pour l'"'"'étudiant :  http://%s/rejoindre\n' "$HOST"
  printf '  Cloner :           git clone http://%s/farci.git farci\n' "$HOST"
  printf '  Fichiers :         http://%s/partage/\n' "$HOST"
}

case "${1:-}" in
  "")           cmd_etat ;;
  maj)          cmd_maj ;;
  wheels)       cmd_wheels ;;
  offline-x86)  shift; cmd_offline_x86 "$@" ;;
  -h|--help)    usage ;;
  *)            err "commande inconnue : $1"; usage >&2; exit 64 ;;
esac
