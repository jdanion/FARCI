# TUTORIAL — Équipe 2 : Inférence

## Objectif

Mettre en place les runtimes d'inférence (Ollama, llama.cpp, oMLX) qui
servent les modèles GGUF du workshop.

## Architecture

```
                    ┌─────────────────┐
                    │   LLM Gateway   │
                    │  (LiteLLM)      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐ ┌───▼────────┐ ┌──▼────────┐
     │ Ollama         │ │ llama.cpp  │ │ oMLX      │
     │ :8080          │ │ :8081      │ │ :8082     │
     └────────┬───────┘ └───┬────────┘ └──┬────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────┐
                    │  Poids GGUF     │
                    │  (partagés)     │
                    └─────────────────┘
```

## Prérequis

- Modèles téléchargés (`./preload.sh --core`)
- Réseau `farci` créé
- Variables d'environnement configurées

## Démarrage

### Ollama

```bash
cd 02-inference/ollama
docker compose up -d
./create-model.sh
```

### llama.cpp

```bash
cd 02-inference/llamacpp
docker compose up -d
```

### oMLX (Mac uniquement)

```bash
cd 02-inference/omlx
./install-mlx.sh
sudo cp farci-omlx.service /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/farci-omlx.service
```

## Vérification

```bash
# Ollama
curl http://192.168.50.20:8080/api/tags

# llama.cpp
curl http://192.168.50.21:8081/health

# Contrat
BASE_URL=http://192.168.50.20:8080/v1 ./tests/test_inference_contract.sh
```

## Benchmark

```bash
./bench/bench.sh ornith-1.5-9b-q5km q5km http://192.168.50.20:8080/v1
```

## Dépannage

### Ollama ne démarre pas

```bash
docker logs farci-ollama
```

### llama.cpp : modèle non trouvé

Vérifier que les GGUF sont dans `$FARCI_MODELS_DIR` et montés dans le conteneur.

### oMLX : architecture non supportée

```
ValueError: Architecture qwen3_5 not supported
```

→ Mettre à jour `mlx-lm` : `pip install --upgrade mlx-lm mlx-vlm`
