# FARCI — Guide de contribution

## Flux Git

1. **Branche** : créer une branche depuis `main` (`feat/equipe-X/...`)
2. **Commit** : messages en français, format `type: description`
3. **PR** : créer une Pull Request vers `main`
4. **Revue** : au moins 1 review avant merge

## Convention de commit

```
type: description
```

Types : `feat`, `fix`, `docs`, `chore`, `test`, `refactor`

## Règles

- `main` est protégée : pas de push direct
- Les tests doivent passer avant merge
- Aucun secret dans les fichiers (utiliser `.env`)
- Les artefacts lourds (images, modèles) vont dans `$FARCI_DATA_DIR`

## Structure du dépôt

```
farci/
├── 00-gitops/          # Gitea + runner
├── 01-network-dashboard/ # Caddy, Uptime Kuma, health-aggregator
├── 02-inference/       # Ollama, llama.cpp, oMLX
├── 03-llm-gateway/     # LiteLLM, Bifrost
├── 04-clinical-documents/ # Docling, pseudonymisation
├── 05-observability/  # Phoenix, Langfuse, OTel
├── 06-evaluation/      # MLflow, métriques
├── 07-applications/    # Python, Open WebUI, Flowise
├── chaos/              # Chaos engineering
├── datasets/           # Dataset synthétique
├── docs/               # Documentation
├── scripts/            # Scripts bash
└── tests/              # Tests
```
