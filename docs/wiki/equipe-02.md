# Équipe 2 — Inférence (Ollama, llama.cpp, oMLX)

## Attendus pédagogiques

- Comprendre la différence entre un modèle et un runtime
- Comprendre ce qu'est un fichier GGUF et la quantification
- Comprendre la notion de contrat d'inférence (API OpenAI-compatible)
- Comprendre pourquoi `reasoning_content` est un problème et comment le gérer
- Savoir comparer deux runtimes à poids constants

## Solution simple (scripts)

```bash
# 1. Démarrer Ollama
cd 02-inference/ollama
docker compose up -d

# 2. Importer les modèles
./create-model.sh

# 3. Démarrer llama.cpp
cd ../llamacpp
docker compose up -d

# 4. Vérifier le contrat
BASE_URL=http://192.168.50.20:8080/v1 ./tests/test_inference_contract.sh
```

## Solution from scratch

### 1. Démarrer Ollama

```bash
docker run -d \
  --name farci-ollama \
  --network farci \
  -p 8080:8080 \
  -e OLLAMA_HOST=0.0.0.0:8080 \
  -e OLLAMA_KEEP_ALIVE=-1 \
  -e OLLAMA_NO_CLOUD=1 \
  -v /srv/farci/offline/models:/models:ro \
  -v ollama-data:/root/.ollama \
  ollama/ollama:0.34.4
```

### 2. Importer un modèle GGUF

```bash
# Créer un Modelfile
cat > Modelfile << 'EOF'
FROM /models/Ornith-1.5-9B-Q5_K_M.gguf
PARAMETER temperature 0
PARAMETER num_ctx 8192
EOF

# Importer dans Ollama
curl -X POST http://192.168.50.20:8080/api/create \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ornith-1.5-9b-q5km",
    "modelfile": "FROM /models/Ornith-1.5-9B-Q5_K_M.gguf\nPARAMETER temperature 0\n"
  }'
```

### 3. Démarrer llama.cpp

```bash
docker run -d \
  --name farci-llamacpp \
  --network farci \
  -p 8081:8081 \
  -v /srv/farci/offline/models:/models:ro \
  -v $(pwd)/grammar:/app/grammar:ro \
  farci/llamacpp:server-b10600 \
  llama-server \
  --model /models/Ornith-1.5-9B-Q5_K_M.gguf \
  --host 0.0.0.0 \
  --port 8081 \
  --ctx-size 8192 \
  --n-gpu-layers 0 \
  --threads 4 \
  --jinja \
  --reasoning off \
  --grammar-file /app/grammar/clinical.gbnf
```

### 4. Tester le contrat

```bash
# Lister les modèles
curl http://192.168.50.20:8080/api/tags

# Healthcheck
curl http://192.168.50.21:8081/health

# Complétion
curl -X POST http://192.168.50.20:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ornith-1.5-9b-q5km",
    "messages": [{"role": "user", "content": "test"}],
    "temperature": 0,
    "max_tokens": 16
  }'
```

### 5. Gérer reasoning_content

```bash
# Ollama : think: false
curl -X POST http://192.168.50.20:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ornith-1.5-9b-q5km",
    "messages": [{"role": "user", "content": "test"}],
    "think": false
  }'

# llama.cpp : --reasoning off (déjà dans la commande)
```

## Vérifications

- [ ] Ollama répond sur :8080
- [ ] llama.cpp répond sur :8081
- [ ] Contrat respecté (models, chat/completions, health)
- [ ] reasoning_content neutralisé
