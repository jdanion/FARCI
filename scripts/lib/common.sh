#!/usr/bin/env bash
# FARCI — bibliothèque bash commune (scripts/lib/common.sh)
# Ne contient aucune dépendance externe : POSIX + coreutils + python3 stdlib.
# Sourced, jamais exécuté directement.

# Garde-fou : ce fichier doit être sourcé, pas exécuté.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "common.sh est une bibliothèque : utilisez 'source scripts/lib/common.sh'" >&2
  exit 64
fi

# --------------------------------------------------------------------------
# Racine du dépôt
# --------------------------------------------------------------------------
FARCI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FARCI_ROOT="${FARCI_ROOT:-$(cd "$FARCI_LIB_DIR/../.." && pwd)}"
export FARCI_ROOT FARCI_LIB_DIR

# FARCI_DATA_DIR n'a PAS de valeur ici : farci_load_env (scripts/dev-env.sh)
# la lit dans .env, puis applique /srv/farci par défaut. Une valeur posée ici
# passerait pour « déjà dans l'environnement » et masquerait celle de .env.

# Horodatage et couleur ------------------------------------------------------
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
  C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD="" C_DIM=""
else
  C_RESET=$'\033[0m' C_RED=$'\033[31m' C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
fi

FARCI_NOW() { date '+%H:%M:%S'; }

log()    { printf '%s[%s]%s %s\n'        "$C_DIM" "$(FARCI_NOW)" "$C_RESET" "$*"; }
info()   { printf '%s[%s] i %s %s\n'      "$C_DIM" "$(FARCI_NOW)" "$C_RESET" "$*"; }
ok()     { printf '%s[%s] OK%s %s\n'      "$C_GREEN" "$(FARCI_NOW)" "$C_RESET" "$*"; }
warn()   { printf '%s[%s] !!%s %s\n'      "$C_YELLOW" "$(FARCI_NOW)" "$C_RESET" "$*" >&2; }
err()    { printf '%s[%s] ERR%s %s\n'     "$C_RED" "$(FARCI_NOW)" "$C_RESET" "$*" >&2; }
debug()  { [[ -n "${FARCI_DEBUG:-}" ]] && printf '%s[%s] dbg%s %s\n' "$C_DIM" "$(FARCI_NOW)" "$C_RESET" "$*" >&2 || true; }
die()    { err "$*"; exit 1; }

section() {
  printf '\n%s%s%s\n' "$C_BOLD$C_BLUE" "── $* ────────────────────────────────────" "$C_RESET"
}

have() { command -v "$1" >/dev/null 2>&1; }

need() {
  have "$1" || die "commande manquante : $1  ${2:+($2)}"
}

# Pourquoi Docker ne répond pas, et quoi faire : un démon arrêté et un
# utilisateur hors du groupe docker donnent la même erreur à `docker info`.
#   docker_diagnose  → vide si Docker répond, sinon une phrase d'action
docker_diagnose() {
  local out
  have docker || { printf 'Docker n'"'"'est pas installé sur cette machine'; return; }
  out="$(docker info 2>&1 >/dev/null)" && return 0
  case "$out" in
    *"permission denied"*)
      printf 'l'"'"'utilisateur %s n'"'"'a pas accès à Docker : sudo usermod -aG docker %s, puis se déconnecter et se reconnecter (ou : newgrp docker)' "${USER:-$(id -un)}" "${USER:-$(id -un)}" ;;
    *"Cannot connect"*|*"Is the docker daemon running"*|*"No such file"*)
      printf 'le service Docker est arrêté : sudo systemctl enable --now docker (Mac : lancer Docker Desktop)' ;;
    *)
      printf 'Docker ne répond pas : %s' "$(printf '%s' "$out" | head -1)" ;;
  esac
}

need_docker() {
  local why
  why="$(docker_diagnose)"
  [[ -z "$why" ]] || die "$why"
}

need_python() {
  have python3 || die "python3 est requis (>= ${FARCI_MIN_PYTHON:-3.11})"
  python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, ${FARCI_MIN_PYTHON:-11}) else 1)" \
    || die "python3 >= ${FARCI_MIN_PYTHON:-3.11} est requis (trouvé : $(python3 -V 2>&1))"
}

# Exécute une commande N fois, avec pause croissante.
#   retry 3 curl -sSf http://.../health
retry() {
  local tries="$1"; shift
  local attempt=1 delay=1
  while true; do
    if "$@"; then return 0; fi
    (( attempt >= tries )) && return 1
    warn "échec (${attempt}/${tries}) : $* — nouvelle tentative dans ${delay}s"
    sleep "$delay"
    (( delay = delay * 2 )); (( delay > 8 )) && delay=8
    (( attempt++ ))
  done
}

# Code HTTP d'une URL, sans échouer si la connexion est refusée.
#   http_code "$BASE_URL/health"   ->  200 | 000 | 503
http_code() {
  local url="$1" timeout="${2:-3}" code
  # curl écrit déjà « 000 » quand la connexion échoue, PUIS sort en erreur :
  # un « || echo 000 » produirait « 000000 », pris pour une réponse.
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null)" || true
  printf '%s\n' "${code:-000}"
}

# Attend qu'une URL réponde 200.
#   wait_http http://.../health 30 "Docling"
wait_http() {
  local url="$1" timeout="${2:-30}" label="${3:-service}" deadline
  deadline=$(( SECONDS + timeout ))
  debug "wait_http $url (${timeout}s) label=$label"
  while (( SECONDS < deadline )); do
    if [[ "$(http_code "$url" 2)" == "200" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Rendu d'un fichier de dissimulation (.env) vers stdout, sans l'exporter.
# Accepte lessyntaxes : CLE=valeur, export CLE=valeur, # commentaires, "v" ou 'v'
emit_env_file() {
  local file="$1" line key value
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"          # trim gauche
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == export\ * ]] && line="${line#export }"
    [[ "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"             # trim droite
    value="${value#"${value%%[![:space:]]*}"}"
    if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
      value="${value:1:${#value}-2}"
    else
      value="${value%%#*}"                            # commentaire de fin
      value="${value%"${value##*[![:space:]]}"}"
    fi
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    printf '%s=%s\n' "$key" "$value"
  done < "$file"
}

# Charge .env, config/network.env, config/workshop.env puis exporte.
# Uniquement disponible après source scripts/dev-env.sh — ce pointeur
# évite les imports circulaires.
farci_load_env() { :; }

# Liste des fichiers de configuration effectivement présents.
farci_env_files() {
  local f
  for f in "$FARCI_ROOT/.env" \
           "$FARCI_ROOT/config/network.env" \
           "$FARCI_ROOT/config/workshop.env"; do
    [[ -r "$f" ]] && printf '%s\n' "$f"
  done
}

# N'affiche que les LIGNES DE CODE d'un fichier : supprime les lignes de
# commentaire et le contenu des docstrings.
# Pourquoi : un commentaire peut légitimement citer une adresse pour expliquer
# une règle réseau. Ce qu'on traque, c'est une adresse RÉELLEMENT UTILISÉE
# comme valeur par le code.
#   code_lines fichier.py [autre.py …]
code_lines() {
  awk '
    BEGIN { indoc = 0 }
    {
      if (indoc) {
        if (index($0, "\"\"\"") > 0) indoc = 0
        next
      }
      if (index($0, "\"\"\"") > 0) {
        # On retire tout ce qui precede la PREMIERE occurrence de """.
        # Le motif est volontairement NON gourmand ([^"] au lieu de .) : avec un
        # .*, awk matcherait jusqu au DERNIER """ de la ligne, laisserait rest
        # vide, et croirait qu une docstring commence ici. C etait le bug.
        # Si ce qui reste contient encore """, la docstring commence ET finit
        # sur la meme ligne (cas de """Une ligne.""").
        rest = $0
        sub(/^[^\"]*\"\"\"/, "", rest)
        if (index(rest, "\"\"\"") == 0) indoc = 1
        next
      }
      sub(/^[[:space:]]*#.*$/, "")
      sub(/[[:space:]]*#.*$/, "")
      if (length($0) > 0) print FILENAME ":" FNR ":" $0
    }
  ' "$@"
}

# Emplacement de stockage lourd (§0.1 du plan).
farci_data_dir() { printf '%s\n' "${FARCI_DATA_DIR:-/srv/farci}"; }

# Vrai si la machine n'a normalement plus d'accès Internet.
# best-effort : ne jamais échouer, ne jamais bloquer plus de 2s.
farci_is_offline() {
  if [[ "${FARCI_ENFORCE_OFFLINE:-1}" == "1" ]] && have unshare; then
    return 1
  fi
  return 0
}

# Un chemin est-il dans un dépôt git ?
farci_in_repo() { [[ -d "$FARCI_ROOT/.git" ]]; }
