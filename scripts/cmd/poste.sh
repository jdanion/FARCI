#!/usr/bin/env bash
# FARCI — ./bin/farci poste : votre poste dans Git (docs/GIT.md)
#
#   ./bin/farci poste             où j'en suis : dépôt, branche, fiche, et la
#                                 commande git à taper ensuite
#   ./bin/farci poste nouveau     écrit la fiche de CE poste, sur SA branche :
#                                 postes/<nom>.env (matériel constaté, équipe,
#                                 fonction dans le projet)
#   ./bin/farci poste verifier    toutes les fiches sont-elles valides ?
#
# LA RÈGLE : une machine = une branche poste/equipe-<N>-<surnom> = une fiche
# postes/equipe-<N>-<surnom>.env. La fiche est versionnée : elle dit ce que la
# machine est (RAM, GPU) et ce qu'elle fait dans le projet (équipe, runtime).
# Elle est lue par ./bin/farci tant que vous êtes sur cette branche : changer
# de branche, c'est changer de configuration.
#
# Cette commande ne tape AUCUNE commande git à votre place : elle regarde où
# vous en êtes et vous donne la suivante. Le surnom est celui de la MACHINE
# (atlas, pc-salle-3), jamais celui d'une personne ; aucun secret dans une fiche.

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
# shellcheck source=scripts/lib/machine.sh
source "$FARCI_ROOT/scripts/lib/machine.sh"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

NAME_RE='^equipe-([0-8])-[a-z0-9][a-z0-9-]*$'
SESSION_BRANCH="${FARCI_SESSION_BRANCH:-seance}"
GIT=(git -C "$FARCI_ROOT")

in_clone() { "${GIT[@]}" rev-parse --git-dir >/dev/null 2>&1; }
current_branch() { "${GIT[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null || true; }

# Un surnom de machine proposé : le nom d'hôte, en minuscules, sans le domaine.
suggested_nick() {
  local nick
  nick="$( (hostname -s 2>/dev/null || hostname 2>/dev/null || echo poste) \
    | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//; s/-*$//')"
  printf '%s\n' "${nick:-poste}"
}

suggested_branch() { printf 'poste/equipe-%s-%s\n' "${FARCI_EQUIPE:-<N>}" "$(suggested_nick)"; }

# D'où vient un remote : GitHub, la forge Gitea, le Pi (lecture seule) ?
remote_kind() {
  case "$1" in
    *github.com*)        printf 'GitHub : la source de vérité (lecture ; pour écrire, votre fork)' ;;
    */FARCI/farci.git|*/FARCI/farci) printf 'forge Gitea de la salle (lecture et écriture)' ;;
    */farci.git)         printf 'copie servie par le Pi (lecture seule)' ;;
    *)                   printf 'autre dépôt' ;;
  esac
}

# Le remote où pousser : une forge Gitea si le clone en connaît une.
push_remote() {
  local name url
  while read -r name; do
    url="$("${GIT[@]}" remote get-url "$name" 2>/dev/null || true)"
    case "$url" in */FARCI/farci.git|*/FARCI/farci) printf '%s\n' "$name"; return 0 ;; esac
  done < <("${GIT[@]}" remote)
  return 0
}

# Fonction du poste dans le projet, selon son équipe et sa machine.
#   poste_plan <équipe> <grosse|legere>  →  rôle <TAB> runtime principal <TAB> phrase
poste_plan() {
  local equipe="$1" machine="$2"
  case "$equipe" in
    0) printf 'full\t\tforge : Gitea, relecture des Pull Requests\n' ;;
    1) printf 'full\t\tréseau : accueil Caddy et tableau de la salle\n' ;;
    2) if [[ "$machine" == grosse ]]; then
         printf 'inference\tollama\tinférence : Ollama + Ornith-1.5-9B\n'
       else
         printf 'inference\tllamacpp\tinférence : llama.cpp + Qwen3.5-2B\n'
       fi ;;
    3) printf 'gateway\t\tpasserelle LLM : LiteLLM\n' ;;
    4) printf 'client\t\tdocuments cliniques : Docling, EDS-NLP\n' ;;
    5) if [[ "$machine" == grosse ]]; then
         printf 'observability\t\tobservabilité : Phoenix et Langfuse\n'
       else
         printf 'observability\t\tobservabilité : Phoenix\n'
       fi ;;
    6) printf 'client\t\tévaluation : métriques, MLflow\n' ;;
    7) printf 'client\t\tapplications : Open WebUI, parcours Python\n' ;;
    8) printf 'client\t\tagents de supervision\n' ;;
  esac
}

cmd_nouveau() {
  local force=0 branch name equipe machine role runtime fonction file
  [[ "${1:-}" == "--force" ]] && force=1
  in_clone || die "ce dossier n'est pas un clone git (archive ?) : voir docs/GIT.md, « Cloner »"
  branch="$(current_branch)"
  if [[ "$branch" != poste/* ]]; then
    err "vous êtes sur « ${branch:-aucune branche} » : une fiche de poste s'écrit sur SA branche."
    printf '\n  Créez la vôtre, puis relancez :\n    git switch -c %s\n    ./bin/farci poste nouveau\n\n' "$(suggested_branch)"
    printf '  <N> : votre équipe (0 à 8). Le surnom est celui de la machine, pas le vôtre.\n'
    return 1
  fi
  name="${branch#poste/}"
  [[ "$name" =~ $NAME_RE ]] \
    || die "nom de branche inattendu : $branch (attendu : poste/equipe-<0-8>-<surnom en minuscules>) — git branch -m $(suggested_branch)"
  equipe="${BASH_REMATCH[1]}"
  file="$FARCI_ROOT/postes/$name.env"
  [[ ! -e "$file" || "$force" == 1 ]] \
    || die "postes/$name.env existe déjà : modifiez-le à la main (ou --force pour le réécrire)"

  # FARCI_MACHINE ne doit venir que de la machine elle-même, pas d'une fiche.
  machine="$(FARCI_MACHINE="" farci_machine)"
  IFS=$'\t' read -r role runtime fonction < <(poste_plan "$equipe" "$machine")
  mkdir -p "$FARCI_ROOT/postes"
  cat > "$file" <<EOF
# FARCI — fiche de poste : $name
# Branche : poste/$name. Fichier VERSIONNÉ : aucun secret, aucun nom de personne.
# Lu par ./bin/farci tant que vous êtes sur cette branche (docs/GIT.md).

# --- Ce que la machine est (constaté par ./bin/farci poste nouveau) ----------
POSTE_SYSTEME=$(uname -s) $(uname -m)
POSTE_RAM_GO=$(farci_ram_go)
POSTE_GPU=$(farci_gpu)

# --- Ce qu'elle fait dans le projet -------------------------------------------
FARCI_EQUIPE=$equipe
POSTE_FONCTION=$fonction
FARCI_ROLE=$role

# --- À adapter : c'est VOTRE commit -------------------------------------------
# Profil : grosse (GPU NVIDIA ou 32 Go : Ollama + modèle 9B) | legere (llama.cpp + 2B)
FARCI_MACHINE=$machine
FARCI_INFERENCE_PRIMARY=${runtime:-ollama}
# Parcours de l'étape 2 : python | webui
FARCI_TRACK=python
EOF
  ok "fiche écrite : postes/$name.env (équipe $equipe, configuration $machine)"
  info "relisez-la, corrigez ce qui est faux pour votre machine : ce sera votre premier commit"
  cmd_etat
}

# verify_file <fichier>  →  une ligne par problème
verify_file() {
  local file="$1" name key value allowed
  name="$(basename "$file" .env)"
  allowed="$(emit_env_file "$FARCI_ROOT/config/workshop.env.example" | cut -d= -f1)"
  if [[ ! "$name" =~ $NAME_RE ]]; then
    printf 'postes/%s.env : nom attendu equipe-<0-8>-<surnom>.env\n' "$name"
    return 0
  fi
  local equipe="${BASH_REMATCH[1]}"
  while IFS='=' read -r key value; do
    if [[ "$key" =~ (PASSWORD|PASSWD|TOKEN|SECRET|KEY)$ ]]; then
      printf 'postes/%s.env : %s ressemble à un secret (les secrets restent dans .env)\n' "$name" "$key"
    elif [[ "$key" != POSTE_* ]] && ! grep -qx "$key" <<< "$allowed"; then
      printf 'postes/%s.env : %s inconnu (clés admises : POSTE_* et celles de config/workshop.env.example)\n' "$name" "$key"
    fi
    case "$key" in
      FARCI_EQUIPE)
        [[ "$value" == "$equipe" ]] \
          || printf 'postes/%s.env : FARCI_EQUIPE=%s ne correspond pas au nom du fichier (équipe %s)\n' "$name" "$value" "$equipe" ;;
      FARCI_MACHINE)
        [[ "$value" =~ ^(grosse|legere|)$ ]] \
          || printf 'postes/%s.env : FARCI_MACHINE=%s (attendu : grosse | legere)\n' "$name" "$value" ;;
    esac
  done < <(emit_env_file "$file")
}

cmd_verifier() {
  local file problems="" n=0
  for file in "$FARCI_ROOT"/postes/*.env; do
    [[ -e "$file" ]] || continue
    n=$(( n + 1 ))
    problems+="$(verify_file "$file")"$'\n'
  done
  problems="$(sed '/^$/d' <<< "$problems")"
  if [[ -n "$problems" ]]; then
    printf '%s\n' "$problems" >&2
    return 1
  fi
  ok "$n fiche(s) de poste valide(s)"
}

# printf compte des octets : les libellés accentués sont alignés à la main.
row() { printf '  %s%*s %s\n' "$1" "$(( 12 - ${#1} ))" "" "$2"; }
next() { printf '\n  %sÀ taper maintenant :%s\n' "$C_BOLD" "$C_RESET"; printf '    %s\n' "$@"; printf '\n'; }

cmd_etat() {
  local branch name file remote url dirty upstream ahead push_to forge
  section "Votre poste dans Git"
  if ! in_clone; then
    row "dépôt" "ce dossier n'est pas un clone git (archive décompressée)"
    url="${FARCI_GITHUB_URL:-<adresse du dépôt>}"
    [[ -z "${GITEA_URL:-}" ]] || url="$GITEA_URL/FARCI/farci.git"
    next "git clone $url farci" \
         "# docs/GIT.md, « Cloner » : sans clone, pas de branche ni d'historique"
    return 0
  fi
  while read -r remote; do
    url="$("${GIT[@]}" remote get-url "$remote")"
    row "dépôt" "$remote → $url"
    row "" "$(remote_kind "$url")"
  done < <("${GIT[@]}" remote)
  branch="$(current_branch)"
  row "branche" "${branch:-(HEAD détachée)}"

  if [[ -z "$("${GIT[@]}" config user.name || true)" || -z "$("${GIT[@]}" config user.email || true)" ]]; then
    row "identité" "non réglée : git ne sait pas qui signe vos commits"
    next 'git config user.name "equipe-<N>"' 'git config user.email "equipe-<N>@farci.local"' \
         "# le compte de votre équipe sur la forge ; chez vous, votre nom et votre adresse"
    return 0
  fi
  row "identité" "$("${GIT[@]}" config user.name) <$("${GIT[@]}" config user.email)>"

  if [[ "$branch" != poste/* ]]; then
    row "fiche" "aucune : vous êtes sur une branche commune"
    next "git switch -c $(suggested_branch)" \
         "# une branche = votre copie de travail du projet, pour CETTE machine ; main n'est pas touchée"
    return 0
  fi
  name="${branch#poste/}"
  file="postes/$name.env"
  if [[ ! -r "$FARCI_ROOT/$file" ]]; then
    row "fiche" "$file : pas encore écrite"
    next "./bin/farci poste nouveau" "# écrit la fiche de cette machine ; vous la relisez et la corrigez"
    return 0
  fi
  row "fiche" "$file — $(emit_env_file "$FARCI_ROOT/$file" | grep -E '^(FARCI_MACHINE|POSTE_FONCTION)=' | cut -d= -f2- | paste -sd'|' - | sed 's/|/ ; /' || true)"

  dirty="$("${GIT[@]}" status --porcelain | wc -l | tr -d ' ')"
  if (( dirty > 0 )); then
    row "à commiter" "$dirty fichier(s) modifié(s) ou nouveau(x) : git status"
    next "git status" "git add $file" "git commit -m \"poste: $name, ce que j'ai adapté\"" \
         "# un commit = une modification expliquée ; git diff montre ce qui part"
    return 0
  fi
  row "à commiter" "rien : tout est dans l'historique (git log --oneline -5)"

  push_to="$(push_remote)"
  if [[ -z "$push_to" ]]; then
    row "publiée" "non : ce clone ne connaît aucune forge où vous pouvez écrire"
    if [[ -n "${GITEA_URL:-}" ]]; then
      next "git remote add salle $GITEA_URL/FARCI/farci.git" "git push -u salle $branch" \
           "# un remote = un dépôt distant ; « salle » est la forge Gitea, « origin » reste d'où vous avez cloné"
    else
      next "git remote add moi https://github.com/<votre-compte>/FARCI.git" "git push -u moi $branch" \
           "# hors de la salle : forkez ${FARCI_GITHUB_URL:-le dépôt} sur GitHub, poussez sur VOTRE fork"
    fi
    return 0
  fi
  upstream="$("${GIT[@]}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  ahead=0
  [[ -n "$upstream" ]] && ahead="$("${GIT[@]}" rev-list --count '@{upstream}..HEAD')"
  if [[ -z "$upstream" ]] || (( ahead > 0 )); then
    if [[ -n "$upstream" ]]; then
      row "publiée" "$ahead commit(s) à pousser vers $upstream"
    else
      row "publiée" "non : la branche n'existe que sur cette machine"
    fi
    next "git push -u $push_to $branch" "# identifiant : le compte de votre équipe (equipe-<N>), donné par le formateur"
    return 0
  fi
  row "publiée" "oui : $upstream"
  forge="$("${GIT[@]}" remote get-url "$push_to")"; forge="${forge%.git}"
  printf '\n  %sDernière étape, dans le navigateur :%s une Pull Request vers « %s »\n' "$C_BOLD" "$C_RESET" "$SESSION_BRANCH"
  printf '    %s/compare/%s...%s\n' "$forge" "$SESSION_BRANCH" "$branch"
  printf '\n  Pour recevoir le travail des autres :\n    git fetch %s\n    git merge %s/%s\n\n' "$push_to" "$push_to" "$SESSION_BRANCH"
}

farci_load_env
case "${1:-}" in
  "")           cmd_etat ;;
  nouveau)      shift; cmd_nouveau "$@" ;;
  verifier)     cmd_verifier ;;
  -h|--help)    usage ;;
  *)            err "commande inconnue : $1"; usage >&2; exit 64 ;;
esac
