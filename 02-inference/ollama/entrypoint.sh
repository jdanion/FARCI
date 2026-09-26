#!/usr/bin/env bash
# FARCI — entrypoint Ollama
# Configure les variables d'environnement avant de démarrer le serveur.

set -euo pipefail

export OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:8080}"
export OLLAMA_KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:--1}"
export OLLAMA_NO_CLOUD="${OLLAMA_NO_CLOUD:-1}"

exec ollama serve
