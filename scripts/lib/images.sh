#!/usr/bin/env bash
# FARCI — liste UNIQUE des images Docker de l'atelier (scripts/lib/images.sh)
#
# Sourcée après farci_load_versions (scripts/dev-env.sh) : les tags viennent
# de versions.env, les NOMS d'images sont ici et nulle part ailleurs.
# preload.sh, verify-airgap.sh, verify-images et lock-digests lisent cette
# liste ; avant elle, cinq listes divergeaient (et deux images n'existaient pas).
#
#   farci_images core     images de la chaîne cœur
#   farci_images bonus    briques bonus et démos du formateur
#   farci_images all      tout
#   farci_images reference  pile de référence de base (reference/, sur le Pi)
#   farci_image <clé>     une image (ex. farci_image docling)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "images.sh est une bibliothèque : utilisez 'source scripts/lib/images.sh'" >&2
  exit 64
fi

declare -gA FARCI_IMAGE=(
  # --- chaîne cœur -----------------------------------------------------------
  [caddy]="caddy:${CADDY_VERSION:-}"
  [python]="python:${PYTHON_IMAGE_TAG:-}"
  [ollama]="ollama/ollama:${OLLAMA_VERSION:-}"
  [litellm]="ghcr.io/berriai/litellm:${LITELLM_VERSION:-}"
  [docling]="ghcr.io/docling-project/docling-serve-cpu:v${DOCLING_SERVE_VERSION:-}"
  [phoenix]="arizephoenix/phoenix:${PHOENIX_VERSION:-}"
  [open-webui]="ghcr.io/open-webui/open-webui:${OPEN_WEBUI_VERSION:-}"
  # construite au préchargement (group_build_eds_nlp), jamais téléchargée
  [eds-nlp]="farci/eds-nlp:${EDSNLP_VERSION:-}"
  # compilée au préchargement pour la machine (group_build_llamacpp)
  [llamacpp]="farci/llamacpp:server-${LLAMACPP_BUILD:-}"
  # --- bonus -----------------------------------------------------------------
  [gitea]="gitea/gitea:${GITEA_VERSION:-}"
  [act-runner]="gitea/act_runner:${GITEA_ACT_RUNNER_VERSION:-}"
  [ci-runner]="node:${CI_RUNNER_NODE_VERSION:-}"
  [postgres]="postgres:${POSTGRES_VERSION:-}"
  [redis]="redis:${REDIS_VERSION:-}"
  [uptime-kuma]="louislam/uptime-kuma:${UPTIME_KUMA_VERSION:-}"
  [bifrost]="maximhq/bifrost:v${BIFROST_VERSION:-}"
  [langfuse]="langfuse/langfuse:${LANGFUSE_VERSION:-}"
  [otel-collector]="otel/opentelemetry-collector-contrib:${OTEL_COLLECTOR_VERSION:-}"
  [mlflow]="ghcr.io/mlflow/mlflow:v${MLFLOW_VERSION:-}"
  # démonstration du formateur (./preload.sh --all), pas une option étudiante
  [flowise]="flowiseai/flowise:${FLOWISE_VERSION:-}"
)
FARCI_IMAGES_CORE=(caddy python ollama litellm docling eds-nlp phoenix open-webui)
# Pile de référence de base ; Ollama et Docling y sont des options.
FARCI_IMAGES_REFERENCE=(caddy python litellm phoenix open-webui eds-nlp)
FARCI_IMAGES_BONUS=(gitea act-runner ci-runner postgres redis uptime-kuma bifrost langfuse otel-collector mlflow flowise)

# Images d'un poste étudiant : la brique de son équipe, selon la machine
# (grosse | legere). Même partage que poste_groups (scripts/preload_lib.sh).
farci_poste_image_keys() {
  local team="$1" profil="$2"
  case "$team" in
    0) printf '%s\n' gitea act-runner ci-runner postgres redis ;;
    1) printf '%s\n' caddy python uptime-kuma ;;
    2) if [[ "$profil" == grosse ]]; then printf '%s\n' ollama; else printf '%s\n' llamacpp; fi ;;
    3) printf '%s\n' litellm bifrost ;;
    4) printf '%s\n' docling eds-nlp ;;
    5) if [[ "$profil" == grosse ]]; then printf '%s\n' phoenix langfuse postgres otel-collector
       else printf '%s\n' phoenix; fi ;;
    6) printf '%s\n' mlflow ;;
    7) printf '%s\n' open-webui ;;
    8) printf '%s\n' python ;;
    *) return 1 ;;
  esac
}

farci_image() { printf '%s\n' "${FARCI_IMAGE[$1]:?image inconnue : $1}"; }

farci_images() {
  local key keys=()
  case "${1:-all}" in
    core)  keys=("${FARCI_IMAGES_CORE[@]}") ;;
    bonus) keys=("${FARCI_IMAGES_BONUS[@]}") ;;
    all)   keys=("${FARCI_IMAGES_CORE[@]}" "${FARCI_IMAGES_BONUS[@]}") ;;
    reference) keys=("${FARCI_IMAGES_REFERENCE[@]}") ;;
    poste) mapfile -t keys < <(farci_poste_image_keys "${2:-}" "${3:-legere}") ;;
    *)     echo "farci_images : core | bonus | all | reference | poste <équipe> <profil>" >&2; return 64 ;;
  esac
  for key in "${keys[@]}"; do
    printf '%s\n' "${FARCI_IMAGE[$key]}"
  done
}
