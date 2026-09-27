# FARCI — oMLX (option C, Mac uniquement)

## Qu'est-ce que oMLX ?

oMLX est un runtime d'inférence optimisé pour Apple Silicon (Metal).
Il utilise MLX, le framework ML d'Apple, pour exécuter les modèles GGUF
sur GPU Metal.

## Pourquoi pas Docker ?

MLX nécessite un accès direct à Metal (GPU Apple). Docker sur Mac ne permet
pas cet accès. oMLX s'exécute donc **hors conteneur**, via `launchd`.

## Installation

```bash
# Prérequis : Python 3.11+ et Homebrew
brew install python@3.11

# Installer MLX et les dépendances
pip install mlx mlx-lm mlx-vlm

# Télécharger le modèle (ou utiliser les poids partagés)
mlx_lm.generate --model /models/Ornith-1.5-9B-Q5_K_M.gguf --prompt "test"
```

## Démarrage du serveur

```bash
# En tant que service launchd
./farci-omlx-service start

# Ou manuellement
mlx_lm.server --model /models/Ornith-1.5-9B-Q5_K_M.gguf --port 8082
```

## Configuration

Le service écoute sur `0.0.0.0:8082` et expose le contrat OpenAI-compatible
(`/v1/chat/completions`).

## Limitations

- **Mac uniquement** : ne fonctionne pas sur Linux/Windows
- **Pas de conteneur** : gestion via launchd
- **RAM unifiée** : nécessite ≥ 16 Go pour Ornith-1.5-9B, ≥ 32 Go pour Qwen3.8-27B

## Troubleshooting

### `mlx-lm` ne supporte pas l'architecture hybride

```
ValueError: Architecture qwen3_5 not supported
```

→ Utiliser `mlx-vlm` ou une version récente de `mlx-lm` qui supporte
les architectures hybrides (Gated DeltaNet + attention).

### Mémoire insuffisante

```
Metal error: Insufficient memory
```

→ Réduire `--max-tokens` ou utiliser un modèle plus petit (Qwen3.5-2B).
