# Équipe 3 — LLM Gateway (LiteLLM, Bifrost)

## Attendus pédagogiques

- Comprendre le rôle d'une gateway LLM (masquage, rate limiting, fallback)
- Comprendre la notion d'alias de modèle logique
- Comprendre pourquoi le gateway est le "mur anti-raisonnement"
- Comprendre la différence entre LiteLLM et Bifrost
- Savoir tester le contrat gateway

## Solution simple (scripts)

```bash
# 1. Démarrer LiteLLM et créer les clés virtuelles
./bin/farci up 03-llm-gateway/litellm
03-llm-gateway/litellm/bootstrap-keys.sh

# 2. Vérifier : ligne LLM Gateway verte, test gateway-contract PASS
./bin/farci status
./bin/farci test

# 3. Démonstration du repli
03-llm-gateway/failover/demo-failover.sh
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

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
curl -X POST $GATEWAY_A_URL/key/generate \
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
curl -X POST $GATEWAY_A_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'

# Avec clé → 200
curl -X POST $GATEWAY_A_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-xxx" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'
```

### 4. Tester le rate limiting

```bash
# 12 requêtes rapides → certaines en 429
for i in $(seq 1 12); do
  curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST $GATEWAY_A_URL/v1/chat/completions \
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
curl -X POST $GATEWAY_A_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-xxx" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'
```

## Vérifications

- [ ] LiteLLM répond sur :4000
- [ ] Authentification requise (401 sans clé)
- [ ] Rate limiting actif (429 après 10 RPM)
- [ ] Fallback fonctionnel (200 + x-fallback-applied)
