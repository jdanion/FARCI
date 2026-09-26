# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
versionnement est [sémantique](https://semver.org/lang/fr/).

## [Non publié]

### phases à venir

Le dépôt est livré **phase par phase**. Chaque phase ajoute ses briques ; le
plan complet est dans `PLAN.md`.

- [ ] **Phase 1** — air-gap : `preload.sh`, `verify-airgap.sh`, manifeste
- [ ] **Phase 2** — équipe 0 : Gitea, runner, GitOps
- [ ] **Phase 3** — équipe 1 : Caddy, Uptime Kuma, `health-aggregator`
- [ ] **Phase 4** — équipe 2 : Ollama, llama.cpp, oMLX
- [ ] **Phase 5** — équipe 3 : LiteLLM, Bifrost
- [ ] **Phase 6** — équipe 4 : Docling, pseudonymisation
- [ ] **Phase 7** — équipe 5 : Phoenix, Langfuse
- [ ] **Phase 8** — équipe 6 : MLflow, métriques
- [ ] **Phase 9** — étape 2 : les trois parcours d'application
- [ ] **Phase 10** — dataset synthétique et gold standard
- [ ] **Phase 11** — étape 3 : scénarios de chaos
- [ ] **Phase 12** — suite de tests et CI
- [ ] **Phase 13** — documentation finale
- [ ] **Phase 14** — recette bout-en-bout

## [0.1.0] — 2026-09-26

### Ajouté — phase 0, socle du dépôt

**Outillage**
- `bin/farci` : lanceur unique, 22 commandes, utilisable **sans `make`**.
- `Makefile` : façade mince générée depuis `scripts/targets.def`, donc
  `make help` et `./bin/farci help` ne peuvent pas diverger.
- `scripts/targets.def` : registre des cibles, source de vérité unique.
- `bootstrap.sh` et `./bin/farci bootstrap` : préparation de machine idempotente
  (répertoires de données, lien `offline/`, fichiers `.env`, dépôt git, lint).
- `scripts/lint.sh` : 8 contrôles (versions, IP, documentation, air-gap, marqueurs
  de travail, bash, Python, taille), avec `PASS` / `FAIL` / `WARN` / `SKIP`.
- `scripts/workshop-status.sh` : tableau de progression (§49), sondes parallèles,
  mode `--watch` pour l'amphithéâtre.
- `scripts/doctor` : diagnostic machine (Docker, Python, RAM, disque, réseau).

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
