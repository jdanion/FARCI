# FARCI — Plan d'implémentation étape par étape

> Plan d'exécution dérivé de `FARCI.md`.
> Objectif : produire **le dépôt entier, fonctionnel, air-gapped**, fichier par fichier.
> Chaque phase est autonome, testable, et se termine par un commit + une PR.

---

## 0. Analyse de l'environnement (constats réels)

Vérifié sur la machine de développement :

| Élément | État | Conséquence sur le plan |
|---|---|---|
| OS | Debian 13 (trixie) | base des images `debian:13-slim` pour nos services internes |
| Docker | 29.8.1 | OK |
| Docker Compose | v5.5.1 (plugin) | OK — syntaxe `compose.yaml` + `profiles` |
| Python | 3.13.5 | cible `python:3.13-slim` pour tous nos services |
| `pip3` | **ABSENT** | à installer via `python -m ensurepip` / apt (phase 0) |
| `make` | **ABSENT** | bloquant pour §47 → à installer en préchargement +Provideur de fallback `scripts/*.sh` |
| `jq` | **ABSENT** | les tests bash **ne doivent pas** dépendre de `jq` → helper JSON en `python3` stdlib |
| `unzip`, `shellcheck` | ABSENTS | goldens packs en `.tar.gz` (pas `.zip`) ; shellcheck optionnel |
| Internet | disponible | utile pour `preload.sh` (phase 1) |
| RAM / CPU | 2 Go / 5 cœurs | le modèle par défaut de dev doit être `small` (~1.7B) ; `medium` réservé aux postes étudiants |
| Disque libre | 12 Go | voir §0.1 : le dépôt ne stocke **jamais** de poids ni d'images |
| RAM | 2 Go | un 9B Q4_K_M exige ~8 Go → la machine de dev **ne peut pas** exécuter le modèle ; validation LLM sur poste ≥ 16 Go |

**Décision structurante** : le dépôt ne doit dépendre d'aucun outil absent de l'image de base.
→ règle n°0 : *« si ce n'est pas dans la stdlib Python 3.13 ou dans une image Docker préchargée, ce n'est pas dans le dépôt. »*

---

## 0.1 Décision figée n°1 — le dépôt Git reste léger

### Principe

**Dans Git : du texte, du code, des petits fichiers de données synthétiques.
Hors Git : tout ce qui est lourd et remplaçable** (images Docker, poids de modèles,
wheels Python, archives).

Budget du dépôt : **< 8 Mo**. Budget de `git clone` pour un étudiant : instantané.

### Mécanisme

| Élément | Emplacement | Dans Git ? |
|---|---|---|
| Code, docs, YAML, prompts, schémas | `farci/` | ✅ oui |
| PDFs synthétiques (80 fichiers ≈ 1–2 Mo) | `datasets/raw/` | ✅ oui (le dataset fait partie de la méthode) |
| Gold standard | `datasets/gold/` | ✅ oui |
| Extractions étudiantes | `datasets/extracted/` | ❌ non (`.gitignore`, §53) |
| Pseudonymisés | `datasets/pseudonymized/` | ❌ non (dérivé) |
| Images Docker | `$FARCI_DATA_DIR/offline/images/` | ❌ non |
| Poids de modèles | `$FARCI_DATA_DIR/offline/models/` | ❌ non |
| Wheels Python | `$FARCI_DATA_DIR/offline/wheels/` | ❌ non |
| `MANIFEST.sha256` | `$FARCI_DATA_DIR/offline/MANIFEST.sha256` | ❌ non |

```bash
# .env (défaut, modifiable)
FARCI_DATA_DIR=/srv/farci          # ou $HOME/.farci, ou un disque externe USB
```

`bootstrap.sh` crée un **lien symbolique** pour que les chemins imposés par le
cahier des charges (§10 `offline/wheels/`, §51 `offline/MANIFEST.sha256`) restent
valides :

```bash
ln -s "${FARCI_DATA_DIR}/offline" offline        # dépôt allégé, chemins du spec
```

Puis `offline/` est un dossier **vide côté Git** : on ne commite que
`offline/.gitignore` + `offline/README.md`.

```gitignore
# offline/.gitignore   (commité)
*
!.gitignore
!README.md

# .gitignore racine (commité)
.env
config/network.env
config/workshop.env
offline/
datasets/extracted/
datasets/pseudonymized/
.chaos/
*.tar *.tar.gz *.gguf *.safetensors *.whl
.mlflow/  .cache/  .venv/
```

### Conséquences à assumer (et à documenter)

1. `git clone` seul **ne suffit pas** : il faut le `FARCI_DATA_DIR` (clé USB / disque
   réseau du formateur). C'est cohérent avec le §60 (`preload.sh` puis
   `verify-airgap.sh`), mais cela doit être écrit noir sur blanc dans le README et
   l'INSTRUCTOR_GUIDE, sinon les étudiants perdent 20 minutes.
2. `offline/` n'est pas versionné → **le manifeste est lui aussi hors Git** (§51 est
   respecté sur le chemin, pas dans l'historique). `make verify-manifest` fonctionne
   dès que `bootstrap.sh` a établi le lien.
3. Un `FARCI_DATA_DIR` par poste (clé USB de 128 Go pour l'instructeur,
   disque local pour les étudiants) → pas de contention réseau à l'étape 1.
4. Gain : un commit d'extraction d'un étudiant ne fait jamais grossir le dépôt ;
   `git gc` n'a rien à compacter.

---

## 0.2 Décision figée n°2 — les deux modèles du workshop

Sélection **vérifiée** le 2026-09-26 (tailles réelles, licences, formats disponibles).

| Rôle | Modèle | Taille | Licence | Formats confirmed |
|---|---|---|---|---|
| **Principal** (commun à tous, §9) | **Ornith-1.5-9B** — dense 8.95B, arch hybride Qwen3.5 (32 couches : Gated DeltaNet + attention pleine tous les 4 rangs), 262k de contexte natif | Q4_K_M **5,9 Go** · Q5_K_M 6,5 Go · Q8_0 9,5 Go · BF16 17,9 Go | **MIT** | GGUF officiel `ornith-ai/Ornith-1.5-9B-GGUF` · Ollama `ornith-1.5:9b` (6,6 Go) · MLX `ornith-ai/Ornith-1.5-9B-MLX-8bit` · vision `mmproj` 0,92 Go |
| **Comparaison / Mac & gros GPU** | **Qwen3.8-27B** — 27,8B, 64 couches (48 GDN + 16 attention), 262k → 1M, **MTP** (décodage spéculatif), vision native | Q4_K_M **16,5–17,8 Go** · IQ3_M 12,6 Go · Q2_K 11,1 Go | **Apache-2.0** (à confirmer sur la carte de la version figée) | GGUF `unsloth/` `bartowski/` `qtum/Qwen3.8-27B-GGUF` · Ollama `qwen3.8:27b` (18 Go) · MLX `Chungulus/Qwen3.8-27B-MLX-4bit` (16,9 Go → 64 Go de RAM unifiée) |
| **CI / machine de dev** (hors méthode scientifique) | **Qwen3.5-2B** | Q4 ≈ 1,2 Go | Apache-2.0 (à confirmer) | GGUF · Ollama `qwen3.5:2b` |

### Trois conséquences fortes qu'il faut assumer dans la conception

**(a) Les deux modèles sont des *reasoning models*.** Ils ouvrent leur réponse par un
bloc de raisonnement. Conséquence technique **majeure** : le contrat d'inférence et le
contrat gateway doivent traiter `reasoning_content` comme un champ à part ; le JSON
structuré ne se lit **que** dans `content`. Sinon Pydantic échoue et l'étape 2
échoue. C'est un ajout au plan (§Phase 4) et un excellent support pédagogique :
*« un contrat qui ignore un champ réellement produit casse l'interchangeabilité. »*
Sous Ollama, il faut en plus neutraliser le thinking natif (`think: false` côté
gateway) pour éviter le doublon de raisonnement.

**(b) La fenêtre §9 (small 1–2B / medium 3–4B) n'est pas respectée** : le plus petit
Ornith-1.5 fait 9B et le plus petit Qwen3.8 fait 27B. Conséquence : le 9B est la
bascule « tout le monde en CPU/GPU modeste », le 27B est réservé aux postes
**≥ 24 Go de VRAM ou Mac ≥ 32 Go**. On ajoute donc un troisième modèle minuscule,
`Qwen3.5-2B`, **exclusivement** pour la CI, les tests de contrat rapides et les
machines de dev — et il est **explicitement exclu du score final** (sinon on mélange
deux méthodes). C'est une déviation assumée du §9, à écrire dans le README.

**(c) Licence : deux régimes différents, c'est une leçon.** MIT (Ornith) vs
Apache-2.0 (Qwen3.8) : open-weight ne veut pas dire « sans condition ». Support
prêt pour l'équipe 0 / gouvernance (§53) : comparer les clauses, l'obligation
d'attribution, et le fait qu'un usage pédagogique n'est pas un usage commercial.

### Le choix qui fait la science : **un seul fichier GGUF pour deux runtimes**

On ne télécharge **jamais** deux fois les mêmes poids. `preload.sh` récupère le
`.gguf` une fois, puis :

- `llama.cpp` monte le fichier en volume ;
- `ollama create` l'importe depuis un `Modelfile` (`FROM /models/....gguf`).

Conséquence pédagogique : **comparer deux runtimes n'est un travail scientifique que
si les poids sont constants** (§59.7). Ici, Ollama et llama.cpp servent le même
fichier, bit pour bit → la seule variable qui change est le runtime. Le tag Ollama
officiel (`ornith-1.5:9b`, 6,6 Go) reste documenté comme alternative dans le
TUTORIAL, mais jamais utilisé comme source de poids du benchmark.



---

## 1. Vue d'ensemble des phases

| # | Phase | Sections FARCI couvertes | Sortie vérifiable |
|---|---|---|---|
| 0 | Socle du dépôt & outillage | 5, 47, 53 | `make help` fonctionne, lint OK |
| 1 | Air-gap : versions, preload, manifeste, **image llama.cpp compilée localement**, **poids (1 GGUF/modèle)** | 6, 7, 8, 9, 10, 51, 52 | `verify-airgap.sh` = OK en réseau coupé |
| 2 | Équipe 0 — GitOps (Gitea + runner + Actions) | 11, 55, 56 | push protégé, PR, workflow vert |
| 3 | Équipe 1 — Réseau, Caddy, dashboard, health-aggregator | 12, 13, 14, 48, 49 | `http://192.168.50.15/healthz` + `/status` |
| 4 | Équipe 2 — Inférence (contrat + Ollama + llama.cpp + oMLX, poids partagés, contrat `reasoning_content`) | 15, 16, 48 | `test_inference_contract.sh` vert sur 2 runtimes |
| 5 | Équipe 3 — LLM Gateway (contrat + LiteLLM + Bifrost + fallback) | 17, 18, 19 | `test_gateway_contract.sh` + `test_failover.sh` |
| 6 | Équipe 4 — Documents cliniques (Docling + pseudonymisation + schémas) | 20, 21, 26, 28 | `test_docling.sh` + golden de pseudonymisation |
| 7 | Équipe 5 — Observabilité (contrat OTel + Phoenix + Langfuse) | 22, 23 | `test_observability.sh` : 1 trace avec 7 attributs |
| 8 | Équipe 6 — Évaluation (MLflow + métriques + gold, matrice modèle × quant × runtime × prompt) | 24, 27, 34, 56 | `make evaluate` : tableau + runs MLflow |
| 9 | Étape 2 — Applications (common, Python, Open WebUI, Flowise) | 29, 30, 31, 32, 33 | 3 parcours → même JSON, même schéma |
| 10 | Dataset synthétique + gold standard | 25, 26, 27, 53 | 20 PDF + 20 gold JSON déterministes |
| 11 | Étape 3 — Chaos engineering (7 scénarios) | 35 → 43 | chaque scénario `apply`/`revert` |
| 12 | Suite de tests complète + CI | 54, 55 | `make test` : résumé, exit 0/1 |
| 13 | Documentation & tutors | 44, 45, 46, 50, 59, 61, 62 | 6 docs + 7 TUTORIALs conformes au gabarit |
| 14 | Recette finale bout-en-bout | 57, 58, 60 | scénario complet air-gap + permutation de briques |

**Chemin critique** : 0 → 1 → 3 → 4 → 5 → 7 → 9 → 11 → 14.
**Parallélisable** : 2 (indépendant), 6 (besoin du schéma de 6, pas du gateway), 8 (besoin gold de 10 → faire 10 avant 8), 10 (indépendant, peut démarrer dès la phase 0).

> Ordre recommandé réel : `0, 1, 10, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14`
> (le dataset est déterministe et générable sans infrastructure → on le fait tôt pour débloquer l'évaluation).

---

# PHASE 0 — Socle du dépôt & outillage

**Objectif** : un dépôt vide mais déjà conforme aux conventions, avec l'outillage de développement.

### Fichiers à créer

```
.gitignore
.editorconfig
Makefile                     # squelette : aide, lint, bootstrap, delegates vers scripts/
README.md                    # squelette §44 (texte final en phase 13)
CONTRIBUTING.md
.env.example
versions.env
config/network.env.example
config/workshop.env.example
config/services.yaml         # registre déclaratif des services (source de vérité dashboard)
docs/ARCHITECTURE.md         # squelette
docs/WORKSHOP_FLOW.md
docs/AIRGAP.md
docs/CONTRACTS.md
docs/CHAOS.md
docs/INSTRUCTOR_GUIDE.md
scripts/lib/common.sh        # helpers bash partagés (log, ip, wait_http, colors)
scripts/lib/json.sh          # jq-like via python3 stdlib
scripts/workshop-status.sh   # §49 (boîte ASCII FARCI WORKSHOP)
scripts/lint.sh
scripts/dev-env.sh           # charge .env + config/*.env, exporte variables
bin/farci                    # dispatcher: ./bin/farci <make-target>  (fallback sans make)
requirements.txt             # §10 (openai, pydantic, pandas, scikit-learn, otel, pytest…)
requirements-dev.txt         # shellcheck, ruff… (optionnel, réseau autorisé)
.gitea/PULL_REQUEST_TEMPLATE.md
.gitea/ISSUE_TEMPLATE/bug.md
CHANGELOG.md
```

### Décisions techniques

1. **Un seul mécanisme de configuration** : `scripts/dev-env.sh` est la seule source qui lit
   `.env` → `config/network.env` → `config/workshop.env` et exporte le résultat.
   Aucun fichier ne doit redéfinir une IP (§4 : *« aucune IP répétée dans le code source »*).
2. **`Makefile = façade mince** : chaque cible appelle `scripts/<x>.sh`.
   Conséquence : le dépôt fonctionne **sans `make`** (air-gap strict, voir §0).
3. **`config/services.yaml`** = source de vérité unique pour : IP, port, healthcheck,
   sonde Uptime Kuma, groupe de dashboard, équipe propriétaire.
   `scripts/gen-compose-env.py` le convertit en `.env` consumed par les compose.
4. **Gabarit TUTORIAL** : `docs/_templates/TUTORIAL.template.md` contenant **exactement**
   les 14 sections du §45 → chaque équipe remplit ce gabarit (cohérence garantie).

### Critère de fin
`./bin/farci help` et `make help` affichent la même liste ; `scripts/lint.sh` passe ;
`git status` propre après `git init` + commit initial.

---

# PHASE 1 — Air-gap : versions, préchargement, manifeste

**Objectif** : garantir que plus rien ne sera téléchargé le jour J (§7, §52).

### Fichiers à créer

```
preload.sh                   # --all --core --gitops --dashboard --inference-ollama …
verify-airgap.sh             # vérification stricte, mode --strict (coupe réseau)
versions.env                 # TOUTES les versions, tag fixe (jamais latest)
versions.lock.env            # généré : image@sha256 (produit par scripts/lock-digests.sh)
models/models.env            # URLs + sha256 des poids (GGUF / Ollama / MLX)
offline/README.md
scripts/preload_lib.sh
scripts/lock-digests.sh      # phase online uniquement
scripts/verify-images.sh
scripts/verify-wheels.sh
scripts/verify-models.sh
scripts/gen-manifest.sh      # → offline/MANIFEST.sha256
scripts/check-offline-policy.sh   # grep anti-CDN / anti-pull / anti-remote-URL
tools/                       # helpers hors runtime (jq, shellcheck, make) installers
```

### Contenu de `versions.env` (extrait, à figer)

```bash
GITEA_VERSION=1.24.6
GITEA_ACT_RUNNER_VERSION=0.2.13
CADDY_VERSION=2.10.0-alpine
UPTIME_KUMA_VERSION=1.1.13
OLLAMA_VERSION=0.32.15          # minimum requis pour l'entrée qwen3.8 dans la library
LLAMACPP_VERSION=b10600         # build number, PAS de tag semver (voir ci-dessous)
LITELLM_VERSION=v1.79.0
BIFROST_VERSION=v1.6.0
DOCLING_VERSION=0.16.0
PHOENIX_VERSION=0.23.0
LANGFUSE_VERSION=3.115.0
MLFLOW_VERSION=3.5.0
OPEN_WEBUI_VERSION=0.6.26
FLOWISE_VERSION=3.4.4
REDIS_VERSION=8.2.1-alpine
POSTGRES_VERSION=17.6-alpine
PYTHON_IMAGE=python:3.13.5-slim-bookworm
DEBIAN_IMAGE=debian:13-slim

# Modèles (cf. 0.2)
FARCI_MODEL_PRIMARY=ornith-1.5-9b-q5km   # 6.5 Go  — défaut de tous les ateliers
FARCI_MODEL_LARGE=qwen3.8-27b-q4km       # 16.5 Go — postes >= 24 Go ou Mac >= 32 Go
FARCI_MODEL_CI=qwen3.5-2b-q4km           # 1.2 Go  — CI et dev, hors score final
```
+ pour chaque entrée : `*_DIGEST=sha256:…` (rempli par `scripts/lock-digests.sh`).

### Décision sur llama.cpp (contournement d'un vrai problème)

L'image officielle `ghcr.io/ggml-org/llama.cpp:server` a **trois défauts rédhibitoires**
pour notre usage :

1. **pas de tag semver**, uniquement des build numbers (`server-b7139`, `server-b9853`) ;
2. certains build numbers **n'ont jamais d'image publiée** — le tag flottant peut donc
   casser le workshop sans que personne ne s'en aperçoive ;
3. **`linux/arm64` n'existe pas** pour l'image `server` → les étudiants sur Mac ou ARM
   ne pourraient pas lancer llama.cpp, alors que c'est précisément la cible de oMLX.

→ **On construit notre propre image multi-architecture pendant le préchargement** :

```bash
# preload.sh, phase online uniquement
curl -L -o "$SRC/llama.cpp-b10600.tar.gz" \
     "https://github.com/ggml-org/llama.cpp/archive/refs/tags/b10600.tar.gz"
sha256sum -c models/llama.cpp-b10600.tar.gz.sha256   # empreintes saisies en phase online
docker buildx build --platform linux/amd64,linux/arm64 \
  -t farci/llamacpp:server-b10600 -f 02-inference/llamacpp/Dockerfile --load .
docker save farci/llamacpp:server-b10600 -o "$OFFLINE/images/llamacpp-server-b10600.tar"
```

Bénéfices : air-gap parfait, support ARM64, et un `Dockerfile` **lisible par les
étudiants** (ils voient comment `llama-server` est compilé → l'option 2B du §15
devient concrète). L'image est donc construite **en local** plutôt que via un
`build:` distant → conforme au §52.

### Modèles (§9)

Sélection et motivations : voir **§0.2**. Règle de preload : **un seul fichier GGUF
par modèle**, monté par llama.cpp *et* importé par Ollama. `scripts/lock-models.sh`
enregistre les URL et les sha256 **réels** en phase online (jamais devinés) dans
`models/models.lock.env`.

Budget de disque :

| Groupe preload | Contenu | Taille |
|---|---|---|
| `--core` | gitops + dashboard + ollama + litellm + phoenix + docling + mlflow + clients + wheels | ~26 Go |
| `--models-ornith` | `Ornith-1.5-9B-Q5_K_M.gguf` (+ Q4_K_M pour l'expérience de quantification) | 6,5 Go (12,4 Go) |
| `--models-qwen38` | `Qwen3.8-27B-Q4_K_M.gguf` + `mmproj` | ~17,5 Go |
| `--models-ci` | `Qwen3.5-2B` Q4 | 1,2 Go |
| `--all` | tout | ~57 Go |


### `preload.sh` — structure

```bash
group_gitops()          # images gitea, runner, postgres, redis
group_dashboard()       # caddy, uptime-kuma
group_build_llamacpp()  # buildx multi-arch (amd64+arm64) depuis la source b10600
group_models_ornith()   # Ornith-1.5-9B Q5_K_M (+ Q4_K_M, + mmproj vision)
group_models_qwen38()   # Qwen3.8-27B Q4_K_M (+ mmproj)  -- 17,5 Go
group_models_ci()       # Qwen3.5-2B Q4  -- CI et dev uniquement
group_inference_ollama()   # image + import des GGUF déjà téléchargés (0 octet de poids)
group_inference_llamacpp() # image locale + montage des GGUF
group_gateway_litellm()  # image + config + clé master
group_gateway_bifrost()  # image
group_observability_*()  # phoenix / langfuse (+ clickhouse ou PG)
group_documents()        # docling-serve + wheels docling
group_evaluation()       # mlflow + artifacts local
group_clients()          # open-webui, flowise
group_wheels()           # pip download -> offline/wheels
group_manifest()         # offline/MANIFEST.sha256
group_tools()            # make, shellcheck, unzip
```
Options : `--all --core --models-<x> --only <g> --skip-existing --parallel N
--out <dir> --verify --dry-run`.
`--core` **inclut** `group_build_llamacpp` + `group_models_ornith` + `group_models_ci`
(c'est le strict nécessaire pour `make health` → pipeline READY).

### `verify-airgap.sh` — contrôles (§7.2, §52)

```
[1] required images présents localement (docker image inspect)   → jamais docker pull
[2] versions.env : aucun "latest", aucun tag vide, digests présents
[3] compose : aucun `build:` distant, aucun `pull_policy: always`
[4] wheels : installation --no-index --find-links=offline/wheels possible (dry-run)
[5] modèles : fichiers + sha256 conformes
[6] manifeste : sha256sum -c offline/MANIFEST.sha256
[7] politique offline : grep CDN / fonts / remote JS / URLs cloud dans 07-applications
[8] --strict : `unshare -rn` + rejeu de `make core-up` sans réseau
```

### Critère de fin
`./preload.sh --core` puis `unshare -rn ./verify-airgap.sh --strict` → exit 0.

---

# PHASE 10 (avancée) — Dataset synthétique + Gold standard

> Déplacée ici car elle ne dépend d'aucune infrastructure et débloque la phase 8.

**Objectif** : 20 dossiers synthétiques (10 « quick »), 4 types de documents, gold 100 % déterministe.

### Fichiers à créer

```
datasets/README.md
datasets/.gitkeep (raw/, pseudonymized/, gold/, extracted/)
datasets/tools/generate_dataset.py     # déterministe (seed=20260926)
datasets/tools/templates/*.md          # gabarits des 4 CRO/CR
datasets/tools/render_pdf.py           # fpdf2 (pur python) -> PDF
datasets/tools/build_gold.py           # gold depuis la source de vérité (jamais via LLM)
datasets/tools/make_quick_set.py       # sous-ensemble de 10 cas
datasets/schemas/clinical_extraction.schema.json   # source de vérité du schéma
datasets/gold_schema.md
tools/mkdocs_site/                      # non — hors périmètre
```

### Principes

1. **Source de vérité = un registre Python structuré** (`cases.py`) : 20 patients
   fictifs, valeurs cohérentes (pT/pN/marge_R/DGE corrélés, pas de hasard indépendant).
2. Le générateur rend **4 PDF par cas** : compte rendu opératoire, anatomopathologie,
   scanner, lettre de sortie.
3. `build_gold.py` écrit `datasets/gold/patient_XXX.json` **depuis le registre**, pas depuis
   un LLM (§27 : *« aucune donnée du gold ne doit être générée dynamiquement par le LLM »*).
4. Les identifiants sont synthétiques mais **semblants réalistes** (IPP/NIR factices
   conformes au format) → la pseudonymisation a quelque chose à faire.
5. `git` conserve les PDF (petits) ; `datasets/extracted/` est gitignoré (§53).

### Variables extraites (§26) — schéma unique

`patient_id, age, sex, diagnosis, procedure_type, approach, venous_resection,
tumor_size_mm, histology, pT, pN, nodes_examined, nodes_positive, margin_R,
pancreatic_fistula, delayed_gastrojejunostomy, hemorrhage, length_of_stay, readmission`

Règles de codage documentées dans `datasets/gold_schema.md` (null vs 0 : **0 est une
valeur** ; absent = `null`) — c'est la principale source de désaccord étudiant/LLM,
donc un contenu pédagogique à part entière.

### Critère de fin
`python datasets/tools/generate_dataset.py` deux fois → sha256 identiques ;
`make test` vert sur le test de parité schéma/gold.

---

# PHASE 2 — Équipe 0 : GitOps

**Objectif** : forge Git + CI (§11), par la pratique.

### Fichiers à créer

```
00-gitops/docker-compose.yml
00-gitops/gitea/app.ini                    # template (GITEA__* env)
00-gitops/gitea/bootstrap.sh                # CLI gitea admin: create org/user/repo
00-gitops/gitea/auth-local.md               # strategie d'authentification locale
00-gitops/runner/register-runner.sh
00-gitops/runner/act_runner/config.yaml
00-gitops/TUTORIAL.md                      # gabarit §45
00-gitops/post-provision.sh                # branche main protégée + PR obligatoire
```

### Points techniques

1. Gitea en **PostgreSQL** (et non SQLite) → utile pédagogiquement (persistance,
   sauvegarde) ; `postgres` est déjà préchargé pour Langfuse/MLflow.
2. `app.ini` monté en read-only, secrets par `.env` (`GITEA__*`).
3. Branche `main` protégée : `post-provision.sh` → `gitea admin` + API
   `PATCH /repos/FARCI/farci/branches/main` (`dismiss_stale_reviews`,
   `enable_status_check`, `block_on_rejected_reviews`, `prevent_push`).
4. `act_runner` en conteneur avec le socket Docker monté (`--network farci-net`).
5. `.gitea/workflows/*.yml` (§12) : `lint` → `tests` → `contract` → `evaluate`.
6. Les secrets PR (clé gateway) sont des **secrets Gitea**, jamais des fichiers (§53).

### Critère de fin
`push` direct sur `main` rejeté ; une PR `feat/equipe-2/ollama` déclenche un workflow vert.

---

# PHASE 3 — Équipe 1 : Réseau, Caddy, dashboard, health-aggregator

### Fichiers à créer

```
01-network-dashboard/docker-compose.yml
01-network-dashboard/caddy/Caddyfile
01-network-dashboard/caddy/Dockerfile          # build local minimal, aucun CDN
01-network-dashboard/uptime-kuma/docker-compose.yml
01-network-dashboard/uptime-kuma/seed/monitors.json     # généré depuis services.yaml
01-network-dashboard/uptime-kuma/seed/seed.py            # client socket.io (stdlib pur)
01-network-dashboard/health-aggregator/Dockerfile
01-network-dashboard/health-aggregator/app.py             # stdlib http.server, zéro pip
01-network-dashboard/health-aggregator/requirements.txt   # vide / commentaire
01-network-dashboard/monitors/README.md
01-network-dashboard/monitors/grafana-dashboard.json     # optionnel, §49
01-network-dashboard/TUTORIAL.md
scripts/uptime-kuma-seed.sh
```

### Réseau (§4)

```yaml
networks:
  farci:
    name: farci
    ipam:
      config: [{ subnet: ${FARCI_SUBNET} }]   # 192.168.50.0/24
```
Une IP statique n'est écrite que dans `config/services.yaml` → `network.env`.
Compose de chaque équipe déclare `networks.farci.external: true`.

### Caddy (§12)

- Publiqué sur `0.0.0.0:80` (+443 si certificat local possible — **sinon HTTP only**,
  prioritization §61.1 : l'air-gap prime sur le TLS).
- Routes : `/v1/*` → gateway actif, `/docling/*`, `/observability/*`, `/mlflow/*`,
  `/kuma/*`, `/status` (health-aggregator), `/healthz` (agrégat léger), `/flowise/*`,
  `/webui/*`, `/gitea/*`.
- `handle_errors` renvoie un JSON explicite (utile pour l'étape 3 : le client comprend
  pourquoi ça échoue).
- **Choix pédagogique explicite** : Caddy ne fait PAS de load balancing entre gateways
  en v1 → la bascule gateway se fait par variable `GATEWAY_BACKEND` rechargée sans
  redémarrage (`caddy reload`), ce qui rend la permutation LiteLLM↔Bifrost visible
  en direct pendant le workshop (§41).

### `health-aggregator` (§14) — cœur de la étape 1

`app.py`, **stdlib uniquement** (`http.server` + `urllib` + `ThreadingHTTPServer`) :

- `GET /status` → agrège Caddy, gateway, ≥1 runtime, Docling, observabilité.
- Réponse :
  ```json
  {"status":"ready","required":{...},"optional":{...},"checked_at":"...","version":"1"}
  ```
  `"status": "ready"` **uniquement** si toute la chaîne minimale est UP (§14).
- `GET /healthz` → 200/503 rapide (sonde Uptime Kuma, pas de timeout long).
- Sources de vérité : `config/services.yaml` (chargé au démarrage), donc cohérent
  avec le dashboard.
- Testé par `tests/test_network.sh` (crash du backend → 503 → pipeline 🔴).

### Uptime Kuma (§13)

- Source de vérité `monitors.json`, généré par `scripts/gen-monitors.py` depuis
  `config/services.yaml` → 7 groupes + 14 sondes + sonde synthétique `CLINICAL AI PIPELINE`.
- Seed par `seed.py` (client socket.io **sans dépendance externe** : implémentation
  minimale du handshake, ou `python-socketio` ajouté aux wheels — décision à l'étape 1).
- Fallback documenté : checklist manuelle de création (si l'API socket change).

### Critère de fin
`curl http://192.168.50.15/status` → `{"status":"ready"}` une fois la chaîne montée ;
les 14 sondes existent dans les 7 bons groupes.

---

# PHASE 4 — Équipe 2 : Inférence

### Fichiers à créer

```
02-inference/CONTRACT.md                # §16
02-inference/ollama/docker-compose.yml
02-inference/ollama/entrypoint.sh
02-inference/ollama/Modelfile
02-inference/ollama/create-model.sh
02-inference/ollama/README-cpu-gpu.md
02-inference/llamacpp/docker-compose.yml
02-inference/llamacpp/Modelfile
02-inference/llamacpp/params.json        # --ctx-size, --n-gpu-layers, quant
02-inference/llamacpp/grammar/clinical.gbnf   # structured output natif llama.cpp
02-inference/omlx/README.md              # §15 option C, Mac uniquement
02-inference/omlx/install-mlx.sh
02-inference/omlx/docker-compose.yml     # profile: mac
02-inference/omlx/farci-omlx.service     # launchd (non conteneurisé: MLX)
02-inference/bench/bench.sh              # tokens/s CPU vs GPU (pédagogique)
02-inference/TUTORIAL.md
```

### `CONTRACT.md` (§16) — contenu normatif

```http
GET  /v1/models                     -> 200 { "object":"list", "data":[{ "id": "<model>" }] }
POST /v1/chat/completions           -> 200 { "id","object":"chat.completion","model",
                                         "choices":[{"index":0,"message":{"role","content"},
                                         "finish_reason"}],
                                         "usage":{"prompt_tokens","completion_tokens","total_tokens"} }
POST /v1/chat/completions (json_schema) -> JSON conforme au schéma, sinon 400 documenté
GET  /health | /healthz             -> 200
```

**Exigence ajoutée après vérification des modèles (indispensable) : `reasoning_content`**

Nos deux modèles (§0.2) sont des *reasoning models* : ils ouvrent leur réponse par un
bloc de raisonnement. Le contrat doit donc imposer :

```http
POST /v1/chat/completions
→ 200 {
    "choices":[{ "message":{
        "role":"assistant",
        "reasoning_content":"…rafraîchit…",   # OPTIONNEL, chaîne, peut être absent
        "content":"{\"patient_id\": … }"      # le JSON SEUL, sans raisonnement
    }}]
}
```
Règles :
1. `content` contient **uniquement** le JSON exploitable. Jamais de raisonnement
   mélangé, jamais de `` ```json ``, jamais de texte avant/après.
2. `reasoning_content`, s'il est présent, **doit** être refusé par le parseur JSON de
   l'application (testée : `tests/test_structured_output.py`).
3. Le gateway DOIT neutraliser le raisonnement (`think: false` côté Ollama,
   `--reasoning off` côté llama.cpp) pour l'extraction, et le **journaliser séparément**
   (utile en analyse d'erreur, interdit dans le gold).
4. Chaque implémentation se conforme par des moyens différents (parsing llama.cpp,
   paramètre Ollama, option Bifrost) → c'est exactement le travail de la gateway.

Exigences communes : `model` logique stable, `stream:false` supporté,
`temperature` respectée, 401 si clé requise, `X-Request-Id`/`traceparent` **propagés**
(→ §23 contrat OTel), **aucun appel sortant** (air-gap).

### `tests/test_inference_contract.sh`
Reçoit `BASE_URL` (§16), ne connaît ni le runtime ni le modèle attendu a priori :
il vérifie la **forme** de la réponse, la présence de `usage`, la stabilité du champ
`model` entre deux appels, l'isolation stricte de `reasoning_content`, le comportement
`temperature=0` (déterminisme faible mais structurel), et la latence.
Rapporte `PASS/FAIL/SKIP` + durée.

### Points clés
- **Poids partagés** (§0.2) : le même `.gguf` alimente llama.cpp (volume) et Ollama
  (`ollama create` depuis un `Modelfile`). Conséquence scientifique : comparer les
  runtimes à poids constants. `Ollama` : `OLLAMA_HOST=0.0.0.0:8080`,
  `OLLAMA_KEEP_ALIVE=-1`, `OLLAMA_NO_CLOUD=1`, et **aucun** `ollama pull` jamais.
- **llama.cpp** : `llama-server` avec `--jinja` (obligatoire pour le chat template de
  Ornith), `--reasoning off` pour l'extraction, GBNF de secours, `params.json`
  paramétré par env (`LLAMACPP_CTX_SIZE`, `LLAMACPP_GPU_LAYERS`, `LLAMACPP_THREADS`).
  Image **construite localement** (voir Phase 1) : pas de dépendance GHCR, ARM64 inclus.
- **oMLX** : hors Docker (Metal), derrière le réseau `farci` via un `launchd` + IP fixe
  `.22`, endpoint `/v1` conforme au même contrat. Attention : `mlx-lm` standard
  **n'implémente pas** l'architecture hybride `qwen3_5` → il faut `mlx-vlm`/`mlx-lm`
  récents ; c'est un *finding* à écrire dans le TUTORIAL, pas un bug d'étudiant.
- Aucune de ces 3 implémentations n'est obligatoire pour le reste (priorité §61.2).

### Expérience à forte valeur ajoutée (nouvelle, peu coûteuse)

`make bench-quant MODEL=ornith-1.5-9b QUANT=q4km,q5km,q8_0` → même prompt, même
gold, 3 F1 + 3 latences. Montre qu'**une quantification n'est pas un détail
d'implémentation mais un paramètre de la méthode** (§59.7), et fournit le premier
« avant/après » chiffré du workshop. Le second axe : `--think on|off` → mesure le
coût du raisonnement sur l'extraction.

### Critère de fin
`BASE_URL=http://192.168.50.20:8080/v1 ./tests/test_inference_contract.sh` → PASS
idem `.21`, `.22`.

---

# PHASE 5 — Équipe 3 : LLM Gateway

### Fichiers à créer

```
03-llm-gateway/CONTRACT.md              # §18
03-llm-gateway/model-aliases.env        # med-extraction, med-extraction-fast, med-slow
03-llm-gateway/litellm/config.yaml
03-llm-gateway/litellm/litellm_proxy_config.yaml   # alias, retries, fallbacks, rpm
03-llm-gateway/litellm/docker-compose.yml
03-llm-gateway/litellm/bootstrap-keys.sh          # research-standard / research-priority
03-llm-gateway/litellm/READMEmapping.md   # concepts LiteLLM -> termes FARCI
03-llm-gateway/bifrost/config.json
03-llm-gateway/bifrost/docker-compose.yml
03-llm-gateway/bifrost/bootstrap.sh
03-llm-gateway/caddy-snippets/litellm.conf
03-llm-gateway/caddy-snippets/bifrost.conf
03-llm-gateway/failover/demo-failover.sh
03-llm-gateway/TUTORIAL.md
```

### `CONTRACT.md` (§18) — le strict surcroît

```
GET  /v1/models                       -> SEULEMENT "med-extraction*" visible (§18)
POST /v1/chat/completions
Auth : Authorization: Bearer sk-...   -> 401 si absente/inconnue
      sk-standard  -> 10 RPM  -> 429 + Retry-After        (§38)
      sk-priority  -> 120 RPM
Headers observabilité : x-litellm-model-id / x-fallback-applied / x-litellm-attempt
                        (exposés par Bifrost de façon équivalente)
Comportement panne primary : réponse 200 servie par le secondaire, client inchangé (§19)
```

### Décisions
- Aliases **stricts et documentés** → l'application ne voit jamais
  `ornith-1.5-9b` ni `qwen3.8-27b`. Modèle logique unique : `med-extraction`.
- `med-extraction` (défaut) → Ollama primaire + llama.cpp fallback (mêmes poids) ;
  `med-extraction-lite` → `Qwen3.5-2B` (CI, tests rapides, exercices) ;
  `med-extraction-max` → `Qwen3.8-27B` (postes ≥ 24 Go, Mac ≥ 32 Go) ;
  `med-extraction-mac` → oMLX.
- **Le gateway est aussi le mur anti-raisonnement** : il coupe `reasoning_content`
  pour l'extraction et le stocke à part. Sans cela, Pydantic échoue et l'étape 2
  s'effondre sur les deux modèles choisis.
- `test_gateway_contract.sh` **paramétrable par implémentation** :
  `IMPL=litellm|bifrost`, mêmes assertions → c'est la démonstration de l'interchangeabilité.
- `test_failover.sh` : coupe le primaire, exige 200 + en-tête de fallback.

### Critère de fin
`./tests/test_gateway_contract.sh` vert sur les **deux** gateways avec la **même**
clé, le **même** alias, la **même** réponse utile.

---

# PHASE 6 — Équipe 4 : Documents cliniques & pseudonymisation

### Fichiers à créer

```
04-clinical-documents/docling/docker-compose.yml
04-clinical-documents/docling/entrypoint.sh
04-clinical-documents/docling/smoke.sh
04-clinical-documents/deidentification/__init__.py
04-clinical-documents/deidentification/rules.py        # regex FR : NIR, IPP, dates, tel, email, adresse
04-clinical-documents/deidentification/ner_rules.py     # prenoms/noms (listes fermées + heuristiques)
04-clinical-documents/deidentification/mapping.py       # [PATIENT_001], [DATE_001], [IPP_001]
04-clinical-documents/deidentification/cli.py
04-clinical-documents/deidentification/golden/         # avant/après attendus
04-clinical-documents/schemas/clinical_extraction.schema.json   # (miroir datasets/schemas)
04-clinical-documents/schemas/README.md                # règle null vs inventé
04-clinical-documents/TUTORIAL.md
tests/test_docling.sh
tests/test_deidentification.py
```

### Points techniques
1. **Docling** : image `docling-serve`, endpoint `POST /v1/convert/file` (§20),
   options `to_formats=md,json`, profil OCR désactivé par défaut (CPU).
   Sortie **structurée** (titres, paragraphes, tableaux) → `text/`,
   `content/markdown`, `content/json` pour inspection (§20).
2. **Pseudonymisation** (`deidentification/`) :
   - **déterministe** (mapping stable par document/patient), réutilisable
     (mapping sérialisé dans `datasets/pseudonymized/mapping.json`) ;
   - **ordre** : dates → identifiants Forts (IPP/NIR/SSN) → phones/emails → adresses
     → noms/prénoms (dictionnaire des prénoms français les fréquents + bigrammes) ;
   - **faux positifs** maîtrisés : tests unitaires sur 30 cas dont cas limites
     (« Mr. Jean », dates de dosage, nombres qui ressemblent à un NIR) ;
   - **rappel pédagogique** : la pseudonymisation n'efface pas le risque de
     ré-identification par quasi-identifiants (âge + sexe + date) → documenté dans
     `TUTORIAL.md` (gouvernance des données, §53).
3. **Schéma** : `clinical_extraction.schema.json` est la source de vérité ; §10 du plan
   (parité) garantira que Pydantic, le JSON Schema envoyé au LLM, le Flowise template
   et le gold sont **le même** contrat.

### Critère de fin
`test_docling.sh` convertit 1 PDF et vérifie la présence de titres/tableaux ;
`pytest tests/test_deidentification.py` 100 % ; le mapping est réversible côté
pseudonymes → gold (le pipeline est vérifiable bout en bout).

---

# PHASE 7 — Équipe 5 : Observabilité

### Fichiers à créer

```
05-observability/CONTRACT.md            # §23 — le vrai contrat est OTLP, pas Phoenix
05-observability/otel-config.env        # endpoints, service.name, resource attrs
05-observability/collector/docker-compose.yml   # otel-collector (facultatif, Toggle)
05-observability/collector/otel-collector.yaml
05-observability/phoenix/docker-compose.yml
05-observability/phoenix/entrypoint.sh
05-observability/langfuse/docker-compose.yml
05-observability/langfuse/.env.example         # clés de service
05-observability/langfuse/bootstrap.sh
05-observability/TUTORIAL.md
tests/test_observability.sh
tests/test_otel_contract.py
```

### `CONTRACT.md` (§23)

Une trace minimale **obligatoire** :
```
trace_id, service, operation, model, latency, status, error[, input_tokens, output_tokens]
```
+ attributs OTel `gen_ai.*` standards, `traceparent` propagé de bout en bout
(client → Caddy → gateway → runtime).

### Décisions
- **Deux backends, un seul code d'instrumentation** : `07-applications/common/observability.py`
  (OTel SDK) est écrit **une fois** et pointe vers `OTEL_EXPORTER_OTLP_ENDPOINT` ;
  Phoenix **et** Langfuse reçoivent le même flux (v3 accepte l'OTLP ingest).
- Le **collecteur OTel** est optionnel (profil `otel`), pour pouvoir parler du fan-out
  sans le rendre obligatoire (priorité §61.2).
- `tests/test_observability.sh` interroge l'API de Phoenix (et l'API Langfuse) et
  **exige** les 7 attributs → si une brique change, le test casse (contrat réel).
- Test de non-régression §42 : le pipeline doit fonctionner avec l'observabilité coupée
  (exporter en `none`/`console` → les spans ne doivent jamais bloquer le chemin critique :
  timeouts courts + failure callback silencieux).

### Critère de fin
1 requête `med-extraction` → trace visible avec `gen_ai.request.model` = `med-extraction`
(le gateway masque le vrai modèle → **les traces sont aussi un sujet de gouvernance**).

---

# PHASE 8 — Équipe 6 : Évaluation & MLflow

### Fichiers à créer

```
06-evaluation/mlflow/docker-compose.yml
06-evaluation/mlflow/entrypoint.sh
06-evaluation/mlflow/Dockerfile              # image MLflow + requirements pinés
06-evaluation/metrics/evaluate.py            # §34
06-evaluation/metrics/metrics.py             # exactitude champ par champ, micro P/R/F1
06-evaluation/metrics/normalize.py           # règles de normalisation (accents, unités, casse)
06-evaluation/metrics/report.py              # tableau lisible + export markdown/json
06-evaluation/gold-standard/README.md
06-evaluation/gold-standard/validate_gold.py
06-evaluation/TUTORIAL.md
tests/test_evaluation.py
```

### `evaluate.py` (§34)

```bash
make evaluate                       # tous les.datasets/extracted/* vs datasets/gold
make evaluate RUNS=python flowise   # sous-ensemble
```

Sorties :
```
nb_dossiers, completude, json_valides, exactitude_champ_par_champ,
precision, recall, F1, latence_moyenne (+ p50/p95)
```
Puis logging MLflow avec **exactement** les paramètres du §24 :
`model, runtime, gateway, prompt_version, temperature, dataset_version, latency,
valid_json_rate, precision, recall, f1`.

**Axes expérimentaux supplémentaires (issus du choix des modèles, §0.2)** — ce sont
eux qui font la différence entre « j'ai appelé une API » et « j'ai fait une
expérience » :

| Axe | Valeurs | Question pédagogique |
|---|---|---|
| `model` | `ornith-1.5-9b` / `qwen3.8-27b` | le modèle change-t-il la qualité des variables extraites ? |
| `quant` | `q4km` / `q5km` / `q8_0` | combien perd-on en compressant les poids ? |
| `runtime` | `ollama` / `llamacpp` / `omlx` | à poids constants, le runtime change-t-il le F1 ? (réponse attendue : non, mais si oui, c'est un bug de config à comprendre) |
| `thinking` | `on` / `off` | le raisonnement aide-t-il, coûte-t-il des tokens, casse-t-il le JSON ? |
| `prompt_version` | `v1` / `v2` | la méthode prime-t-elle sur le modèle ? (comparaison v1+9B vs v2+2B) |
| `schema_mode` | `json_schema` / `prompt_strict` / `gbnf` | quel mécanisme de contrainte est le plus sûr ? |

Chaque ligne est un **run MLflow** ; `make compare-runs` affiche un tableau croisé
F1 × latence. Le scénario signature du workshop devient donc :

```
ornith-9b + q4km + llamacpp + v1  -> F1 0.71
ornith-9b + q5km + llamacpp + v1  -> F1 0.79     <- la quantification coûte 8 points
ornith-9b + q5km + llamacpp + v2  -> F1 0.84     <- le prompt en gagne 5
qwen38-27b + q4km + llamacpp + v2 -> F1 0.88     <- le modèle en gagne 4
```
*(valeurs illustratives : les étudiants produisent les leurs, c'est la méthode qui
est montrée, pas le résultat)*

**Détection de régression** (`evaluate.yml`, §55) : comparaison au run de référence,
affichage du format attendu :
```
JSON validity       100 %
Extraction F1       0.84
Regression          none
```

### Règles d'évaluation (pédagogie §59.6)
- Champs **null attendus** : compter comme correct si prédit `null`
  (sinon le modèle est puni pour avoir bien dit « je ne sais pas »).
- Normalisation : casse, accents, unités (`20 mm` = `20`), `F1` = 0/1/2,
  booléens (`oui/non/true`), plages (`pT1b` → `pT1b`).
- Les métriques sont **micro** (tous les champs) + **macro par champ** (diagnostic).

### Critère de fin
`make evaluate` sur 3 runs (python/webui/flowise) produit un tableau comparable
et 3 runs MLflow consultables.

---

# PHASE 9 — Étape 2 : les trois applications

### Fichiers à créer

```
07-applications/common/README.md
07-applications/common/farci_client.py       # OpenAI SDK pointé sur Caddy
07-applications/common/schemas.py            # Pydantic ClinicalExtraction (§28)
07-applications/common/observability.py      # OTel (écrit en phase 7, utilisé ici)
07-applications/common/pipeline.py           # PDF→Docling→deid→LLM→Pydantic→JSON
07-applications/common/retry.py              # backoff + repair JSON (max 2)
07-applications/common/prompts/extraction_v1.md
07-applications/common/prompts/extraction_v2.md
07-applications/common/prompts/README.md     # §56 versioning
07-applications/common/prompts/v1-vs-v2.md   # ce qui a changé et pourquoi (F1 attendu)
07-applications/python/pyproject.toml
07-applications/python/requirements.txt
07-applications/python/run_pipeline.py       # CLI
07-applications/python/make_table.py
07-applications/python/README.md
07-applications/open-webui/docker-compose.yml
07-applications/open-webui/env.example
07-applications/open-webui/post-setup.sh     # connexion OAI-compatible vers Caddy
07-applications/open-webui/prompt.md
07-applications/open-webui/export-submissions.sh
07-applications/open-webui/README.md
07-applications/flowise/docker-compose.yml
07-applications/flowise/flowise.json        # flow importable (§32)
07-applications/flowise/README.md
07-applications/TUTORIAL.md
tests/test_structured_output.py
tests/test_schema_parity.py
```

### Contrats communs (§33)

- Même schéma, même dataset, même gateway, même alias `med-extraction`.
- Chaque sortie → `datasets/extracted/<student>/<patient>.json`, **écrit seulement
  si Pydantic valide** (§39 chaos 04).
- `common/` est la seule implémentation de référence ; Open WebUI et Flowise doivent
  **reproduire le même contrat** (d'où `flowise.json` versionné et le script
  d'export Open WebUI qui dépose les JSON au bon endroit).

### `prompts/extraction_v1.md` / `v2.md` (§28, §56)

Règles obligatoires du prompt :
1. Renvoyer **uniquement** un JSON conforme au schéma.
2. Champ absent → `null`. **Interdiction explicite d'inférer, extrapoler, compléter
   par Connaissances médicales** (le message clé du §59.1).
3. Ne pas calculer de dérivées non demandées.
4. Unité imposée : mm, jours.
5. `patient_id` repris du pseudonyme (`[PATIENT_001]`) — **jamais** inventé.

`v2` ajoute : ordre d'extraction par section, interdiction de microstructure
d'un tableau qui n'est pas demandée, et un format de sortie strict (JSON Schema natif
quand le runtime le supporte). → l'amélioration **mesurable** en F1 est la leçon.

### Parcours A — Python (recommandé, §30)
Pipeline complet, `argparse` (`--input --out --prompt --model --temperature --trace`),
reprise sur échec, rapport par dossier, `make evaluate` ensuite.

### Parcours B — Open WebUI (§31)
- Connexion **OBLIGATOIREMENT** via Caddy (`/v1`), pas directement au runtime
  → sinon la leçon « l'application ne connaît pas le moteur » est perdue.
- `post-setup.sh` crée la connexion OAI-compatible + clé virtuelle.
- `prompt.md` = `extraction_v1.md` verbatim ; procédure de soumission manuelle
  puis `export-submissions.sh` normalise vers `datasets/extracted/<student>/`.

### Parcours C — Flowise (§32)
`flowise.json` : `File/Text → HTTP Request (Docling via Caddy) → Prompt Template →
LLM Chain (OpenAI-compatible → Caddy) → Function/Validation (schéma) → Output`.
Le nœud de validation **rejette** les JSON non conformes (équivalent de Pydantic)
→ cohérence de la démonstration.

### Critère de fin
3 dossiers × 3 parcours → 3 ensembles de JSON validés par le **même** schéma ;
`make evaluate` compare ; `tests/test_structured_output.py` vert.

---

# PHASE 11 — Étape 3 : Chaos engineering

### Fichiers à créer

```
chaos/chaos.sh                # dispatcher: list | scenario-NN | reset | status
chaos/lib/chaos_lib.sh
chaos/scenarios/scenario-01-primary-runtime-down.sh
chaos/scenarios/scenario-02-backup-runtime-down.sh
chaos/scenarios/scenario-03-rate-limit.sh
chaos/scenarios/scenario-04-invalid-json.sh
chaos/scenarios/scenario-05-docling-down.sh
chaos/scenarios/scenario-06-gateway-a-down.sh
chaos/scenarios/scenario-07-observability-down.sh
chaos/scenarios/README.md     # tableau : action / attendu / observabilité / leçon
chaos/TUTORIAL.md
tests/test_failover.sh
```

### Contrat de chaque scénario (§43)

Interface unique : `apply` et `revert` (idempotents), état persisté dans
`.chaos/state.json`, sortie lisible, **durée d'impact paramétrable** :

```bash
./chaos/chaos.sh list
./chaos/chaos.sh scenario-01
./chaos/chaos.sh scenario-01 --duration 60     # auto-revert
./chaos/chaos.sh status
./chaos/chaos.sh reset
```

### Détail par scénario (attendu *vérifiable*, pas espéré)

| # | Action | Assertion automatique | Leçon |
|---|---|---|---|
| 01 | stop runtime primaire | gateway 200, en-tête fallback, client inchangé, Kuma: Ollama 🔴 / Gateway 🟢 / Pipeline 🟢 | redondance active |
| 02 | stop runtime secondaire | Kuma `CLINICAL AI PIPELINE` 🔴, gateway 503 documenté | le pipeline n'est résilient que si *tous* les niveaux le sont |
| 03 | 12 requêtes en 2 s avec `sk-standard` | ≥1 × **429** + `Retry-After` ; `sk-priority` 200 | le débit est une propriété du gateway, pas du modèle |
| 04 | modèle renvoie un JSON hors schéma (température/grammar cassée) | Pydantic `ValidationError` journalisée, **aucun** fichier écrit | validation obligatoire (§59.5) |
| 05 | stop Docling | pipeline document 🔴, gateway 🟢, inference 🟢 | dépendance partielle |
| 06 | stop gateway A | bascule vers B via Caddy, toujours `http://192.168.50.15/v1` | le client ne change qu'un endpoint logique |
| 07 | stop Phoenix/Langfuse | extraction **réussie**, traces perdues uniquement | observabilité ≠ chemin de production |

`scenario-04` ne triche pas : il utilise un **mécanisme réel** (schema désactivé côté
runtime via un modele de test `med-chaos` volontairement non conforme), pas un faux
endpoint factice.

### Critère de fin
`./chaos/chaos.sh scenario-01 && make test-failover && ./chaos/chaos.sh reset` →
pipeline vert, Kuma entièrement 🟢, `state.json` vide.

---

# PHASE 12 — Suite de tests & CI

### Fichiers (§54)

```
tests/lib/common.sh
tests/lib/json.sh
tests/test_gitops.sh
tests/test_network.sh
tests/test_inference_contract.sh
tests/test_gateway_contract.sh
tests/test_docling.sh
tests/test_observability.sh
tests/test_structured_output.py
tests/test_schema_parity.py
tests/test_deidentification.py
tests/test_evaluation.py
tests/test_failover.sh
tests/test_airgap.sh
tests/run-all.sh            # agrégateur → tableau de résumé (§54)
.gitea/workflows/tests.yml
.gitea/workflows/evaluate.yml
.gitea/workflows/integration.yml
.gitea/workflows/score.yml   # (bonus) publish du tableau de scores
```

### `tests/run-all.sh` (§54)
Chaque test est **autonome**, retourne `0/1/2 (skip)`, écrit une ligne :

```
╔══════════════════════════════════════════════════════════════╗
║ TEST                    │ RÉSULTAT │ DURÉE   │ DÉTAIL      ║
╠══════════════════════════════════════════════════════════════╣
║ air-gap                 │ PASS     │  2.1s   │             ║
║ inference contract      │ PASS     │  1.4s   │ ollama      ║
║ gateway contract        │ PASS     │  0.9s   │ litellm     ║
║ failover                │ SKIP     │    –    │ chaos actif ║
╚══════════════════════════════════════════════════════════════╝
```
`SKIP` est une **première classe** (une brique optionnelle absente n'est pas un échec).

### CI (`.gitea/workflows/*.yml`, §55)
- `tests.yml` (sur PR) : lint → `pytest` (sans réseau) → tests contractuels unitaires
  (mocks) → **mini dataset (3 cas)** seulement si la stack est joignable.
- `evaluate.yml` : si le runner est étiqueté `gpu`/`full`, joue le mini dataset et
  publie `JSON validity / F1 / Regression`.
- `integration.yml` : sur `main`, après merge — séquence complète air-gap + chaos léger.
- Conventions : `permissions: read-all`, `concurrency`, aucun secret en clair.

### Critère de fin
`make test` exit 0 sur une stack complète ; chaque ligne du tableau est justifiée.

---

# PHASE 13 — Documentation & tutors

### Fichiers
```
README.md                       # §44 : les 3 ÉTAPES + le vocabulaire en langage médical
docs/ARCHITECTURE.md            # §3 en ASCII + graphe des contrats + ports/IP
docs/WORKSHOP_FLOW.md           # minutage, 7 équipes, rôles, jalons
docs/AIRGAP.md                  # ce qui est préchargé, comment vérifier, pièges
docs/CONTRACTS.md               # les 3 contrats en un seul document comparé
docs/CHAOS.md                   # tableau des 7 scénarios + résultat attendu
docs/INSTRUCTOR_GUIDE.md        # §50 checklists J-7 / J-1 / J0
docs/_templates/TUTORIAL.template.md
0*/TUTORIAL.md  (×7)            # §45, structure identique imposée
CONTRIBUTING.md                 # flux Git : branche, commit, PR, revue (§11/§46)
```

### Exigences de contenu (non négociables)
1. **README** : commence par le schéma `ÉTAPE 1 → 2 → 3` (§44), puis explique
   *modèle / runtime / gateway / application / observabilité / évaluation / GitOps*
   avec une analogie médicale à chaque terme (le « scanner » n'est pas le « radiologue »).
   Doit contenir explicitement `modèle ≠ runtime` (§9) et les 10 messages du §59.
   **Doit aussi** : (a) annoncer d'emblée que `git clone` seul ne suffit pas et que
   `FARCI_DATA_DIR` est obligatoire (§0.1) ; (b) le tableau des 3 modèles avec licence
   et taille (§0.2) ; (c) l'écart assumé au §9 (pas de 1–2B) et sa raison.
2. **Chaque TUTORIAL** : les 14 sections exactes du §45 + une section
   `Dépannage` (non listée au §45 mais nécessaire en atelier).
3. **CONTRATS.md** : tableau `inference / gateway / observabilité` → endpoints,
   auth, codes d'erreur, en-têtes, obligations ; + « comment ajouter une
   implémentation en 4 étapes » (le vrai objectif pédagogique).
4. **INSTRUCTOR_GUIDE** : les deux checklists §50 verbatim + plan de repli
   (machine de secours, images déjà chargées, clé USB).

### Critère de fin
`scripts/lint.sh --docs` vérifie : tous les `TUTORIAL.md` contiennent les 14 titres
du gabarit ; chaque service de `services.yaml` est mentionné dans un TUTORIAL ;
aucun `TODO`/`FIXME`/`XXX` dans le dépôt.

---

# PHASE 14 — Recette finale (Definition of Done globale)

### Séquence de recette (§60), exécutée telle quelle

```bash
# --- avec Internet (une fois) ---
git clone <gitea>/FARCI/farci.git && cd farci
cp .env.example .env && cp config/network.env.example config/network.env
./bootstrap.sh --check            # dépendances, réseau, droits
./preload.sh --all
./verify-airgap.sh
make core-up && make dashboard-up
make test

# --- COUPURE INTERNET ---
# (ou : unshare -rn pour un test strict)
make health                       # → CLINICAL PIPELINE READY
make evaluate                     # → tableau de scores
./chaos/chaos.sh scenario-01      # panne reproductible et observable
./chaos/chaos.sh reset
make health                       # → retour au vert
```

### Matrice de recette (à cocher, une ligne par exigence du FARCI)

| Exigence | Vérification automate | Attendu |
|---|---|---|
| §4 IP modifiables | `grep -R "192.168.50" --include='*.yml' --include='*.py' .` | 0 occurrence hors `config/` |
| §6 pas de `latest` | `scripts/lint.sh --versions` | 0 `latest` |
| §7 air-gap | `unshare -rn ./verify-airgap.sh --strict` | exit 0 |
| §13 dashboard | `curl :3001/api/status-page/heartbeat/1` | 14 moniteurs, 7 groupes |
| §14 agrégat | `curl 192.168.50.15/status` | `{"status":"ready"}` |
| §16/§18 contrats | `make test` | tous PASS |
| §19 fallback | `tests/test_failover.sh` | 200 + fallback |
| §28 structured output | `tests/test_structured_output.py` | 0 fichier invalide écrit |
| §34 score | `make evaluate` | 8 métriques + run MLflow |
| §38 rate limit | scenario-03 | 429 + `Retry-After` |
| §45 tutos | lint docs | 7/7 conformes |
| §49 statut | `scripts/workshop-status.sh` | ASCII + pipeline READY |
| §51 manifeste | `make verify-manifest` | 0 mismatch |
| §52 aucun CDN | `scripts/check-offline-policy.sh` | 0 violation |
| §55 CI | push sur PR | 4 jobs verts |
| §58 permutation | `GATEWAY_BACKEND=bifrost RUNTIME=llamacpp OBS=langfuse make health` | READY, code métier inchangé |
| §9 modèle unique | `make evaluate` sur les 3 parcours | même dataset, même schéma, même alias |
| **§0.1 dépôt léger** | `git count-objects -vH` | `.git` < 8 Mo |
| **§0.2 poids partagés** | `sha256sum offline/models/*.gguf` | 1 fichier = 2 runtimes |
| **contrat reasoning** | `tests/test_structured_output.py` | `content` sans raisonnement, 0 leak |
| **licences** | `make licenses` | MIT + Apache-2.0 affichées, valides |

### Critère de fin (unique)
**Les 3 étapes sont enchaînables sans Internet, par des étudiants, avec
`make`/scripts seulement, et chaque brique est remplaçable sans modifier le code
métier de l'application.**

---

## 2. Ordre d'exécution recommandé (planning)

| Jour / Lot | Phases | Parallélisable avec |
|---|---|---|
| Lot 1 | 0 | rien (tout en dépend) |
| Lot 2 | 1 (+ 1bis : `tools/` make) — **commencer par `--models-ci` seul**, le temps de télécharger | 10 (générateur de dataset) |
| Lot 3 | 10 (gold + PDFs + schémas) | 2 |
| Lot 4 | 3 (réseau/Caddy/agrégat — indispensable pour tester 4, 5, 7) | 2 |
| Lot 5 | 4 (inférence) puis 5 (gateway) puis 7 (observabilité) | 6 (après schéma) |
| Lot 6 | 6 + 8 | 9 (dépend de 5, 7) |
| Lot 7 | 9 (common d'abord, puis les 3 parcours) | 11 |
| Lot 8 | 11 + 12 | 13 |
| Lot 9 | 13 puis 14 (recette) | — |

**Ordre de mise en place (à respecter)**
1. `common/` **avant** les 3 parcours (évite 3 implémentations divergentes).
2. `CONTRACT.md` **avant** toute implémentation d'une brique (évite la dérive).
3. `services.yaml` **avant** Caddy/Uptime/agrégat (évite 3 listes de services).
4. Schéma JSON **avant** Pydantic, Flowise, prompt, gold (évite 4 contrats divergents).
5. Air-gap (`preload`, `versions`, manifeste) **avant** toute image ajoutée.

---

## 3. Risques identifiés et parades

| # | Risque | Impact | Parade prévue |
|---|---|---|---|
| R1 | Images introuvables / tags nonexistants (Bifrost, oMLX, Docling) | bloquant | `versions.env` figé après `docker manifest inspect` sur chaque tag, dans la phase 1 |
| R2 | `preload.sh --all` > 30 Go | poste instructeur saturé | `--core` par défaut + `--all` documenté + `du -sh offline/*` affiché |
| R3 | Structured output non supporté par le modèle small | chaos 04 et F1 trompeux | grammar GBNF llama.cpp + `format: json` Ollama + repli prompt strict ; `bench/bench.sh` documente |
| R4 | Uptime Kuma sans API de création de moniteurs | étape 1 bloquée | `services.yaml` + seed socket.io + checklist manuelle de secours |
| R5 | oMLX non conteneurisable (Metal) | option C cassée | Tagged `profile: mac` + endpoint contractuel, jamais requis (§15) |
| R6 | 2 Go RAM en dev → OOM sur Docling/Phoenix | tests locaux rouges | `make dev-lite` (profil `lite` : llama.cpp small, pas de Docling GPU) + prérequis documented |
| R7 | `make` absent (§47) | bloquant pour l'instructeur | `tools/install.sh` + `bin/farci` + install dans `preload.sh` |
| R8 | Divergence gold ↔ Pydantic ↔ Flowise | métriques faussées | `tests/test_schema_parity.py` en CI, bloquant |
| R9 | OTel bloque le chemin critique si l'observabilité tombe | pipeline cassé | timeouts 1 s, failure callback, `chaos scenario-07` vert obligatoire |
| R10 | Divulgation de clés (rate limit) en cours d'atelier | chaos 03 impossible | clés jetables regenerables (`make keys-reset`), jamais dans Git (§53) |
| **R11** | Les 2 modèles sont des *reasoning models* : leur raisonnement se retrouve dans `content` | **étape 2 cassée** (Pydantic error sur tous les dossiers) | `reasoning_content` rendu explicite dans les 2 contrats + `think:false` côté gateway + test dédié qui échoue si un raisonnement fuit |
| **R12** | llama.cpp : pas de tag semver, images ARM64 absentes, build numbers parfois non publiés | image qui casse le jour J, Mac sans llama.cpp | `preload.sh` **compile l'image localement** en multi-arch depuis la source b10600 + sha256 vérifié |
| **R13** | Licence : MIT (Ornith) vs Apache-2.0 (Qwen3.8) — et Qwen3.8-Max/Flash sous Qwen Community License 1.0 | usage pédagogique mal documenté | `models/models.env` porte la licence par modèle + `make licenses` ; les poids 3.8-27B **uniquement** en usage atelier |
| **R14** | Poids 9B (6,5 Go) et 27B (17,5 Go) : RAM et disque des postes étudiants | « ça marche pas sur mon PC » | `FARCI_DATA_DIR` externe (§0.1), `med-extraction-lite` (2B) par défaut sur machine < 16 Go, `make hardware-check` avant le workshop |
| **R15** | 27B multimodal (mmproj) : temptation de court-circuiter Docling | contournement de l'équipe 4 | le mmproj n'est **activé que** dans l'exercice bonus « Docling vs VLM », jamais dans le pipeline noté |
| **R16** | `mlx-lm` standard n'implémente pas l'arch hybride `qwen3_5` | oMLX muet sur Mac | versions `mlx`/`mlx-lm`/`mlx-vlm` figées dans `versions.env` + TUTORIAL §15.3 avec les commandes exactes |

---

## 4. Definition of Done par phase (rappel)

Une phase est close quand :
```
[ ] tous les fichiers listés existent et ne contiennent ni TODO ni stub
[ ] le service démarre hors ligne
[ ] son healthcheck est vert sur un endpoint réel (§48)
[ ] son test contractuel passe
[ ] son TUTORIAL.md est rempli (14 sections)
[ ] `make help` expose la commande
[ ] commit + PR fusionnée
[ ] la sonde Uptime Kuma correspondante est UP
[ ] `scripts/lint.sh` passe (versions, offline-policy, docs, IP)
```

---

# PHASE 15 — Agents Arcane déportés & GitOps

**Objectif** : déployer un agent de supervision (Arcane) en conteneur Docker sur chaque
brique du pipeline, et orchestrer les déploiements via GitOps (webhook Gitea → runner).

## Fichiers à créer

```
08-arcane-agents/
├── docker-compose.yml          # agents déportés sur chaque brique
├── arcane-agent/
│   ├── Dockerfile
│   ├── agent.py                # agent de supervision (stdlib)
│   └── config.yaml             # configuration par brique
├── webhook/
│   ├── webhook.py              # récepteur de webhooks Gitea
│   └── webhook.service         # service systemd (ou conteneur)
├── gitops/
│   ├── gitops.sh               # déploiement GitOps
│   └── webhook-handler.sh      # traitement des événements
└── TUTORIAL.md
```

## Architecture

```
Gitea (push/PR)
    │
    ▼ (webhook)
┌─────────────┐
│  Webhook    │  ← reçoit les événements Git
│  Handler    │
└──────┬──────┘
       │
       ▼ (GitOps)
┌─────────────┐
│  gitops.sh  │  ← pull + apply
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Agents Arcane (conteneurs Docker)  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│  │Ollama│ │LLM  │ │Docl.│ │MLfl.│  │
│  │agent │ │agent│ │agent│ │agent│  │
│  └─────┘ └─────┘ └─────┘ └─────┘  │
└─────────────────────────────────────┘
```

## Points techniques

1. **Agent Arcane** : conteneur Docker par brique, supervise l'état, alerte en cas d'anomalie
2. **Webhook Gitea** : reçoit les événements push/PR, déclenche le déploiement GitOps
3. **Gitops.sh** : pull le dépôt + apply les manifests (docker compose up -d)
4. **Idempotence** : chaque déploiement est idempotent (apply sans effet de bord)

## Critère de fin

Un push sur `main` déclenche un déploiement automatique via webhook → gitops.sh,
et chaque brique a son agent Arcane de supervision actif.

---

## 5. Prochaine action

Étape immédiate recommandée : **Phase 0 + Phase 1 + Phase 10 (lot 1-3)**, car elles
produisent le squelette exécutable (`make help`, `preload`, air-gap) et le dataset
qui débloquent toutes les autres phases sans dépendance à une brique en cours.

Ordre d'écriture proposé pour la première session :
1. `.gitignore`, `offline/.gitignore`, `.env.example`, `config/network.env.example`,
   `versions.env`, `models/models.env`, `Makefile`, `bin/farci`, `scripts/`
2. `preload.sh` (d'abord `--dry-run`, puis `--models-ci` seulement),
   `bootstrap.sh` (dont le lien `offline` → `FARCI_DATA_DIR`), `verify-airgap.sh`
3. `datasets/tools/*` + `datasets/raw|gold` + `datasets/schemas/`
4. `make help && ./preload.sh --dry-run --core && ./verify-airgap.sh` → première preuve
   de vie, **sans** télécharger 26 Go sur cette machine de dev (2 Go de RAM / 12 Go libres).

### Ce qui ne pourra pas être validé sur cette machine

Honnêteté utile pour planifier : avec **2 Go de RAM**, tout ce qui implique le modèle
ne tourne pas ici. Validable localement : phases 0, 1 (hors exécution des groupes
lourds), 2, 3 (Caddy + agrégat sans Docling/Phoenix), 6, 10, 12 (partie statique), 13.
À valider sur un poste ≥ 16 Go : phases 4, 5, 7, 8, 9, 11, 14.
