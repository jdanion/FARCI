#!/usr/bin/env bash
# FARCI — ./bin/farci bootstrap
#
# Prépare la machine pour travailler sur le dépôt, SANS toucher à Internet
# (le téléchargement est la responsabilité de preload.sh, en phase online).
#
#   ./bin/farci bootstrap            prépare
#   ./bin/farci bootstrap --check    vérifie seulement, n'écrit rien
#
# Ce que fait le bootstrap :
#   1. vérifie les prérequis (docker, python3, curl...)
#   2. crée $FARCI_DATA_DIR et ses sous-répertoires (§0.1 du plan)
#   3. crée le lien symbolique offline/ -> $FARCI_DATA_DIR/offline
#      (les chemins offline/wheels/ et offline/MANIFEST.sha256 du cahier des
#       charges restent donc valides, sans que le dépôt stocke des Go)
#   4. crée .env et config/*.env à partir des exemples, sans écraser l'existant
#   5. initialise git si nécessaire
#   6. corrige les permissions des scripts
#   7. crée l'environnement Python .venv/ et l'installe HORS LIGNE depuis
#      offline/wheels/ (pip refuse souvent d'installer dans le Python système)
#   8. lance le lint
#
# Idempotent : peut être relancé sans risque.

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *) die "option inconnue : $arg" ;;
  esac
done

CHANGES=0
changed() { CHANGES=$(( CHANGES + 1 )); }

section "1. prérequis"
REQUIRED_OK=1
for tool in docker python3 curl tar sha256sum git; do
  if have "$tool"; then
    ok "$tool"
  else
    err "$tool MANQUANT"
    REQUIRED_OK=0
  fi
done
if have docker && ! docker info >/dev/null 2>&1; then
  err "le démon Docker ne répond pas — le started service docker est-il lancé ?"
  REQUIRED_OK=0
fi
if (( CHECK_ONLY )); then
  (( REQUIRED_OK )) && ok "prérequis satisfaits" || err "prérequis manquants"
  exit $(( REQUIRED_OK ? 0 : 1 ))
fi
(( REQUIRED_OK )) || die "corriger les prérequis manquants avant de continuer"

section "2. répertoire de données lourdes"
# Charger .env s'il existe déjà, pour connaître FARCI_DATA_DIR.
if [[ -r "$FARCI_ROOT/.env" ]]; then
  # shellcheck source=scripts/dev-env.sh
  source "$FARCI_ROOT/scripts/dev-env.sh"
  farci_load_env
fi
DATA_DIR="${FARCI_DATA_DIR:-/srv/farci}"

# Si /srv n'est pas inscriptible (poste étudiant), se rabattre sur ~/.farci.
if ! mkdir -p "$DATA_DIR" 2>/dev/null || [[ ! -w "$DATA_DIR" ]]; then
  fallback="$HOME/.farci"
  warn "$DATA_DIR n'est pas inscriptible — repli sur $fallback"
  warn "mettez à jour FARCI_DATA_DIR dans .env pour rendre le choix explicite"
  DATA_DIR="$fallback"
  FARCI_DATA_DIR="$DATA_DIR"
  mkdir -p "$DATA_DIR" || die "impossible de créer $DATA_DIR"
fi

for sub in offline/images offline/models offline/wheels offline/bin logs; do
  if [[ ! -d "$DATA_DIR/$sub" ]]; then
    mkdir -p "$DATA_DIR/$sub" && { ok "créé $DATA_DIR/$sub"; changed; }
  else
    info "existe $DATA_DIR/$sub"
  fi
done

section "3. lien symbolique offline/"
# FARCI §10 et §51 imposent les chemins offline/wheels/ et offline/MANIFEST.sha256.
# On respecte ces chemins sans rien stocker dans le dépôt : lien symbolique.
# Le lien n'est PAS versionné — un clone frais n'en a pas besoin, et le chemin
# du formateur serait invalide chez l'étudiant.
if [[ -L "$FARCI_ROOT/offline" ]]; then
  current="$(readlink "$FARCI_ROOT/offline")"
  if [[ "$current" == "$DATA_DIR/offline" ]]; then
    info "offline -> $current (correct)"
  else
    warn "offline pointe vers $current, attendu $DATA_DIR/offline"
    info "corriger : rm offline && ln -s $DATA_DIR/offline offline"
  fi
elif [[ -d "$FARCI_ROOT/offline" ]]; then
  if [[ -z "$(ls -A "$FARCI_ROOT/offline" 2>/dev/null)" ]]; then
    rmdir "$FARCI_ROOT/offline" 2>/dev/null || true
    ln -s "$DATA_DIR/offline" "$FARCI_ROOT/offline" \
      && { ok "offline est désormais un lien vers $DATA_DIR/offline"; changed; }
  else
    warn "$FARCI_ROOT/offline est un VRAI dossier contenant des fichiers."
    warn "Cela n'est pas conforme : offline/ doit être un lien symbolique."
    warn "Déplacer son contenu vers $DATA_DIR/offline, puis réessayer :"
    warn "    mv $FARCI_ROOT/offline/* $DATA_DIR/offline/ && rmdir $FARCI_ROOT/offline"
  fi
else
  ln -s "$DATA_DIR/offline" "$FARCI_ROOT/offline" \
    && { ok "offline -> $DATA_DIR/offline"; changed; }
fi

# Un fichier d'explication vit dans le répertoire de données, pour que
# quelqu'un qui regarde la clé USB sache ce qu'il y a dedans.
if [[ ! -r "$DATA_DIR/offline/README.md" ]]; then
  cat > "$DATA_DIR/offline/README.md" <<'OFFLINE_README'
# offline/ — les artefacts lourds du workshop

Ce répertoire est la cible du lien symbolique `offline/` dans le dépôt.
Il n'est JAMAIS versionné : un modèle pèse 6 à 18 Go.

## Contenu attendu

    images/     images Docker sauvegardées (docker save)
    models/     poids des modèles au format GGUF
    wheels/     paquets Python téléchargés (installation --no-index)
    bin/        binaires optionnels (Mac)
    MANIFEST.sha256   empreintes de tout ce qui précède

## Remplissage

Une seule fois, avec Internet, AVANT le workshop :

    ./preload.sh --core
    ./verify-airgap.sh

Le jour J, rien ne doit être téléchargé. Si quelque chose tente de sortir sur
Internet, c'est un défaut : `./verify-airgap.sh` le signale.
OFFLINE_README
  ok "écrit $DATA_DIR/offline/README.md"
fi

section "4. fichiers de configuration"
create_from_example() {
  local example="$1" target="$2"
  if [[ -r "$FARCI_ROOT/$target" ]]; then
    info "existe $target (non écrasé)"
  elif [[ -r "$FARCI_ROOT/$example" ]]; then
    cp "$FARCI_ROOT/$example" "$FARCI_ROOT/$target" \
      && { ok "créé $target (à partir de $example)"; changed; }
  else
    err "exemple manquant : $example"
  fi
}
create_from_example ".env.example" ".env"
create_from_example "config/network.env.example" "config/network.env"
create_from_example "config/workshop.env.example" "config/workshop.env"

section "5. dépôt git"
if [[ -d "$FARCI_ROOT/.git" ]]; then
  info "dépôt git déjà initialisé"
else
  git -C "$FARCI_ROOT" init -q -b main && { ok "git init (branche main)"; changed; }
  if ! git -C "$FARCI_ROOT" config user.name >/dev/null 2>&1; then
    info "aucune identité git configurée — pensez à :"
    printf '        git config user.name  "Votre Nom"\n'
    printf '        git config user.email "vous@exemple.univ.fr"\n'
  fi
fi

section "6. permissions des scripts"
non_exec="$(find "$FARCI_ROOT/scripts" "$FARCI_ROOT/bin" "$FARCI_ROOT/bootstrap.sh" \
            -name '*.sh' -o -path "$FARCI_ROOT/bin/farci" 2>/dev/null \
            | while IFS= read -r f; do
                [[ -f "$f" && ! -x "$f" ]] && printf '%s ' "$f"
              done)"
if [[ -n "${non_exec// /}" ]]; then
  # shellcheck disable=SC2086
  chmod +x $non_exec && { ok "permissions+x corrigées : $non_exec"; changed; }
else
  info "tous les scripts sont exécutables"
fi

section "7. environnement Python (.venv)"
# Hors ligne : uniquement depuis offline/wheels/ (préparé par preload.sh).
REQ="$FARCI_ROOT/requirements.txt"
[[ -r "$REQ" ]] || REQ="$FARCI_ROOT/requirements.in"
WHEELS="$FARCI_ROOT/offline/wheels"
# bin/farci n'utilise .venv/ qu'une fois le témoin .farci-ok posé : un .venv/
# incomplet ne doit jamais masquer un Python système qui fonctionne.
if [[ -f "$FARCI_ROOT/.venv/.farci-ok" ]]; then
  info ".venv/ déjà équipé"
elif python3 -c "import pydantic" 2>/dev/null && [[ ! -d "$FARCI_ROOT/.venv" ]]; then
  info "le Python du système a déjà les dépendances : pas de .venv/ nécessaire"
elif ! compgen -G "$WHEELS/*.whl" >/dev/null; then
  warn "offline/wheels/ est vide : ./preload.sh --only wheels (avec Internet, sur CETTE machine)"
elif ! { [[ -x "$FARCI_ROOT/.venv/bin/python3" ]] || python3 -m venv "$FARCI_ROOT/.venv"; }; then
  warn "python3 -m venv a échoué : installer python3-venv AVANT l'atelier (sudo apt install python3-venv)"
elif "$FARCI_ROOT/.venv/bin/python3" -m pip install -q --no-index --find-links "$WHEELS" -r "$REQ"; then
  touch "$FARCI_ROOT/.venv/.farci-ok"
  ok "dépendances Python installées hors ligne dans .venv/ ($(basename "$REQ"))"; changed
else
  warn "installation hors ligne incomplète : ./bin/farci verify-wheels"
fi

section "8. lint"
if "$FARCI_ROOT/bin/farci" lint --quiet; then
  ok "dépôt conforme"
else
  warn "le dépôt ne passe pas encore le lint (voir ./bin/farci lint)"
fi

printf '\n'
if (( CHANGES )); then
  ok "bootstrap terminé ($CHANGES modification(s))"
else
  ok "bootstrap terminé (rien à faire)"
fi
cat <<'NEXT'

  Prochaines étapes selon votre rôle :

    lire sa fiche d'équipe   ./bin/farci read <équipe>
    préparation air-gap     ./preload.sh --core
    développement           ./bin/farci doctor
    suivre la construction  ./bin/farci status --watch

NEXT
exit 0
