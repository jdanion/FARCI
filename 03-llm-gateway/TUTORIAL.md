# TUTORIAL — Équipe 3 : LLM Gateway

## Objectif

Mettre en place la gateway LLM qui masque les runtimes et expose un contrat
OpenAI-compatible unifié.

## Architecture

```
Application
    │
    ▼
┌─────────────────┐
│  LLM Gateway    │  ← masque les runtimes
│  (LiteLLM)      │  ← rate limiting, fallback
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 Ollama   llama.cpp
 (primaire) (fallback)
```

## Démarrage

### LiteLLM

```bash
cd 03-llm-gateway/litellm
docker compose up -d
```

### Bifrost (alternative)

```bash
cd 03-llm-gateway/bifrost
docker compose up -d
```

## Bootstrap des clés

```bash
cd 03-llm-gateway/litellm
./bootstrap-keys.sh
```

## Test du contrat

```bash
IMPL=litellm ./tests/test_gateway_contract.sh
```

## Test de failover

```bash
./failover/demo-failover.sh
```

## Dépannage

### LiteLLM ne démarre pas

```bash
docker logs farci-litellm
```

### Clé API invalide

Régénérer la clé via `bootstrap-keys.sh` ou l'UI LiteLLM.
