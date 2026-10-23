#!/usr/bin/env bash
# FARCI — ./bin/farci forge-sync : faire descendre main de GitHub vers Gitea
#
#   ./bin/farci forge-sync status            GitHub et Gitea : identiques, en retard, divergents ?
#   ./bin/farci forge-sync push              Gitea main ← GitHub main (avance rapide seulement)
#   ./bin/farci forge-sync bundle <fichier>  emporter GitHub main dans un fichier (clé USB)
#   ./bin/farci forge-sync from-bundle <fichier>   Gitea main ← ce fichier (salle sans Internet)
#   ./bin/farci forge-sync rapatrier <branche>     une branche faite sur Gitea → branche locale,
#                                                  à proposer sur GitHub par une PR
#
# LA RÈGLE : GitHub est la seule source de vérité. Gitea (la forge de la
# salle) reçoit main de GitHub et rien d'autre ; on n'écrit jamais
# directement sur main côté Gitea. Si les deux divergent, on REFUSE : on ne
# force jamais. Le travail fait pendant la séance vit sur des branches Gitea ;
# ce qui mérite d'être gardé remonte vers GitHub par une Pull Request
# (`rapatrier`), puis redescend au prochain `push`.
#
# Remotes : FARCI_SOURCE_REMOTE (défaut origin, GitHub) et FARCI_GITEA_REMOTE
# (défaut gitea, ajouté automatiquement depuis GITEA_URL s'il manque). Le
# premier push crée aussi la branche de séance « seance », cible des PR des
# équipes. main étant protégée sur Gitea, pousser avec le compte farci-admin.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

farci_load_env
need git

SOURCE="${FARCI_SOURCE_REMOTE:-origin}"
GITEA="${FARCI_GITEA_REMOTE:-gitea}"
BRANCH="${FARCI_SYNC_BRANCH:-main}"
SESSION_BRANCH="${FARCI_SESSION_BRANCH:-seance}"
# Le dépôt local qui sert de relais (FARCI_SYNC_REPO : utilisé par les tests).
GIT=(git -C "${FARCI_SYNC_REPO:-$FARCI_ROOT}")

ensure_gitea_remote() {
  "${GIT[@]}" remote get-url "$GITEA" >/dev/null 2>&1 && return 0
  # Le Gitea déclaré (GITEA_IP), sinon celui de CETTE machine.
  local url="${GITEA_URL:-${GITEA_PORT:+http://127.0.0.1:$GITEA_PORT}}"
  [[ -n "$url" ]] \
    || die "remote « $GITEA » absent et Gitea inconnu : git remote add $GITEA <url du dépôt Gitea>"
  "${GIT[@]}" remote add "$GITEA" "$url/FARCI/farci.git"
  ok "remote $GITEA ajouté : $url/FARCI/farci.git"
}

fetch_source() {
  "${GIT[@]}" fetch -q "$SOURCE" "+refs/heads/$BRANCH:refs/remotes/$SOURCE/$BRANCH" \
    || die "impossible de lire $SOURCE/$BRANCH (GitHub joignable ?)"
}

# Chemin absolu (git -C change de répertoire ; realpath -m n'existe pas sur macOS).
abspath() { [[ "$1" == /* ]] && printf '%s\n' "$1" || printf '%s/%s\n' "$PWD" "$1"; }

# Lit main côté Gitea et affiche son sha ; rien si la branche n'existe pas
# encore (dépôt neuf). ensure_gitea_remote doit avoir été appelé avant.
fetch_gitea() {
  "${GIT[@]}" ls-remote "$GITEA" >/dev/null 2>&1 \
    || die "Gitea injoignable : $("${GIT[@]}" remote get-url "$GITEA")"
  if "${GIT[@]}" ls-remote --exit-code --heads "$GITEA" "$BRANCH" >/dev/null 2>&1; then
    "${GIT[@]}" fetch -q "$GITEA" "+refs/heads/$BRANCH:refs/remotes/$GITEA/$BRANCH"
    "${GIT[@]}" rev-parse "refs/remotes/$GITEA/$BRANCH"
  fi
}

# relation <gitea_sha|vide> <source_sha> : identique | retard | avance | divergent | vide
relation() {
  local gitea="$1" source="$2"
  if [[ -z "$gitea" ]]; then echo vide
  elif [[ "$gitea" == "$source" ]]; then echo identique
  elif "${GIT[@]}" merge-base --is-ancestor "$gitea" "$source"; then echo retard
  elif "${GIT[@]}" merge-base --is-ancestor "$source" "$gitea"; then echo avance
  else echo divergent
  fi
}

explain_refusal() {
  local gitea="$1" source="$2"
  err "Gitea $BRANCH contient des commits absents de GitHub : synchronisation REFUSÉE (jamais de force)."
  printf '\n  Commits présents seulement sur Gitea :\n'
  "${GIT[@]}" log --oneline "$source..$gitea" | sed 's/^/    /'
  cat <<EOF

  Pour s'en sortir sans rien perdre :
    1. ./bin/farci forge-sync rapatrier $BRANCH     (copie locale : depuis-gitea/$BRANCH)
    2. pousser cette branche sur GitHub, ouvrir une Pull Request, la fusionner
    3. ./bin/farci forge-sync push               (Gitea rattrape GitHub)
EOF
}

# push_to_gitea <sha> <libellé de la source>
push_to_gitea() {
  local source_sha="$1" label="$2" gitea_sha state
  ensure_gitea_remote
  gitea_sha="$(fetch_gitea)"
  state="$(relation "$gitea_sha" "$source_sha")"
  case "$state" in
    identique) ok "Gitea $BRANCH est déjà à jour ($(short "$source_sha"))"; return 0 ;;
    avance|divergent) explain_refusal "$gitea_sha" "$source_sha"; return 1 ;;
  esac
  # Avance rapide seulement : pas de « + » dans la refspec, git refuse sinon.
  "${GIT[@]}" push -q "$GITEA" "$source_sha:refs/heads/$BRANCH"
  ok "Gitea $BRANCH : $( [[ -n "$gitea_sha" ]] && short "$gitea_sha" || echo '(vide)') → $(short "$source_sha") ($label)"
  # La branche de séance (cible des PR des équipes) est créée une fois, au
  # départ de main ; ensuite elle n'appartient qu'à la séance.
  if ! "${GIT[@]}" ls-remote --exit-code --heads "$GITEA" "$SESSION_BRANCH" >/dev/null 2>&1; then
    "${GIT[@]}" push -q "$GITEA" "$source_sha:refs/heads/$SESSION_BRANCH"
    ok "branche de séance créée sur Gitea : $SESSION_BRANCH"
  fi
}

short() { "${GIT[@]}" rev-parse --short "$1"; }

cmd_status() {
  local source_sha gitea_sha state
  fetch_source
  source_sha="$("${GIT[@]}" rev-parse "refs/remotes/$SOURCE/$BRANCH")"
  ensure_gitea_remote
  gitea_sha="$(fetch_gitea)"
  state="$(relation "$gitea_sha" "$source_sha")"
  printf '  GitHub (%s/%s) : %s\n' "$SOURCE" "$BRANCH" "$(short "$source_sha")"
  printf '  Gitea  (%s/%s) : %s\n' "$GITEA" "$BRANCH" "$( [[ -n "$gitea_sha" ]] && short "$gitea_sha" || echo '(vide)')"
  case "$state" in
    identique) ok "identiques" ;;
    vide)      info "Gitea vide : ./bin/farci forge-sync push" ;;
    retard)    info "Gitea en retard de $("${GIT[@]}" rev-list --count "$gitea_sha..$source_sha") commit(s) : ./bin/farci forge-sync push" ;;
    avance|divergent) explain_refusal "$gitea_sha" "$source_sha"; return 1 ;;
  esac
}

cmd_push() {
  fetch_source
  push_to_gitea "$("${GIT[@]}" rev-parse "refs/remotes/$SOURCE/$BRANCH")" "GitHub"
}

cmd_bundle() {
  local file="${1:?usage : forge-sync bundle <fichier>}"
  fetch_source
  "${GIT[@]}" bundle create -q "$(abspath "$file")" "refs/remotes/$SOURCE/$BRANCH"
  ok "bundle écrit : $file ($(short "refs/remotes/$SOURCE/$BRANCH"), $(du -h "$file" | cut -f1))"
  info "sha256 : $(sha256sum "$file" | cut -d' ' -f1)"
  info "dans la salle : ./bin/farci forge-sync from-bundle $file"
}

cmd_from_bundle() {
  local file="${1:?usage : forge-sync from-bundle <fichier>}" path ref sha
  [[ -r "$file" ]] || die "bundle introuvable : $file"
  path="$(abspath "$file")"
  "${GIT[@]}" bundle verify -q "$path" >/dev/null 2>&1 || die "bundle invalide ou incomplet : $file"
  ref="$("${GIT[@]}" bundle list-heads "$path" | awk -v b="/$BRANCH" '$2 ~ b"$" {print $2; exit}')"
  [[ -n "$ref" ]] || die "le bundle ne contient pas de branche $BRANCH"
  "${GIT[@]}" fetch -q "$path" "+$ref:refs/remotes/bundle/$BRANCH"
  sha="$("${GIT[@]}" rev-parse "refs/remotes/bundle/$BRANCH")"
  push_to_gitea "$sha" "bundle $(basename "$file")"
}

cmd_rapatrier() {
  local branch="${1:?usage : forge-sync rapatrier <branche Gitea>}" local_branch
  ensure_gitea_remote
  local_branch="depuis-gitea/$branch"
  "${GIT[@]}" fetch -q "$GITEA" "+refs/heads/$branch:refs/heads/$local_branch" \
    || die "branche introuvable sur Gitea : $branch"
  ok "branche locale $local_branch créée ($(short "$local_branch"))"
  cat <<EOF

  Pour la faire entrer dans la source de vérité :
    git push $SOURCE $local_branch
    puis ouvrir une Pull Request sur GitHub vers $BRANCH, la relire, la fusionner ;
    enfin ./bin/farci forge-sync push
EOF
}

case "${1:-}" in
  status)      cmd_status ;;
  push)        cmd_push ;;
  bundle)      shift; cmd_bundle "$@" ;;
  from-bundle) shift; cmd_from_bundle "$@" ;;
  rapatrier)   shift; cmd_rapatrier "$@" ;;
  -h|--help|"") usage ;;
  *)           err "commande inconnue : $1"; usage >&2; exit 64 ;;
esac
