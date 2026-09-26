#!/usr/bin/env bash
# FARCI — vérification des images Docker locales (FARCI §7.2)
#
# Vérifie que toutes les images requises sont présentes localement et
# qu'elles correspondent aux versions figées dans versions.env.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

section "FARCI — vérification des images Docker"

IMAGES=(
  "gitea/gitea:${GITEA_VERSION}"
  "gitea/act_runner:${GITEA_ACT_RUNNER_VERSION}"
  "postgres:${POSTGRES_VERSION}"
  "redis:${REDIS_VERSION}"
  "caddy:${CADDY_VERSION}"
  "louislam/uptime-kuma:${UPTIME_KUMA_VERSION}"
  "ollama/ollama:${OLLAMA_VERSION}"
  "ghcr.io/berriai/litellm:${LITELLM_VERSION}"
  "ds4sd/docling-serve:${DOCLING_SERVE_VERSION}"
  "arizephoenix/phoenix:${PHOENIX_VERSION}"
  "mlflow/mlflow:${MLFLOW_VERSION}"
  "ghcr.io/open-webui/open-webui:${OPEN_WEBUI_VERSION}"
  "flowiseai/flowise:${FLOWISE_VERSION}"
)

missing=0
present=0

for img in "${IMAGES[@]}"; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    ok "$img"
    present=$((present + 1))
  else
    warn "MANQUANTE : $img"
    missing=$((missing + 1))
  fi
done

printf '\n'
printf '%d présente(s), %d manquante(s)\n' "$present" "$missing"

if (( missing > 0 )); then
  printf 'Exécutez ./preload.sh --core pour télécharger les images manquantes.\n'
  exit 1
fi

ok "toutes les images requises sont présentes"
