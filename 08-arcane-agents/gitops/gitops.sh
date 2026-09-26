#!/usr/bin/env bash
# FARCI — déploiement GitOps
#
# Pull le dépôt et applique les manifests.
# Idempotent : peut être exécuté plusieurs fois sans effet de bord.

set -euo pipefail

FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FARCI_ROOT

# shellcheck source=scripts/lib/common.sh
source "$FARCI_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

farci_load_env

BRANCH="${1:-main}"

section "FARCI — GitOps déploiement"

# Vérifier que le dépôt est propre
if [[ -n "$(git -C "$FARCI_ROOT" status --porcelain)" ]]; then
  warn "dépôt non propre — commit ou stash des changements avant déploiement"
fi

# Pull la branche
info "pull de $BRANCH..."
git -C "$FARCI_ROOT" pull origin "$BRANCH"

# Appliquer les manifests
info "application des manifests..."

# Ollama
if [[ -f "$FARCI_ROOT/02-inference/ollama/docker-compose.yml" ]]; then
  info "  → ollama"
  docker compose -f "$FARCI_ROOT/02-inference/ollama/docker-compose.yml up -d
fi

# llama.cpp
if [[ -f "$FARCI_ROOT/02-inference/llamacpp/docker-compose.yml" ]]; then
  info "  → llamacpp"
  docker compose -f "$FARCI_ROOT/02-inference/llamacpp/docker-compose.yml up -d
fi

# Gateway
if [[ -f "$FARCI_ROOT/03-llm-gateway/litellm/docker-compose.yml" ]]; then
  info "  → litellm"
  docker compose -f "$FARCI_ROOT/03-llm-gateway/litellm/docker-compose.yml up -d
fi

# Docling
if [[ -f "$FARCI_ROOT/04-clinical-documents/docling/docker-compose.yml" ]]; then
  info "  → docling"
  docker compose -f "$FARCI_ROOT/04-clinical-documents/docling/docker-compose.yml up -d
fi

# MLflow
if [[ -f "$FARCI_ROOT/06-evaluation/mlflow/docker-compose.yml" ]]; then
  info "  → mlflow"
  docker compose -f "$FARCI_ROOT/06-evaluation/mlflow/docker-compose.yml up -d
fi

# Agents Arcane
if [[ -f "$FARCI_ROOT/08-arcane-agents/docker-compose.yml" ]]; then
  info "  → agents arcane"
  docker compose -f "$FARCI_ROOT/08-arcane-agents/docker-compose.yml up -d
fi

ok "GitOps déploiement terminé"
