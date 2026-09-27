# FARCI — Ollama : CPU vs GPU

## CPU

Ollama fonctionne sur CPU pour les petits modèles (≤ 2B paramètres).
Pour les modèles plus grands (9B, 27B), la latence est élevée mais reste utilisable
pour les tests.

```bash
OLLAMA_GPU_LAYERS=0 docker compose up -d
```

## GPU (NVIDIA)

Ollama détecte automatiquement CUDA. Vérifier avec :

```bash
docker exec farci-ollama ollama info
```

## GPU (AMD)

```bash
docker compose -f docker-compose.yml -f docker-compose.amd.yml up -d
```

## Apple Silicon

Ollama utilise Metal automatiquement sur Mac M1/M2/M3.

## Performance attendue

| Modèle | CPU (tokens/s) | GPU (tokens/s) |
|---|---|---|
| Qwen3.5-2B | ~5-10 | ~50-100 |
| Ornith-1.5-9B | ~1-3 | ~20-50 |
| Qwen3.8-27B | ~0.5-1 | ~10-30 |
