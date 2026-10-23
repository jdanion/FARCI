# Équipe 2 — Inférence (Ollama, llama.cpp, oMLX)

## Attendus pédagogiques

- Comprendre la différence entre un modèle et un runtime
- Comprendre ce qu'est un fichier GGUF et la quantification
- Comprendre la notion de contrat d'inférence (API OpenAI-compatible)
- Comprendre pourquoi `reasoning_content` est un problème et comment le gérer
- Savoir comparer deux runtimes à poids constants

## Solution simple (scripts)

```bash
# 1. Démarrer Ollama et importer les poids
./bin/farci up 02-inference/ollama
02-inference/ollama/create-model.sh

# 2. Bonus : llama.cpp sur le même fichier de poids
./bin/farci up 02-inference/llamacpp

# 3. Vérifier : ligne Inference Primary verte, test inference-contract PASS
./bin/farci status
./bin/farci test
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Démarrer Ollama

```bash
docker run -d \
  --name farci-ollama \
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
curl -X POST $INFERENCE_A_URL/api/create \
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
curl $INFERENCE_A_URL/api/tags

# Healthcheck
curl $INFERENCE_B_URL/health

# Complétion
curl -X POST $INFERENCE_A_URL/v1/chat/completions \
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
curl -X POST $INFERENCE_A_URL/v1/chat/completions \
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
