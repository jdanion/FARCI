# FARCI — Guide de contribution

## Flux Git

1. **Branche** : créer une branche depuis `main` (`feat/equipe-X/...`)
2. **Commit** : messages en français, format `type: description`
3. **PR** : créer une Pull Request vers `main`
4. **Revue** : au moins 1 review avant merge

## Règle obligatoire : branche + PR humaine

**Toute modification de code du projet doit passer par une nouvelle branche.**
Aucun push direct sur `main` n'est autorisé.

**Le travail de session se termine par une demande de Pull Request.**
La PR est ensuite validée **uniquement par un utilisateur humain** — pas par un agent,
pas par un workflow automatique, pas par un bot.

### Procédure

```bash
# 1. Créer une branche
git checkout -b feat/ma-fonctionnalite

# 2. Committer
git add .
git commit -m "feat: description"

# 3. Pousser
git push origin feat/ma-fonctionnalite

# 4. Créer la PR (via l'interface Gitea ou l'API)
# 5. Attendre la revue humaine
# 6. Merge manuel par un humain après approbation
```

### Interdictions

- ❌ Push direct sur `main`
- ❌ Merge automatique (auto-merge)
- ❌ Merge par un agent ou un bot
- ❌ Merge sans revue humaine

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
