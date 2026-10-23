# FARCI — Guide de contribution

## Flux Git

1. **Branche** : créer une branche depuis `main` (`feat/equipe-X/...`)
2. **Commit** : messages en français, format `type: description`
3. **PR** : créer une Pull Request vers `main`
4. **Revue** : au moins 1 review avant merge

## Deux forges, une seule source de vérité

| Forge | Rôle | Qui écrit sur `main` |
|---|---|---|
| **GitHub** (`origin`) | **source de vérité** du dépôt | une PR relue et fusionnée par un humain |
| **Gitea** (salle, équipe 0) | copie de travail pendant la séance | **personne** à la main : `./bin/farci forge-sync` seulement |

- Gitea `main` ne reçoit que GitHub `main`, **en avance rapide** :

  ```bash
  ./bin/farci forge-sync status               # identiques, en retard, divergents ?
  ./bin/farci forge-sync push                 # Gitea main ← GitHub main
  ./bin/farci forge-sync bundle farci.bundle  # salle sans Internet : sur clé USB
  ./bin/farci forge-sync from-bundle farci.bundle
  ```

- Pendant la séance, les PR des équipes sur Gitea visent une **branche de
  séance** (`seance`), pas `main`.
- Si Gitea `main` a divergé, la synchronisation est **refusée** (jamais de
  force). Ce qui mérite d'être gardé remonte par une PR GitHub :
  `./bin/farci forge-sync rapatrier <branche>`, puis `git push origin
  depuis-gitea/<branche>` et une PR. Au `push` suivant, Gitea rattrape GitHub.

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

### Automatisation en fin de session

**À la fin de chaque session de travail, les actions suivantes sont exécutées
automatiquement :**

1. **Pull** : `git pull origin main` pour synchroniser la branche avec `main`
2. **Commit** : tous les changements sont commités automatiquement
3. **Push** : la branche est poussée vers le distant
4. **PR** : une Pull Request est créée automatiquement vers `main`

```bash
# Fin de session — à exécuter automatiquement
git pull origin main
git add .
git commit -m "feat: description de la session"
git push origin feat/ma-fonctionnalite
# Création de la PR via l'API Gitea (adresse et secret lus dans la configuration)
source scripts/dev-env.sh && farci_load_env
curl -X POST "$GITEA_URL/api/v1/repos/FARCI/farci/pulls" \
  -H "Content-Type: application/json" \
  -u "farci-admin:$GITEA_ADMIN_PASSWORD" \
  -d '{
    "title": "feat: description de la session",
    "head": "feat/ma-fonctionnalite",
    "base": "main"
  }'
```

> **Note** : la PR est créée automatiquement, mais le merge reste **manuel**
> et réservé à un **utilisateur humain**.

### Résumé obligatoire dans la PR

Chaque Pull Request créée par l'agent codeur **doit contenir un résumé structuré**
pour aider l'humain qui valide le merge à comprendre et vérifier le travail.

Le résumé doit inclure :

1. **Objectif** : ce que la branche accomplit (une phrase)
2. **Fichiers modifiés** : liste des fichiers créés ou modifiés
3. **Points clés** : décisions techniques, choix d'implémentation
4. **Vérifications** : tests effectués, commandes exécutées
5. **Impact** : ce qui change pour les utilisateurs

Exemple de template :

```markdown
## Résumé

**Objectif** : [description courte]

**Fichiers modifiés** :
- `fichier1` : [description]
- `fichier2` : [description]

**Points clés** :
- [décision 1]
- [décision 2]

**Vérifications** :
- [x] `./bin/farci ci` est vert (selftest, lint, tests unitaires, gold)
- [x] [autre test]

**Impact** : [description de l'impact]
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
- Les tests doivent passer avant merge : `./bin/farci ci` (c'est exactement
  ce que la CI exécute, en local comme sur le runner)
- Toute commande citée dans la documentation doit exister
  (`./bin/farci lint-commands`) et se lancer depuis la racine du dépôt
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
├── 05-observability/   # Phoenix, Langfuse, OTel
├── 06-evaluation/      # métriques, MLflow
├── 07-applications/    # Python, Open WebUI, Flowise
├── 08-arcane-agents/   # agents de supervision, webhook GitOps
├── chaos/              # Chaos engineering
├── datasets/           # Dataset synthétique
├── docs/               # Documentation
├── scripts/            # Scripts bash
└── tests/              # Tests
```
