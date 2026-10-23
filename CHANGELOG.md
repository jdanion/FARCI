# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
versionnement est [sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Lot 2 — tenir en 4 h

- `docs/WORKSHOP_FLOW.md` et `docs/INSTRUCTOR_GUIDE.md` réécrits sur 240 min :
  accueil 20, étape 1 90, pause 10, étape 2 50, évaluation 20, étape 3 35,
  clôture 15 ; objectif minimal (< 45 min) et bonus par équipe ; ce qu'on
  coupe en cas de retard.
- `config/services.yaml` : champ `tier` (core / bonus) et `critical_group`.
  `CLINICAL PIPELINE READY` = Caddy + agrégateur + LiteLLM + Docling + **au
  moins un** runtime. Phoenix est cœur mais hors de READY (scénario 07).
- Règle unique `pipeline_state` (`scripts/services.py`), utilisée par
  `./bin/farci status` **et** le health-aggregator (réécrit : il lisait un
  format de registre qui n'existe pas). Tests : `tests/test_pipeline_rule.py`.
- Tableau : lignes cœur + une ligne « Bonus n/8 » (`--all` pour le détail),
  liste « Il manque » dans l'ordre de montage, `--json` avec l'état du pipeline.
- Sondes de vivacité qui ne dépendent de personne : `/livez` sur Caddy et sur
  l'agrégateur (avant, Caddy paraissait en panne quand l'agrégateur l'était,
  et l'agrégateur se sondait lui-même en boucle).
- Uptime Kuma derrière un profil `bonus`.
- Casting : rôles cœur / bonus alignés sur le registre ; les briques cœur sans
  équipe sont listées (servies par le formateur).
- `docs/CHAOS.md` : 4 scénarios en 35 min (01, 04, 06 ou 05, 07), résultats
  attendus alignés sur la règle du pipeline.

### Lot 1 — remettre au vert

L'outillage, la CI et la documentation décrivent enfin le même dépôt.
Critère de sortie : `./bin/farci selftest`, `./bin/farci lint` et
`./bin/farci ci` verts ; aucune doc ne cite une commande inexistante
(contrôle `lint-commands`).

**Corrigé**
- Registre des cibles : `preload`, `verify-airgap` et `casting` ont un script
  dans `scripts/cmd/` ; les groupes affichés par `help` sont lus dans
  `help.sh` (plus de liste en double) ; toutes les cibles répondent à `--help`.
- 18 scripts sans bit exécutable dans l'index Git.
- Plus aucune adresse IP hors de `config/network.env` : les URL de service
  sont dérivées en un seul endroit (`scripts/dev-env.sh`), sans valeur par
  défaut. Le contrôle couvre désormais aussi Caddyfile, `.ini`, `.example`.
  Plusieurs adresses par défaut étaient fausses (Phoenix, Docling, Uptime Kuma).
- `Caddyfile` : syntaxe d'environnement de Caddy (`{$VAR}`), ports lus dans
  la configuration, préfixes retirés (`handle_path`) pour Docling et les UI.
- Évaluation : typage des champs, normalisation, détection des runs
  `datasets/extracted/<run>/`, F1 calculé sur tous les dossiers du gold,
  conformité au schéma vérifiée sans dépendance. Gold contre gold = 1,00.
- `validate_gold.py` lit `datasets/gold/` et valide contre le schéma.
- Pseudonymisation : le NIR et les noms absents du dictionnaire passaient en
  clair ; aucune fuite sur les 80 documents (test dédié).
- Pipeline Python : un dossier par patient à partir des `.txt`, pseudonymisé,
  validé ; un JSON non conforme n'est jamais écrit.
- Pydantic aligné sur le schéma JSON (champs nullables requis).
- `chaos/chaos.sh` : racine du dépôt, recherche des scénarios, `reset` qui
  répare réellement et signale ce qu'il n'a pas pu réparer.
- Images : `docling-serve` et `mlflow` pointaient vers des tags inexistants ;
  liste unique `scripts/lib/images.sh` (cinq listes divergeaient).
- `preload.sh` télécharge réellement les poids (`models/models.env`) et
  sauvegarde chaque image en `.tar` pour les postes sans Internet.
- Tests d'intégration : racine du dépôt, délais bornés, `SKIP` si la brique
  est absente (`FARCI_TESTS_STRICT=1` pour la recette).

**Ajouté**
- Cibles `up`, `down`, `logs`, `extract`, `evaluate`, `chaos`, `ci`,
  `test`, `test-unit`, `verify-manifest`, `gen-manifest`, `lint-commands`.
- Tests unitaires (unittest, sans réseau ni GPU) : évaluation, parité du
  schéma, sortie structurée, pseudonymisation.
- `07-applications/common/observability.py` : traces OTLP du parcours
  Python, sans jamais bloquer l'extraction.
- CI exécutable : `.gitea/workflows/tests.yml` (runner label `farci`, sans
  action externe) et `.github/workflows/ci.yml`, tous deux `./bin/farci ci`.
- `01-network-dashboard/TUTORIAL.md` ; gabarit TUTORIAL complet (14 sections
  du §45 + Dépannage) et TUTORIAL réécrits sur ce gabarit.

**Retiré**
- Options de casting non fournies (GitLab, Nginx, Traefik, PyMuPDF, W&B,
  Portainer), désormais listées comme « non fournies ».
- Workflows factices (`score.yml`, valeurs F1 écrites en dur dans `evaluate.yml`).
- `06-evaluation/mlflow/Dockerfile` (inutilisé, image inexistante) et
  `07-applications/open-webui/env.example` (doublon du compose).

### Historique des phases

Les phases 1 à 15 de `PLAN.md` ont été livrées (voir l'historique Git), mais
**sans validation sur matériel réel** : le lot 1 en a corrigé l'outillage et
la cohérence. Restent à valider sur les machines de l'atelier : démarrage de
chaque brique, modèles, réseau de salle (voir la PR du lot 1).

## [0.1.0] — 2026-09-26

### Ajouté — phase 0, socle du dépôt

**Outillage**
- `bin/farci` : lanceur unique, utilisable **sans `make`**.
- `Makefile` : façade mince générée depuis `scripts/targets.def`, donc
  `make help` et `./bin/farci help` ne peuvent pas diverger.
- `scripts/targets.def` : registre des cibles, source de vérité unique.
- `bootstrap.sh` et `./bin/farci bootstrap` : préparation de machine idempotente
  (répertoires de données, lien `offline/`, fichiers `.env`, dépôt git, lint).
- `scripts/cmd/lint.sh` (`./bin/farci lint`) : 8 contrôles (versions, IP, documentation, air-gap, marqueurs
  de travail, bash, Python, taille), avec `PASS` / `FAIL` / `WARN` / `SKIP`.
- `scripts/cmd/status.sh` (`./bin/farci status`) : tableau de progression (§49), sondes parallèles,
  mode `--watch` pour l'amphithéâtre.
- `scripts/cmd/doctor.sh` (`./bin/farci doctor`) : diagnostic machine (Docker, Python, RAM, disque, réseau).

**Configuration**
- `config/services.yaml` : registre déclaratif des 15 services, 7 groupes,
  10 lignes de progression. Contient uniquement des **noms de variables**.
- `config/network.env.example` : le seul endroit du dépôt contenant des adresses.
- `scripts/dev-env.sh` : chargement unique de la configuration, avec priorité
  documentée (environnement > workshop.env > network.env > .env).
- `versions.env` : toutes les versions **vérifiées comme existantes** par
  `docker manifest inspect` le 2026-09-26 (Gitea 1.27.3, Caddy 2.11.4,
  LiteLLM 1.102.1, Ollama 0.34.4, MLflow 3.16.1, Phoenix 20.16.0,
  Langfuse 4.46.0, Docling Serve 0.5.1, Flowise 3.1.4, Open WebUI 0.11.4,
  Uptime Kuma 2.5.5, PostgreSQL 18.6, Redis 8.8.3).

**Briques maison (sans dépendance externe)**
- `scripts/lib/miniyaml.py` : parseur d'un sous-ensemble de YAML, avec
  auto-test. Remplace PyYAML, absent en mode air-gap.
- `scripts/lib/jsonpath.py` + `json.sh` : accès JSON en ligne de commande.
  Remplace `jq`, absent de la machine de référence.
- `scripts/lib/common.sh` : helpers bash (logs, `retry`, `wait_http`, sonde HTTP).
- `scripts/check_targets.py` : valide le format du registre de cibles — une
  tabulation en trop faisait disparaître une cible **sans aucun message**.

**Données**
- Dépôt allégé : `offline/` est un lien symbolique vers `$FARCI_DATA_DIR/offline`.
  Aucun poids, aucune image, aucun wheel dans l'historique Git.
- `requirements.in` : dépendances Python, chaque ligne justifiée par son
  consommateur. `scripts/lock-requirements.sh` produit le verrou et les wheels.

**Documentation**
- `README.md` : les trois étapes, le vocabulaire en langage médical, les dix
  messages, le tableau des modèles.
- `CONTRIBUTING.md` : cycle Git, conventions, règles vérifiables.
- `docs/` : les six documents du cahier des charges, plus le gabarit de TUTORIAL
  à 14 sections.

### Décisions notables

- **Dépôt Git léger** : les artefacts lourds vivent hors de l'historique. Conséquence
  assumée : `git clone` seul ne suffit pas, il faut aussi `FARCI_DATA_DIR`.
- **Modèles** : Ornith-1.5-9B (MIT) comme modèle principal, Qwen3.8-27B
  (Apache-2.0) pour les postes puissants, Qwen3.5-2B pour la CI. Écart au
  cahier des charges documenté : il ne propose pas de modèle sous 9 Go.
- **Un seul fichier de poids par modèle**, monté par llama.cpp et importé par
  Ollama : comparer deux runtimes n'est scientifiquement valide qu'à poids
  constants.
- **Image llama.cpp compilée localement** : l'image officielle n'a pas de tag
  semver et n'existe pas en `linux/arm64`.
- **Le lint ne bloque pas sur ce qui n'existe pas encore** : les répertoires des
  phases futures sont ignorés, les outils absents sont `SKIP` et non `FAIL`.
