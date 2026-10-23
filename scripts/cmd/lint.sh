#!/usr/bin/env bash
# FARCI — contrôles de qualité du dépôt (FARCI §5, §6, §12, §45, §52, §53)
#
#   ./bin/farci lint                  tous les contrôles
#   ./bin/farci lint --only ips docs  une sélection
#     contrôles : versions ips todo docs commands offline shell python size
#   ./bin/farci lint --quiet          seulement les erreurs
#
# Code de sortie : 0 si aucun contrôle n'a échoué (les avertissements
# n'échouent pas), 1 sinon. C'est ce code que la CI et la PR utilisent.
#
# Un contrôle qui ne peut pas s'exécuter (outil absent, étape non encore
# écrite) est marqué SKIP : c'est une première classe de résultat, pas un
# échec. Un atelier multi-étapes ne doit pas être rouge parce qu'une équipe
# n'a pas encore livré son service.
#
# Règle appliquée par tous les contrôles : un contrôle s'exclut lui-même.
# Un contrôle qui traque le mot « TODO » contient forcément « TODO » ; un
# contrôle qui traque une adresse contient forcément une adresse d'exemple.
# Les fichiers de test sont donc hors du champ de l'interlocuteur.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

ONLY=()
QUIET=0
ARGS_ONLY=()

# Chaque branche doit consumER exactement les arguments qu'elle analyse, sinon
# la boucle reboucle indéfiniment sur le même "$1" (piège rencontré en développement).
while (( $# > 0 )); do
  case "$1" in
    --only)
      shift
      while (( $# > 0 )) && [[ "$1" != --* ]]; do
        ARGS_ONLY+=("$1"); shift
      done
      if (( ${#ARGS_ONLY[@]} == 0 )); then
        die "--only attend au moins un contrôle (voir --help)"
      fi
      ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *)         die "option inconnue : $1 (voir --help)" ;;
  esac
done

# Plusieurs cibles partagent ce script (lint, lint-versions, lint-ips...) : le
# nom de la cible sélectionne le contrôle. C'est ce qui fait que
# `make lint-ips` ne lance QUE le controle ips, et non toute la batterie.
# Un --only explicite l'emporte toujours sur le nom de la cible.
if (( ${#ARGS_ONLY[@]} > 0 )); then
  ONLY=("${ARGS_ONLY[@]}")
elif [[ "${FARCI_TARGET:-lint}" == lint-* ]]; then
  ONLY=("${FARCI_TARGET#lint-}")
elif [[ "${FARCI_TARGET:-lint}" != "lint" ]]; then
  die "ce script ne connaît pas la cible \"$FARCI_TARGET\" (voir scripts/targets.def)"
fi

ERRORS=0
WARNINGS=0
SKIPS=0
declare -a REPORT=()

wanted() {
  (( ${#ONLY[@]} == 0 )) && return 0
  local check="$1" want
  for want in "${ONLY[@]}"; do
    [[ "$want" == "$check" ]] && return 0
  done
  return 1
}

record() {
  local status="$1" check="$2" message="$3"
  case "$status" in
    PASS) ;;
    FAIL) ERRORS=$(( ERRORS + 1 )) ;;
    WARN) WARNINGS=$(( WARNINGS + 1 )) ;;
    SKIP) SKIPS=$(( SKIPS + 1 )) ;;
  esac
  REPORT+=("$(printf '%-5s %-14s %s' "$status" "$check" "$message")")
  case "$status" in
    FAIL) err "$check : $message" ;;
    WARN) warn "$check : $message" ;;
    SKIP) [[ $QUIET -eq 0 ]] && warn "$check : $message" ;;
  esac
}

# Fichiers à exclure de toute analyse de contenu.
EXCLUDE_DIRS=(.git .venv node_modules offline __pycache__ .pytest_cache .chaos)
is_excluded() {
  local path="$1" dir
  path="${path#./}"
  for dir in "${EXCLUDE_DIRS[@]}"; do
    [[ "$path" == "$dir"/* || "$path" == "$dir" ]] && return 0
  done
  return 1
}

# Liste les fichiers à analyser : versionnés ET nouveaux non ignorés.
# (--others --exclude-standard : on prend les fichiers en cours d'écriture,
#  mais on respectera .gitignore, donc jamais les secrets ni offline/.)
tracked_files() {
  if farci_in_repo && git -C "$FARCI_ROOT" ls-files >/dev/null 2>&1; then
    git -C "$FARCI_ROOT" ls-files --cached --others --exclude-standard
  else
    find . -type f -not -path './.git/*' | sed 's|^\./||'
  fi
}

# Le filtre code_lines (qui retire commentaires et docstrings) est défini dans
# scripts/lib/common.sh : il est utilisé ici ET testé par selftest, donc il ne
# doit exister qu'en un seul endroit.

# ---------------------------------------------------------------------------
# 1. versions — aucun tag flottant
# ---------------------------------------------------------------------------
if wanted versions; then
  bad=0
  if [[ ! -r "$FARCI_ROOT/versions.env" ]]; then
    record FAIL versions "versions.env introuvable"
  else
    while IFS= read -r line; do
      [[ "$line" == \#* || -z "$line" ]] && continue
      key="${line%%=*}"; value="${line#*=}"
      [[ "$value" =~ (^|[-:_])(latest|main|master|nightly|edge|dev|stable)$ ]] \
        && { record FAIL versions "$key=$value utilise un tag flottant (FARCI §6)"; bad=1; }
    done < "$FARCI_ROOT/versions.env"
    (( bad )) || record PASS versions "aucun tag flottant dans versions.env"
  fi
  if [[ ! -r "$FARCI_ROOT/versions.lock.env" ]]; then
    record WARN versions "versions.lock.env absent : empreintes non figées (attendu en phase 1)"
  else
    record PASS versions "versions.lock.env présent"
  fi
  # Aucune version ne doit être écrite en dur ailleurs que dans versions.env.
  stray="$(tracked_files | grep -E '\.(ya?ml|env|toml|json)$' \
            | grep -v '^versions' \
            | xargs -r grep -nE '(:|-)[0-9]+\.[0-9]+(\.[0-9]+)?(-alpine)?' 2>/dev/null \
            | grep -vE 'schema_version|version: (1|2|3)$' | head -5 || true)"
  if [[ -n "$stray" ]]; then
    record WARN versions "des versions semblent écrites hors versions.env :"
    printf '%s\n' "$stray" | sed 's/^/        /' >&2
  fi
fi

# ---------------------------------------------------------------------------
# 2. ips — aucune adresse en dur hors configuration (FARCI §4)
# ---------------------------------------------------------------------------
if wanted ips; then
  # config/ est le seul endroit autorisé à contenir des adresses réelles, et
  # la documentation a le droit de citer des exemples.
  # Attention : code_lines est une fonction bash, on ne peut pas la passer
  # à xargs — il faut une boucle.
  # selftest.sh est exclu : il contient forcément les adresses qu'il vérifie
  # (comme lint.sh contient forcément le mot TODO qu'il traque).
  offenders="$(cd "$FARCI_ROOT" && {
    while IFS= read -r file; do
      code_lines "$file"
    done < <(tracked_files \
      | grep -vE '^(config/|docs/|.*\.md$)' \
      | grep -E '\.(py|sh|ya?ml|json|toml|env|def|ini|conf|example)$|(^|/)(Caddyfile|Modelfile|Dockerfile)$' \
      | grep -v '^scripts/cmd/selftest\.sh$')
  } | grep -E '\b(192\.168\.[0-9]{1,3}\.[0-9]{1,3})\b' || true)"
  if [[ -n "$offenders" ]]; then
    record FAIL ips "$(printf '%s\n' "$offenders" | wc -l | tr -d ' ') adresse(s) en dur hors config/ :"
    printf '%s\n' "$offenders" | head -40 | sed 's/^/        /' >&2
    record FAIL ips "déplacer l'adresse dans config/network.env et utiliser \${VAR}"
  else
    record PASS ips "aucune adresse en dur hors config/ et documentation"
  fi
  # services.yaml ne doit référencer que des NOMS de variables.
  if [[ -r "$FARCI_ROOT/config/services.yaml" ]]; then
    if grep -qE '\b(192\.168\.|10\.[0-9]+\.|172\.(1[6-9]|2[0-9]|3[01])\.)' "$FARCI_ROOT/config/services.yaml"; then
      record FAIL ips "config/services.yaml contient une adresse : il ne doit référencer que des noms de variables"
    else
      record PASS ips "config/services.yaml ne contient que des noms de variables"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 3. todo — ni TODO ni stub livré (FARCI §60 : dépôt fonctionnel)
# ---------------------------------------------------------------------------
if wanted todo; then
  # Deux régimes, parce qu'un contrôle qui se détecte lui-même ne sert à rien :
  #  - dans le CODE, un TODO en milieu de ligne est un vrai marqueur ;
  #  - dans la DOCUMENTATION, seul un marqueur en début de ligne compte, car
  #    les documents *parlent* de TODO pour l'interdire.
  # scripts/cmd/lint.sh est exclu : il contient forcément le motif recherché.
  todo_code="$(tracked_files \
    | grep -E '\.(py|sh|ya?ml)$' \
    | grep -v '^scripts/cmd/lint\.sh$' \
    | xargs -r grep -nIE '\b(TODO|FIXME|XXX|HACK)\b|not implemented' 2>/dev/null || true)"
  todo_docs="$(tracked_files \
    | grep -E '\.(md|def|txt|example)$' \
    | xargs -r grep -nIE '^[[:space:]]*(#[[:space:]]*)?(TODO|FIXME|XXX)\b' 2>/dev/null || true)"

  if [[ -n "$todo_code" ]]; then
    record FAIL todo "marqueurs de travail non résolus dans le code :"
    printf '%s\n' "$todo_code" | head -10 | sed 's/^/        /' >&2
  elif [[ -n "$todo_docs" ]]; then
    record FAIL todo "marqueurs de travail non résolus dans la documentation :"
    printf '%s\n' "$todo_docs" | head -10 | sed 's/^/        /' >&2
  else
    record PASS todo "aucun marqueur de travail dans le dépôt"
  fi
fi

# ---------------------------------------------------------------------------
# 4. docs — documentation conforme (FARCI §44, §45)
# ---------------------------------------------------------------------------
if wanted docs; then
  missing=()
  for f in README.md CONTRIBUTING.md CHANGELOG.md docs/ARCHITECTURE.md \
           docs/WORKSHOP_FLOW.md docs/AIRGAP.md docs/CONTRACTS.md \
           docs/CHAOS.md docs/INSTRUCTOR_GUIDE.md \
           docs/_templates/TUTORIAL.template.md; do
    [[ -r "$FARCI_ROOT/$f" ]] || missing+=("$f")
  done
  if (( ${#missing[@]} )); then
    record FAIL docs "fichiers de documentation manquants : ${missing[*]}"
  else
    record PASS docs "les 9 fichiers de documentation requis existent"
  fi

  # Les 14 sections imposées par FARCI §45.
  TEMPLATE="$FARCI_ROOT/docs/_templates/TUTORIAL.template.md"
  if [[ -r "$TEMPLATE" ]]; then
    mapfile -t REQUIRED_SECTIONS < <(grep -E '^# ' "$TEMPLATE" | sed 's/^# //')
    if (( ${#REQUIRED_SECTIONS[@]} < 14 )); then
      record FAIL docs "le gabarit TUTORIAL ne contient que ${#REQUIRED_SECTIONS[@]} sections sur 14"
    else
      bad=0
      while IFS= read -r f; do
        for section in "${REQUIRED_SECTIONS[@]}"; do
          grep -qF "# $section" "$f" 2>/dev/null || {
            record FAIL docs "${f#"$FARCI_ROOT"/} : section manquante « $section »"
            bad=1
          }
        done
      done < <(find "$FARCI_ROOT" -name TUTORIAL.md -not -path '*/.git/*' | sort)
      # §45 impose 14 sections ; le gabarit en ajoute une, « Dépannage », utile
      # en atelier mais qui n'est pas une exigence du cahier des charges.
      (( bad )) || record PASS docs "$(find "$FARCI_ROOT" -name TUTORIAL.md -not -path '*/.git/*' | wc -l | tr -d ' ') TUTORIAL conformes (14 sections §45 + Dépannage)"
    fi
  else
    record SKIP docs "gabarit TUTORIAL absent"
  fi

  # Le README doit commencer par le schéma des 3 étapes (FARCI §44).
  if [[ -r "$FARCI_ROOT/README.md" ]]; then
    if head -60 "$FARCI_ROOT/README.md" | grep -q 'ÉTAPE 1'; then
      record PASS docs "README : le schéma des 3 étapes est en tête"
    else
      record FAIL docs "README : le schéma ÉTAPE 1/2/3 doit figurer en tête (FARCI §44)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4 bis. commands — la doc ne cite que des commandes et fichiers existants
# ---------------------------------------------------------------------------
if wanted commands; then
  cmd_out="$(python3 "$FARCI_ROOT/scripts/check_commands.py" 2>&1)"
  if [[ -n "$cmd_out" ]]; then
    record FAIL commands "$(printf '%s\n' "$cmd_out" | wc -l | tr -d ' ') commande(s) ou fichier(s) cités mais inexistants :"
    printf '%s\n' "$cmd_out" | head -40 | sed 's/^/        /' >&2
  else
    record PASS commands "toutes les commandes citées par la documentation existent"
  fi
fi

# ---------------------------------------------------------------------------
# 5. offline — politique air-gap (FARCI §52)
# ---------------------------------------------------------------------------
if wanted offline; then
  # Pas de CDN, pas de police distante, pas de script distant dans les applis.
  cdn="$(find "$FARCI_ROOT/07-applications" -type f \
         \( -name '*.html' -o -name '*.js' -o -name '*.css' -o -name '*.py' \) 2>/dev/null \
         | xargs -r grep -nIE 'https?://(?!192\.168\.|localhost|127\.0\.0\.1)[a-z0-9.-]+' 2>/dev/null \
         | grep -vE '\.(md|json):' || true)"
  if [[ -n "$cdn" ]]; then
    record FAIL offline "référence distante détectable dans 07-applications :"
    printf '%s\n' "$cdn" | head -10 | sed 's/^/        /' >&2
  else
    record PASS offline "aucune ressource distante dans 07-applications (absente ou propre)"
  fi

  # Aucun compose ne doit forcer un téléchargement au démarrage.
  pull_violations="$(find "$FARCI_ROOT" -name 'docker-compose.y*ml' -not -path '*/.git/*' 2>/dev/null \
                     | xargs -r grep -nE 'pull_policy:\s*(always|missing)|^\s*build:\s*https?://' 2>/dev/null || true)"
  if [[ -n "$pull_violations" ]]; then
    record FAIL offline "un compose peut déclencher un téléchargement (FARCI §52) :"
    printf '%s\n' "$pull_violations" | sed 's/^/        /' >&2
  else
    record PASS offline "aucun compose ne force de téléchargement"
  fi

  # Les secrets ne doivent pas être versionnés.
  if farci_in_repo; then
    if git -C "$FARCI_ROOT" ls-files --error-unmatch .env config/network.env \
         >/dev/null 2>&1; then
      record FAIL secrets ".env ou config/network.env est versionné (FARCI §53)"
    else
      record PASS secrets "ni .env ni config/network.env ne sont versionnés"
    fi
  else
    record SKIP secrets "pas de dépôt git initialisé"
  fi

  # offline/ doit être un lien symbolique hors du dépôt, jamais un dossier
  # réel : c'est ce qui garantit qu'aucun poids n'entre dans l'historique.
  if [[ -L "$FARCI_ROOT/offline" ]]; then
    target="$(readlink -f "$FARCI_ROOT/offline" 2>/dev/null || echo '?')"
    case "$target" in
      "$FARCI_ROOT"*) record FAIL offline "offline pointe à l'intérieur du dépôt : $target" ;;
      *)              record PASS offline "offline est un lien hors dépôt (-> $target)" ;;
    esac
  elif [[ -d "$FARCI_ROOT/offline" ]]; then
    record FAIL offline "offline/ est un vrai dossier : il doit être un lien symbolique (./bin/farci bootstrap)"
  else
    record PASS offline "offline/ pas encore créé (./bin/farci bootstrap s'en charge)"
  fi
fi

# ---------------------------------------------------------------------------
# 6. shell — syntaxe, et shellcheck s'il est présent
# ---------------------------------------------------------------------------
if wanted shell; then
  syntax_errors=0
  while IFS= read -r f; do
    bash -n "$FARCI_ROOT/$f" 2>/tmp/farci-bashn || {
      record FAIL shell "erreur de syntaxe bash : $f"
      sed 's/^/        /' /tmp/farci-bashn >&2
      syntax_errors=1
    }
  done < <(tracked_files | grep -E '\.sh$')
  (( syntax_errors )) || record PASS shell "syntaxe bash correcte"

  # Les scripts doivent être exécutables ET porter un shebang.
  not_exec="$(tracked_files | grep -E '\.sh$' \
              | while IFS= read -r f; do
                  [[ -x "$FARCI_ROOT/$f" ]] || printf '%s ' "$f"
                done)"
  if [[ -n "${not_exec// /}" ]]; then
    record FAIL shell "scripts non exécutables : $not_exec"
  else
    record PASS shell "tous les scripts .sh sont exécutables"
  fi

  if have shellcheck; then
    sc_out="$(find "$FARCI_ROOT" -name '*.sh' -not -path '*/.git/*' -print0 \
              | xargs -0 shellcheck -S warning -f gcc 2>&1 | grep -v 'SC1091' || true)"
    if [[ -n "$sc_out" ]]; then
      record WARN shell "shellcheck signale des points à revoir :"
      printf '%s\n' "$sc_out" | head -15 | sed 's/^/        /' >&2
    else
      record PASS shell "shellcheck : aucun avertissement"
    fi
  else
    record SKIP shell "shellcheck absent (recommandé : ./preload.sh --only tools)"
  fi
fi

# ---------------------------------------------------------------------------
# 7. python — compilation de tous les .py
# ---------------------------------------------------------------------------
if wanted python; then
  if ! have python3; then
    record SKIP python "python3 absent"
  else
    # Seuls les répertoires qui existent : les équipes n'ont pas toutes livré
    # leur code, et ce n'est pas une raison de mettre le dépôt en rouge.
    py_dirs=()
    for d in scripts datasets 04-clinical-documents 06-evaluation 07-applications tests; do
      [[ -d "$FARCI_ROOT/$d" ]] && py_dirs+=("$FARCI_ROOT/$d")
    done
    py_out="$(python3 -m compileall -q "${py_dirs[@]}" 2>&1 | head -10 || true)"
    if [[ -n "$py_out" ]]; then
      record FAIL python "erreur de compilation Python :"
      printf '%s\n' "$py_out" | sed 's/^/        /' >&2
    else
      record PASS python "tous les modules Python compilent (${#py_dirs[@]} répertoire(s))"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 8. taille — le dépôt reste léger (contrainte du plan §0.1)
# ---------------------------------------------------------------------------
if wanted size; then
  big="$(find "$FARCI_ROOT" -type f -not -path '*/.git/*' -not -path '*/.venv/*' -not -path '*/eds-nlp/vendor/*' -size +1M \
         -printf '%s %p\n' 2>/dev/null | sort -rn | head -5 || true)"
  if [[ -n "$big" ]]; then
    record WARN size "fichiers volumineux dans l'arbre de travail :"
    printf '%s\n' "$big" | awk '{printf "        %.1f Mo %s\n", $1/1048576, $2}' >&2
  else
    record PASS size "aucun fichier de plus de 1 Mo dans l'arbre"
  fi
  if farci_in_repo; then
    repo_size="$(du -sh "$FARCI_ROOT/.git" 2>/dev/null | cut -f1)"
    [[ -n "$repo_size" ]] && record PASS size "taille du dépôt git : $repo_size"
  fi
fi

# ---------------------------------------------------------------------------
# Synthèse
# ---------------------------------------------------------------------------
if (( ${#ONLY[@]} == 0 )); then
  section "résumé du lint"
  if (( QUIET == 0 )); then
    printf '%s\n' "${REPORT[@]}"
    printf '\n'
  fi
  printf '  %d erreur(s), %d avertissement(s), %d contrôle(s) ignoré(s)\n' \
    "$ERRORS" "$WARNINGS" "$SKIPS"
fi

if (( ERRORS > 0 )); then
  err "le dépôt ne passe pas le lint ($ERRORS erreur(s))"
  exit 1
fi
ok "lint passé"
exit 0
