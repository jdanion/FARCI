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
  [flowise]="flowiseai/flowise:${FLOWISE_VERSION:-}"
)
FARCI_IMAGES_CORE=(caddy python ollama litellm docling phoenix open-webui)
FARCI_IMAGES_BONUS=(gitea act-runner ci-runner postgres redis uptime-kuma bifrost langfuse otel-collector mlflow flowise)

farci_image() { printf '%s\n' "${FARCI_IMAGE[$1]:?image inconnue : $1}"; }

farci_images() {
  local key keys=()
  case "${1:-all}" in
    core)  keys=("${FARCI_IMAGES_CORE[@]}") ;;
    bonus) keys=("${FARCI_IMAGES_BONUS[@]}") ;;
    all)   keys=("${FARCI_IMAGES_CORE[@]}" "${FARCI_IMAGES_BONUS[@]}") ;;
    *)     echo "farci_images : core | bonus | all" >&2; return 64 ;;
  esac
  for key in "${keys[@]}"; do
    printf '%s\n' "${FARCI_IMAGE[$key]}"
  done
}
