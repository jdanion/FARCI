#!/usr/bin/env bash
# FARCI — helpers JSON pour les scripts bash (scripts/lib/json.sh)
#
# Raison d'être : sur une machine air-gapée, `jq` n'est pas garanti. Tous les
# tests et scripts du dépôt utilisent donc ces fonctions, qui s'appuient sur la
# seule stdlib Python 3. Si `jq` est présent, il n'est toujours pas utilisé :
# le comportement doit être identique partout.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "json.sh est une bibliothèque : utilisez 'source scripts/lib/json.sh'" >&2
  exit 64
fi

FARCI_JSONPY="${FARCI_LIB_DIR}/jsonpath.py"

# json_get <chemin> [fichier|-]   -> valeur sur stdout ; retour 1 si absent
json_get() {
  local path="$1" file="${2:--}"
  python3 "$FARCI_JSONPY" get "$path" "$file"
}

# json_has <chemin> [fichier|-]   -> 0 si présent
json_has() {
  local path="$1" file="${2:--}"
  python3 "$FARCI_JSONPY" has "$path" "$file" >/dev/null 2>&1
}

# json_keys [chemin] [fichier|-] -> une clé par ligne
json_keys() {
  local path="${1:-}" file="${2:--}"
  if [[ -n "$path" ]]; then
    python3 "$FARCI_JSONPY" keys "$path" "$file"
  else
    python3 "$FARCI_JSONPY" keys "" "$file"
  fi
}

# json_type <chemin> [fichier|-]  -> null|bool|number|string|array|object
json_type() {
  python3 "$FARCI_JSONPY" type "$1" "${2:--}"
}

# json_valid [fichier|-]          -> 0 si JSON valide
json_valid() {
  python3 "$FARCI_JSONPY" valid "${1:--}" >/dev/null 2>&1
}

# json_norm [fichier|-]           -> JSON compact sur une ligne
json_norm() {
  python3 "$FARCI_JSONPY" norm "${1:--}"
}

# Assertions de test, messages lisibles dans le tableau de make test.
#   assert_json_equals "a.b" "200" "$body" "usage.total_tokens doit valoir 200"
assert_json_equals() {
  local path="$1" expected="$2" file="$3" message="${4:-}"
  local actual
  actual="$(json_get "$path" "$file" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  [[ -n "$message" ]] && err "$message"
  err "  chemin   : $path"
  err "  attendu  : ${expected:-<vide>}"
  err "  obtenu   : ${actual:-<absent>}"
  return 1
}

# assert_json_present <chemin> <fichier|-> <message>
assert_json_present() {
  local path="$1" file="$2" message="${3:-}"
  if json_has "$path" "$file"; then
    return 0
  fi
  [[ -n "$message" ]] && err "$message"
  err "  chemin absent : $path"
  return 1
}

# assert_json_type <chemin> <type> <fichier|-> <message>
assert_json_type() {
  local path="$1" expected="$2" file="$3" message="${4:-}"
  local actual
  actual="$(json_type "$path" "$file" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  [[ -n "$message" ]] && err "$message"
  err "  chemin   : $path — attendu $expected, obtenu ${actual:-<absent>}"
  return 1
}
