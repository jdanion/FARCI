#!/usr/bin/env bash
# FARCI — bibliothèque de préchargement (scripts/preload_lib.sh)
# Sourced par preload.sh et verify-airgap.sh. Ne contient aucune dépendance
# externe : POSIX + coreutils + python3 stdlib.

# Garde-fou : ce fichier doit être sourcé, pas exécuté.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "preload_lib.sh est une bibliothèque : utilisez 'source scripts/preload_lib.sh'" >&2
  exit 64
fi

# --------------------------------------------------------------------------
# Chargement de la configuration
# --------------------------------------------------------------------------
# shellcheck source=scripts/lib/common.sh
if [[ -z "${FARCI_LIB_DIR:-}" ]]; then
  _preload_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/lib/common.sh
  source "$_preload_lib_dir/lib/common.sh"
fi
# shellcheck source=scripts/dev-env.sh
if [[ -z "${FARCI_ENV_LOADED:-}" ]]; then
  source "$FARCI_ROOT/scripts/dev-env.sh"
  farci_load_env
fi

# versions.env n'est pas dans farci_env_files() — le charger explicitement
if [[ -r "$FARCI_ROOT/versions.env" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -z "${!key+x}" ]] && export "$key=$value"
  done < "$FARCI_ROOT/versions.env"
fi

# --------------------------------------------------------------------------
# Groupes de préchargement
# --------------------------------------------------------------------------
# Chaque groupe est une fonction group_<nom>() qui télécharge les artefacts
# nécessaires. Les groupes sont enregistrés dans PRELOAD_GROUPS pour que
# preload.sh puisse les itérer.

declare -a PRELOAD_GROUPS=(
  gitops
  dashboard
  build_llamacpp
  models_ornith
  models_qwen38
  models_ci
  inference_ollama
  inference_llamacpp
  gateway_litellm
  gateway_bifrost
  observability_phoenix
  observability_langfuse
  documents
  evaluation
  clients
  wheels
  manifest
  tools
)

# Groupes inclus dans --core
declare -a PRELOAD_CORE_GROUPS=(
  gitops
  dashboard
  build_llamacpp
  models_ornith
  models_ci
  inference_ollama
  inference_llamacpp
  gateway_litellm
  observability_phoenix
  documents
  evaluation
  clients
  wheels
  manifest
)

# --------------------------------------------------------------------------
# Helpers de téléchargement
# --------------------------------------------------------------------------

# Télécharge un fichier avec vérification sha256 optionnelle.
#   preload_download <url> <dest> [sha256]
preload_download() {
  local url="$1" dest="$2" sha256="${3:-}"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"

  if [[ -f "$dest" && -n "$sha256" ]]; then
    if echo "$sha256  $dest" | sha256sum -c --quiet 2>/dev/null; then
      debug "déjà présent : $dest"
      return 0
    fi
  fi

  info "téléchargement : $url"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] %s → %s\n' "$url" "$dest"
    return 0
  fi

  curl -fSL --retry 3 -o "$dest" "$url" || {
    err "échec du téléchargement : $url"
    return 1
  }

  if [[ -n "$sha256" ]]; then
    if ! echo "$sha256  $dest" | sha256sum -c --quiet 2>/dev/null; then
      err "sha256 mismatch : $dest"
      rm -f "$dest"
      return 1
    fi
  fi
  ok "téléchargé : $dest"
}

# Charge une image Docker depuis un registre.
#   preload_docker_pull <image:tag>
preload_docker_pull() {
  local image="$1"
  info "image docker : $image"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] docker pull %s\n' "$image"
    return 0
  fi
  docker pull "$image" || {
    err "échec du pull : $image"
    return 1
  }
  ok "image présente : $image"
}

# Sauvegarde une image Docker dans le répertoire offline.
#   preload_docker_save <image:tag> <nom_fichier>
preload_docker_save() {
  local image="$1" filename="$2"
  local dest="$FARCI_IMAGES_DIR/$filename"
  info "sauvegarde image : $image → $dest"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] docker save %s → %s\n' "$image" "$dest"
    return 0
  fi
  mkdir -p "$FARCI_IMAGES_DIR"
  docker save "$image" -o "$dest" || {
    err "échec de la sauvegarde : $image"
    return 1
  }
  ok "image sauvegardée : $dest"
}

# --------------------------------------------------------------------------
# Groupes de préchargement
# --------------------------------------------------------------------------

group_gitops() {
  info "groupe : gitops"
  preload_docker_pull "gitea/gitea:${GITEA_VERSION}"
  preload_docker_pull "gitea/act_runner:${GITEA_ACT_RUNNER_VERSION}"
  preload_docker_pull "postgres:${POSTGRES_VERSION}"
  preload_docker_pull "redis:${REDIS_VERSION}"
}

group_dashboard() {
  info "groupe : dashboard"
  preload_docker_pull "caddy:${CADDY_VERSION}"
  preload_docker_pull "louislam/uptime-kuma:${UPTIME_KUMA_VERSION}"
}

group_build_llamacpp() {
  info "groupe : build_llamacpp (compilation locale multi-arch)"
  local src_dir="$FARCI_ROOT/02-inference/llamacpp"
  local tarball="$FARCI_MODELS_DIR/llama.cpp-${LLAMACPP_BUILD}.tar.gz"
  local tarball_sha="$FARCI_MODELS_DIR/llama.cpp-${LLAMACPP_BUILD}.tar.gz.sha256"

  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] buildx build --platform linux/amd64,linux/arm64 -t farci/llamacpp:server-%s\n' "$LLAMACPP_BUILD"
    return 0
  fi

  # Télécharger les sources llama.cpp
  local url="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${LLAMACPP_BUILD}.tar.gz"
  preload_download "$url" "$tarball"

  # Vérifier le sha256 si le fichier .sha256 existe
  if [[ -f "$tarball_sha" ]]; then
    local expected_sha
    expected_sha="$(cat "$tarball_sha")"
    if ! echo "$expected_sha  $tarball" | sha256sum -c --quiet 2>/dev/null; then
      err "sha256 mismatch pour llama.cpp source"
      return 1
    fi
  fi

  # Compiler et sauvegarder l'image
  if [[ -f "$src_dir/Dockerfile" ]]; then
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t "farci/llamacpp:server-${LLAMACPP_BUILD}" \
      -f "$src_dir/Dockerfile" \
      --load \
      "$FARCI_ROOT" || {
      err "échec de la compilation llama.cpp"
      return 1
    }
    preload_docker_save "farci/llamacpp:server-${LLAMACPP_BUILD}" "llamacpp-server-${LLAMACPP_BUILD}.tar"
  else
    warn "Dockerfile llama.cpp absent : $src_dir/Dockerfile"
    warn "  → créer 02-inference/llamacpp/Dockerfile (phase 4)"
  fi
}

group_models_ornith() {
  info "groupe : models_ornith"
  # Les URLs et sha256 sont dans models/models.env
  # Pour l'instant, on vérifie juste que le fichier existe
  if [[ ! -f "$FARCI_ROOT/models/models.env" ]]; then
    warn "models/models.env absent — les URLs des poids ne sont pas encore définies"
    return 0
  fi
  # Le téléchargement effectif sera fait par lock-models.sh en phase online
  info "  → utiliser scripts/lock-models.sh pour télécharger les poids Ornith"
}

group_models_qwen38() {
  info "groupe : models_qwen38"
  if [[ ! -f "$FARCI_ROOT/models/models.env" ]]; then
    warn "models/models.env absent — les URLs des poids ne sont pas encore définies"
    return 0
  fi
  info "  → utiliser scripts/lock-models.sh pour télécharger les poids Qwen3.8"
}

group_models_ci() {
  info "groupe : models_ci"
  if [[ ! -f "$FARCI_ROOT/models/models.env" ]]; then
    warn "models/models.env absent — les URLs des poids ne sont pas encore définies"
    return 0
  fi
  info "  → utiliser scripts/lock-models.sh pour télécharger les poids Qwen3.5-2B"
}

group_inference_ollama() {
  info "groupe : inference_ollama"
  preload_docker_pull "ollama/ollama:${OLLAMA_VERSION}"
}

group_inference_llamacpp() {
  info "groupe : inference_llamacpp"
  # L'image est construite localement par group_build_llamacpp
  info "  → l'image farci/llamacpp est construite par group_build_llamacpp"
}

group_gateway_litellm() {
  info "groupe : gateway_litellm"
  preload_docker_pull "ghcr.io/berriai/litellm:${LITELLM_VERSION}"
}

group_gateway_bifrost() {
  info "groupe : gateway_bifrost"
  preload_docker_pull "ghcr.com/MaximFaq/bifrost:${BIFROST_VERSION}"
}

group_observability_phoenix() {
  info "groupe : observability_phoenix"
  preload_docker_pull "arizephoenix/phoenix:${PHOENIX_VERSION}"
}

group_observability_langfuse() {
  info "groupe : observability_langfuse"
  preload_docker_pull "langfuse/langfuse:${LANGFUSE_VERSION}"
}

group_documents() {
  info "groupe : documents"
  preload_docker_pull "ds4sd/docling-serve:${DOCLING_SERVE_VERSION}"
}

group_evaluation() {
  info "groupe : evaluation"
  preload_docker_pull "mlflow/mlflow:${MLFLOW_VERSION}"
}

group_clients() {
  info "groupe : clients"
  preload_docker_pull "ghcr.io/open-webui/open-webui:${OPEN_WEBUI_VERSION}"
  preload_docker_pull "flowiseai/flowise:${FLOWISE_VERSION}"
}

group_wheels() {
  info "groupe : wheels"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] pip download --no-index --find-links=offline/wheels\n'
    return 0
  fi
  mkdir -p "$FARCI_WHEELS_DIR"
  pip3 download \
    --dest "$FARCI_WHEELS_DIR" \
    -r "$FARCI_ROOT/requirements.in" \
    -r "$FARCI_ROOT/requirements-eval.txt" \
    2>/dev/null || warn "pip download a échoué — vérifier requirements.in"
}

group_manifest() {
  info "groupe : manifest"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] générer offline/MANIFEST.sha256\n'
    return 0
  fi
  "$FARCI_ROOT/scripts/gen-manifest.sh"
}

group_tools() {
  info "groupe : tools"
  if [[ "${PRELOAD_DRY_RUN:-0}" == "1" ]]; then
    printf '  [dry-run] installer make, shellcheck, unzip\n'
    return 0
  fi
  if [[ -f "$FARCI_ROOT/tools/install.sh" ]]; then
    bash "$FARCI_ROOT/tools/install.sh"
  else
    warn "tools/install.sh absent — installation manuelle requise"
  fi
}

# --------------------------------------------------------------------------
# Exécution d'un groupe
# --------------------------------------------------------------------------
run_group() {
  local group="$1"
  local func="group_${group}"
  if ! declare -f "$func" >/dev/null; then
    err "groupe inconnu : $group"
    return 1
  fi
  "$func"
}
