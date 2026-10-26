# FARCI — llama.cpp server (construit localement, phase 1)
#
# Compilée depuis les sources pour la machine qui la construit
# (./preload.sh : groupe build_llamacpp).
# Aucune dépendance GHCR : air-gap parfait.

FROM --platform=$BUILDPLATFORM gcc:13 AS builder

ARG LLAMACPP_BUILD=b10600

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch ${LLAMACPP_BUILD} https://github.com/ggml-org/llama.cpp.git

WORKDIR /src/llama.cpp
RUN cmake -B build -DGGML_NATIVE=ON -DLLAMA_CURL=OFF \
    && cmake --build build --config Release -j$(nproc)

FROM debian:13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/llama.cpp/build/bin/llama-server /usr/local/bin/
COPY --from=builder /src/llama.cpp/build/bin/llama-cli /usr/local/bin/

EXPOSE 8081

ENTRYPOINT ["llama-server"]
