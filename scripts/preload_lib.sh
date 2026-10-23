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

# Télécharge une image de scripts/lib/images.sh PUIS la sauvegarde en .tar
# dans offline/images/ : c'est ce .tar que l'on copie sur les postes sans
# Internet (clé USB), où `docker load` la rend disponible.
#   preload_image <clé>    (ex. preload_image docling)
preload_image() {
  local image file
  image="$(farci_image "$1")" || return 1
  file="$(printf '%s' "$image" | tr '/:' '__').tar"
  preload_docker_pull "$image" || return 1
  if [[ "${PRELOAD_SKIP_EXISTING:-0}" == "1" && -f "$FARCI_IMAGES_DIR/$file" ]]; then
    debug "déjà sauvegardée : $file"
    return 0
  fi
  preload_docker_save "$image" "$file"
}

# Télécharge les poids d'un modèle déclaré dans models/models.env.
#   preload_model <PRÉFIXE>   (ex. ORNITH_1_5_9B_Q5KM -> _URL, _SHA256)
# Le nom du fichier est celui de l'URL : c'est ce nom qu'attendent
# llama.cpp, create-model.sh et verify-models.
preload_model() {
  local prefix="$1" url_var="${1}_URL" sha_var="${1}_SHA256" url sha dest
  # shellcheck source=models/models.env
  source "$FARCI_ROOT/models/models.env"
  url="${!url_var:-}"
  sha="${!sha_var:-}"
  [[ -n "$url" ]] || { err "models/models.env : $url_var absent"; return 1; }
  dest="$FARCI_MODELS_DIR/$(basename "$url")"
  if [[ -f "$dest" && -z "$sha" && "${PRELOAD_SKIP_EXISTING:-0}" == "1" ]]; then
    debug "déjà présent : $dest"
    return 0
  fi
  [[ -n "$sha" ]] || warn "$sha_var vide : empreinte non vérifiée (elle sera inscrite au manifeste)"
  preload_download "$url" "$dest" "$sha"
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
  preload_image gitea
  preload_image act-runner
  preload_image ci-runner
  preload_image postgres
  preload_image redis
}

group_dashboard() {
  info "groupe : dashboard"
  preload_image caddy
  preload_image python
  preload_image uptime-kuma
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
  info "groupe : models_ornith (modèle principal, ~6,5 Go)"
  preload_model ORNITH_1_5_9B_Q5KM
}

group_models_qwen38() {
  info "groupe : models_qwen38 (gros postes uniquement, ~16,5 Go)"
  preload_model QWEN3_8_27B_Q4KM
}

group_models_ci() {
  info "groupe : models_ci (modèle de secours et de CI, ~1,2 Go)"
  preload_model QWEN3_5_2B_Q4KM
}

group_inference_ollama() {
  info "groupe : inference_ollama"
  preload_image ollama
}

group_inference_llamacpp() {
  info "groupe : inference_llamacpp"
  # L'image est construite localement par group_build_llamacpp
  info "  → l'image farci/llamacpp est construite par group_build_llamacpp"
}

group_gateway_litellm() {
  info "groupe : gateway_litellm"
  preload_image litellm
}

group_gateway_bifrost() {
  info "groupe : gateway_bifrost"
  preload_image bifrost
}

group_observability_phoenix() {
  info "groupe : observability_phoenix"
  preload_image phoenix
}

group_observability_langfuse() {
  info "groupe : observability_langfuse"
  preload_image langfuse
  preload_image otel-collector
}

group_documents() {
  info "groupe : documents"
  preload_image docling
}

group_evaluation() {
  info "groupe : evaluation"
  preload_image mlflow
}

group_clients() {
  info "groupe : clients"
  preload_image open-webui
  preload_image flowise
}

# Pile de référence (reference/docker-compose.yml) : à lancer sur le Pi
# lui-même. `docker pull` tire l'architecture de la machine (arm64 sur un
# Pi) : les .tar produits ici ne servent qu'au Pi, pas aux portables x86.
group_reference() {
  info "groupe : reference (machine du formateur, architecture $(uname -m))"
  preload_image caddy
  preload_image python
  preload_image litellm
  preload_image phoenix
  preload_image open-webui
  preload_image ollama
  # Docling (profil documents) : image lourde, arm64 à vérifier sur le Pi.
  preload_image docling || warn "Docling indisponible pour $(uname -m) : la route documents restera aux équipes"
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
  "$FARCI_ROOT/scripts/cmd/gen-manifest.sh"
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
