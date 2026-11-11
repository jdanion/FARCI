# FARCI — llama.cpp server, compilé pour la machine qui le servira
#
# Construit par ./preload.sh (groupe build_llamacpp), AVEC Internet :
#   1. le préchargement clone llama.cpp à la version LLAMACPP_BUILD
#      (versions.env) dans 02-inference/llamacpp/vendor/llama.cpp (hors Git) ;
#   2. docker build compile llama-server ici, sans réseau vers GitHub.
# GGML_NATIVE : les instructions du processeur de CETTE machine (CPU seul).
# Base : l'image python déjà préchargée (versions.env), rien d'autre à tirer.

ARG PYTHON_IMAGE_TAG
FROM python:${PYTHON_IMAGE_TAG} AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

COPY vendor/llama.cpp /src/llama.cpp
WORKDIR /src/llama.cpp
# Binaire autonome (bibliothèques statiques), sans HTTPS ni téléchargement de
# modèle (air-gap : les poids sont montés en lecture seule).
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON -DBUILD_SHARED_LIBS=OFF \
      -DLLAMA_OPENSSL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
    && cmake --build build --config Release -j"$(nproc)" --target llama-server

ARG PYTHON_IMAGE_TAG
FROM python:${PYTHON_IMAGE_TAG}

# Ce dont llama-server a besoin à l'exécution (ldd) : libgomp1 (OpenMP,
# threads de calcul) et libstdc++6 ; curl : sonde de santé de la compose.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libstdc++6 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/llama.cpp/build/bin/llama-server /usr/local/bin/

EXPOSE 8080

ENTRYPOINT ["llama-server"]
