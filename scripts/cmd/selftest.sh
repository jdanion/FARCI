#!/usr/bin/env bash
# FARCI — ./bin/farci selftest
# Auto-tests des briques maison : le parseur YAML restreint et l'accès JSON.
# Ces briques remplacent PyYAML et jq : si elles cassent, tout le dépôt casse,
# donc elles sont testées à chaque appel du lint.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

FAILED=0

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,6p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

section "miniyaml (parseur du registre)"
if python3 "$FARCI_LIB_DIR/miniyaml.py" --selftest; then
  :
else
  FAILED=1
fi

# Le registre réel doit aussi être lisible, sinon plus rien ne fonctionne.
if python3 -c "
import sys, os
sys.path.insert(0, '${FARCI_LIB_DIR}')
from miniyaml import load
data = load('${FARCI_ROOT}/config/services.yaml')
assert isinstance(data.get('services'), list) and data['services'], 'liste services vide'
for s in data['services']:
    for champ in ('id', 'label', 'group', 'ip_var', 'port_var', 'health_paths', 'tier'):
        assert champ in s, f\"service {s.get('id')}: champ {champ} manquant\"
    assert isinstance(s['health_paths'], list) and s['health_paths'], f\"{s['id']}: health_paths vide\"
print(f\"registre : {len(data['services'])} services, {len(data.get('groups', {}))} groupes, \"
      f\"{len(data.get('status_rows', []))} lignes de statut — OK\")
" 2>&1; then
  :
else
  err "le registre config/services.yaml ne respecte pas le format attendu"
  FAILED=1
fi

if FARCI_ROOT="$FARCI_ROOT" python3 "$FARCI_ROOT/scripts/services.py" validate; then
  :
else
  err "config/services.yaml : tier, critique ou lignes du tableau incohérents"
  FAILED=1
fi

section "jsonpath (remplace jq)"
json_selftest() {
  local failures=0
  local sample='{"choices":[{"message":{"content":"{\"ok\":true}"},"finish_reason":"stop"}],
                  "usage":{"prompt_tokens":11,"completion_tokens":7,"total_tokens":18},
                  "model":"med-extraction","tools":null}'

  check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
      ok "$desc"
    else
      err "$desc — attendu « $expected », obtenu « $actual »"
      failures=1
    fi
  }

  check "valeur imbriquée" "18" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" get usage.total_tokens)"
  check "index de liste"   "stop" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" get choices[0].finish_reason)"
  check "null"             "" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" get tools 2>/dev/null || true)"
  check "type"             "object" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" type usage)"
  # keys sur un tableau renvoie son encombrement, sur un objet ses clés.
  check "clés d'un objet"  "2" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" keys choices[0] | grep -c .)"
  check "taille d'un tableau" "liste[1]" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" keys choices)"
  check "valide => 0"      "0" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" valid >/dev/null 2>&1; echo $?)"
  check "invalide => 1"    "1" \
    "$(printf '{oops' | python3 "$FARCI_LIB_DIR/jsonpath.py" valid >/dev/null 2>&1; echo $?)"
  check "chemin absent => 1" "1" \
    "$(printf '%s' "$sample" | python3 "$FARCI_LIB_DIR/jsonpath.py" get usage.nonexistent >/dev/null 2>&1; echo $?)"

  return "$failures"
}

if json_selftest; then
  :
else
  FAILED=1
fi

section "registre des cibles (scripts/targets.def)"
# Ce registre est lu par la Makefile ET par bin/farci. Une tabulation en trop
# faisait disparaître une cible sans aucun message : on vérifie donc la forme
# exacte de chaque ligne, et que chaque script existe et est exécutable.
if python3 "$FARCI_ROOT/scripts/check_targets.py"; then
  :
else
  FAILED=1
fi

section "« Ensuite : » après chaque commande (scripts/suite.def)"
# Chaque cible propose la suite ; chaque commande proposée existe.
if python3 "$FARCI_ROOT/scripts/check_suite.py"; then
  :
else
  FAILED=1
fi

section "réponse à --help de toutes les cibles"
# Un script dont le parsing d'arguments boucle ne rendra JAMAIS la main : on
# vérifie donc que chaque cible répond à --help rapidement. C'est le filet de
# sécurité le moins cher contre toute la famille de bugs de boucle infinie.
# On passe par bin/farci et non directement par le script : c'est le chemin
# réel d'un utilisateur, et cela exercise aussi le lanceur et $FARCI_TARGET.
help_failures=0
while IFS=$'\t' read -r name group description script; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  script_path="$FARCI_ROOT/scripts/cmd/$script"
  [[ -x "$script_path" ]] || continue
  if timeout 15 "$FARCI_ROOT/bin/farci" "$name" --help >/dev/null 2>&1; then
    :
  else
    code=$?
    if (( code == 124 )); then
      err "$name : --help ne termine pas (boucle probable dans le parsing des arguments)"
    else
      err "$name : --help renvoie $code (attendu 0)"
    fi
    help_failures=1
  fi
done < "$FARCI_ROOT/scripts/targets.def"
if (( help_failures )); then
  FAILED=1
else
  ok "toutes les cibles répondent à --help"
fi

section "code_lines (filtre du lint ips)"
# Ce filtre retire commentaires et docstrings. Il a déjà été cassé par une
# docstring d'une seule ligne : on le teste donc sur les trois cas.
code_lines_selftest() {
  local tmp failures=0
  tmp="$(mktemp -d)"
  cat > "$tmp/echantillon.py" <<'PYTEST'
"""Docstring d'une seule ligne."""
import os

VRAI = 1
# commentaire avec 192.168.50.99

def f():
    """Docstring
    multi-ligne avec 192.168.50.98
    """
    return VRAI
PYTEST
  local out
  out="$(code_lines "$tmp/echantillon.py")"

  expect_absent() {
    if printf '%s' "$out" | grep -q "$1"; then
      err "code_lines aurait dû ignorer : $1"
      failures=1
    else
      ok "ignoré : $1"
    fi
  }
  expect_present() {
    if printf '%s' "$out" | grep -q "$1"; then
      ok "conservé : $1"
    else
      err "code_lines aurait dû conserver : $1"
      failures=1
    fi
  }

  expect_absent "192.168.50.99"   # commentaire
  expect_absent "192.168.50.98"   # docstring multi-ligne
  expect_present "import os"      # du vrai code
  expect_present "VRAI = 1"
  expect_present "return VRAI"    # code situé APRÈS une docstring fermée

  rm -rf "$tmp"
  return "$failures"
}

if code_lines_selftest; then
  :
else
  FAILED=1
fi

section "bibliothèque bash"
if bash -n "$FARCI_LIB_DIR/common.sh" && bash -n "$FARCI_ROOT/scripts/dev-env.sh"; then
  ok "common.sh et dev-env.sh : syntaxe correcte"
else
  err "erreur de syntaxe dans les bibliothèques bash"
  FAILED=1
fi

printf '\n'
if (( FAILED )); then
  err "auto-tests échoués"
  exit 1
fi
ok "auto-tests passés"
exit 0
