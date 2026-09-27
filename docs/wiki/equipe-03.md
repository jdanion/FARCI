# Équipe 3 — LLM Gateway (LiteLLM, Bifrost)

## Attendus pédagogiques

- Comprendre le rôle d'une gateway LLM (masquage, rate limiting, fallback)
- Comprendre la notion d'alias de modèle logique
- Comprendre pourquoi le gateway est le "mur anti-raisonnement"
- Comprendre la différence entre LiteLLM et Bifrost
- Savoir tester le contrat gateway

## Solution simple (scripts)

```bash
# 1. Démarrer LiteLLM
cd 03-llm-gateway/litellm
docker compose up -d

# 2. Bootstrap des clés
./bootstrap-keys.sh

# 3. Tester le contrat
IMPL=litellm ./tests/test_gateway_contract.sh

# 4. Tester le failover
./failover/demo-failover.sh
```

## Solution from scratch

### 1. Démarrer LiteLLM

```bash
docker run -d \
  --name farci-litellm \
  --network farci \
  -p 4000:4000 \
  -v $(pwd)/config.yaml:/app/config.yaml:ro \
  -v litellm-data:/data \
  ghcr.io/berriai/litellm:1.102.1 \
  --config /app/config.yaml --port 4000
```

### 2. Créer une clé API

```bash
curl -X POST http://192.168.50.30:4000/key/generate \
  -H "Authorization: Bearer sk-priority-placeholder" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "standard",
    "rpm_limit": 10
  }'
```

### 3. Tester l'authentification

```bash
# Sans clé → 401
curl -X POST http://192.168.50.30:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'

# Avec clé → 200
curl -X POST http://192.168.50.30:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-xxx" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'
```

### 4. Tester le rate limiting

```bash
# 12 requêtes rapides → certaines en 429
for i in $(seq 1 12); do
  curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST http://192.168.50.30:4000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer sk-standard-xxx" \
    -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}'
done
```

### 5. Tester le fallback

```bash
# Coupure du primaire
docker stop farci-ollama

# Le gateway doit répondre 200 avec x-fallback-applied: true
curl -X POST http://192.168.50.30:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-xxx" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'
```

## Vérifications

- [ ] LiteLLM répond sur :4000
- [ ] Authentification requise (401 sans clé)
- [ ] Rate limiting actif (429 après 10 RPM)
- [ ] Fallback fonctionnel (200 + x-fallback-applied)
