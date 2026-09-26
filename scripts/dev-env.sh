#!/usr/bin/env bash
# FARCI — chargement unique de la configuration (scripts/dev-env.sh)
#
# PRINCIPE : c'est le SEUL endroit du dépôt qui lit les fichiers .env.
# Aucun script, aucun compose, aucun module Python ne doit réimplémenter
# cette logique (FARCI §4 : « aucune IP ne doit être répétée dans le code »).
#
# ORDRE DE PRIORITÉ (du plus fort au plus faible) :
#   1. l'environnement déjà exporté      (on peut toujours surcharger à la main)
#   2. config/workshop.env               (réglages de ce poste)
#   3. config/network.env                (adresses)
#   4. .env                              (global)
#
# Usage :
#   source scripts/dev-env.sh           # exporte dans le shell courant
#   scripts/dev-env.sh --print          # affiche la configuration effective
#   scripts/dev-env.sh --check          # valide la configuration, sort 1 si KO
#   scripts/dev-env.sh --paths          # affiche les fichiers de configuration

# shellcheck source=scripts/lib/common.sh
if [[ -z "${FARCI_LIB_DIR:-}" ]]; then
  _dev_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/lib/common.sh
  source "$_dev_env_dir/lib/common.sh"
fi

# Liste des fichiers de config, du plus prioritaire au moins prioritaire.
farci_env_files() {
  printf '%s\n' \
    "$FARCI_ROOT/config/workshop.env" \
    "$FARCI_ROOT/config/network.env" \
    "$FARCI_ROOT/.env"
}

farci_load_env() {
  [[ "${FARCI_ENV_LOADED:-0}" == "1" ]] && return 0
  [[ "${FARCI_SKIP_ENV:-0}" == "1" ]] && return 0

  local file key value
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="${key//export /}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # L'environnement existant gagne toujours.
    if [[ -n "${!key+x}" ]]; then
      debug "conserver $key (déjà dans l'environnement)"
      continue
    fi
    export "$key=$value"
  done < <(for f in $(farci_env_files); do emit_env_file "$f"; done)

  # Valeurs dérivées : jamais écrites dans un .env, toujours calculées.
  # AUCUNE adresse par défaut ici (FARCI §4) : si FARCI_SUBNET manque,
  # `env-check` le signale. Mieux vaut une erreur franche qu'un
  # réseau supposé qui n'existe pas.
  export FARCI_ROOT
  export FARCI_DATA_DIR="${FARCI_DATA_DIR:-/srv/farci}"
  export FARCI_OFFLINE_DIR="${FARCI_DATA_DIR}/offline"
  export FARCI_MODELS_DIR="${FARCI_OFFLINE_DIR}/models"
  export FARCI_IMAGES_DIR="${FARCI_OFFLINE_DIR}/images"
  export FARCI_WHEELS_DIR="${FARCI_OFFLINE_DIR}/wheels"
  export FARCI_MANIFEST="${FARCI_OFFLINE_DIR}/MANIFEST.sha256"
  export FARCI_DOCKER_NETWORK="${FARCI_DOCKER_NETWORK:-farci}"

  FARCI_ENV_LOADED=1
  export FARCI_ENV_LOADED
}

# Variables sans lesquelles rien ne peut fonctionner. Volontairement court :
# mieux vaut un échec franc qu'un compose qui démarre à moitié.
FARCI_REQUIRED_VARS=(
  FARCI_SUBNET
  INFERENCE_A_IP INFERENCE_B_IP
  GATEWAY_A_IP
  DOCLING_IP
  MLFLOW_IP
  CADDY_IP
)

# farci_check_env valide la configuration.
# L'adresse et les ports sont validés par scripts/services.py, qui est la SEULE
# implémentation de cette règle : la dupliquer ici l'avait déjà rendue fausse
# une fois (comparaison « l'adresse commence par le réseau »).
farci_check_env() {
  local failures=0 var

  if [[ ! -r "$FARCI_ROOT/config/services.yaml" ]]; then
    err "config/services.yaml introuvable — le dépôt est incomplet"
    failures=$(( failures + 1 ))
  fi

  for var in "${FARCI_REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      err "variable manquante : $var"
      err "  → cp config/network.env.example config/network.env  puis compléter"
      failures=$(( failures + 1 ))
    fi
  done

  if (( failures == 0 )); then
    if ! python3 "$FARCI_ROOT/scripts/services.py" check-network; then
      failures=$(( failures + 1 ))
    fi
  else
    warn "adresses non validées : des variables manquent encore"
  fi

  # Avertissements (non bloquants).
  local warn=0
  have make      || { warn "make absent : utilisez ./bin/farci <cible> (mêmes cibles)"; warn=1; }
  have curl      || { warn "curl absent : les sondes de santé échoueront"; warn=1; }
  have sha256sum || { warn "sha256sum absent : verify-airgap.sh ne pourra pas vérifier"; warn=1; }
  (( warn )) && warn "certains outillages manquent : ./preload.sh --tools les installe"

  (( failures == 0 )) || return 1
  return 0
}

farci_print_env() {
  local file key
  for file in $(farci_env_files); do
    [[ -r "$file" ]] || continue
    printf '\n%s# %s%s\n' "$C_BOLD" "$file" "$C_RESET"
    emit_env_file "$file" | while IFS= read -r line; do
      key="${line%%=*}"
      if [[ -n "${!key+x}" && "${!key}" != "${line#*=}" ]]; then
        printf '%s (surchargé par l’environnement : %s)%s\n' "$line" "${!key}" "$C_DIM"
      else
        printf '%s\n' "$line"
      fi
    done
  done
  printf '\n%s# dérivées%s\n' "$C_BOLD" "$C_RESET"
  printf 'FARCI_ROOT=%s\nFARCI_DATA_DIR=%s\nFARCI_OFFLINE_DIR=%s\n' \
    "$FARCI_ROOT" "$FARCI_DATA_DIR" "${FARCI_OFFLINE_DIR:-}"
  printf 'FARCI_SUBNET=%s\nFARCI_DOCKER_NETWORK=%s\n' \
    "${FARCI_SUBNET:-}" "${FARCI_DOCKER_NETWORK:-farci}"
}

# Exécution directe : --print | --check | --paths
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  need_python
  case "${1:---print}" in
    --print)  farci_load_env; farci_print_env ;;
    --check)  farci_load_env; farci_check_env && ok "configuration valide" ;;
    --paths)  farci_load_env
              for f in $(farci_env_files); do
                [[ -r "$f" ]] && printf '%s\n' "$f" || printf '%s (absent)\n' "$f"
              done ;;
    *)       echo "usage: $0 [--print|--check|--paths]" >&2; exit 64 ;;
  esac
fi
