# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
versionnement est [sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Le tableau ouvre les pages des services

- Une ligne « Ouvrir : » sous l'en-tête du tableau de la salle : Rejoindre,
  puis la forge, la discussion (Open WebUI), les traces (Phoenix), Langfuse,
  MLflow, les sondes, Docling, Flowise. Un lien n'apparaît que si le service
  répond, et mène à la machine qui le rend (celle de l'équipe, sinon le Pi).
- La forge a désormais le Pi pour doublure : sans équipe 0, le tableau la
  montre rendue par la référence et son lien fonctionne.

### Deux temps : en ligne, puis en local sur la forge du Pi

- La séance sépare le temps en ligne (cloner depuis GitHub sans compte,
  télécharger sa brique, créer sa branche) du temps en local sur
  `FARCI-SALLE`, où l'on publie sur la forge Gitea du Pi. Le basculement est
  un moment du déroulé.
- `./bin/farci poste salle` : branche un clone sur la forge sans rien saisir
  (dépôt distant `salle`, compte `equipe-<N>` rangé dans `.git/`, identité
  git). Le mot de passe de la salle vient du partage du Pi
  (`FARCI_FORGE_MOT_DE_PASSE_PUBLIC=0` pour ne pas le publier).
- Le Pi héberge la forge et l'accueil en premier : sans adresse déclarée pour
  Gitea, c'est celle du Pi (plus de `room set gitea`), et un poste étudiant la
  trouve en ne connaissant que `REFERENCE_IP`.
- Guide git, fiches d'équipe, déroulé, feuille de séance : le chemin principal
  est `git push -u salle`. Diaporama : quatre diapositives sur le basculement.

### Questionnaires Wooclap à importer

- `docs/support/wooclap/` : `pre-test.xlsx`, `post-test.xlsx` et
  `satisfaction.xlsx`, générés par `build_wooclap.py` (une seule source, qui
  réécrit aussi `EVALUATION.md`).
- 20 questions de connaissance, dont les nouvelles notions (quantification,
  modèle spécialisé, Pydantic, forme contre fond, rappel, `git diff`, Pull
  Request) ; attentes des étudiants au pré-test ; au questionnaire de
  satisfaction : attentes satisfaites ou non, utilité de chaque partie, partie
  préférée, partie la plus difficile.
- Classeurs alignés sur l'en-tête d'un export Wooclap réel (`Type`, `Title`,
  `Correct`, `Choice`). Questionnaire de satisfaction adapté à des étudiants
  en médecine : se sont-ils sentis à leur place, les comparaisons médicales
  ont-elles aidé, le format atelier contre le cours magistral, l'usage en
  thèse ou en mémoire.
- Diaporama : l'acronyme FARCI sur la page de garde ; trois diapositives sur
  le parallèle médical (rappel = sensibilité, précision = valeur prédictive
  positive, tableau de contingence, effet de la prévalence), et deux
  questions de connaissance correspondantes.

### Diaporama : lisible par PowerPoint, et 22 diapositives de détail

- Correctif : PowerPoint (iPad compris) refusait d'ouvrir le diaporama. Deux
  flèches du schéma de la passerelle avaient une hauteur négative, tolérée
  par LibreOffice et par le contrôle automatique, interdite par le format.
- Quatre sections de détail : les modèles (lire un nom de fichier, les six
  modèles, généraliste / spécialisé / à raisonnement / mélange d'experts,
  protocole de comparaison), Pydantic (le schéma réel, ce qu'il refuse),
  la mesure (quatre issues par champ, rappel et précision, lire le
  classement) et git (commit, branche, diff, Pull Request, dépannage).
- `docs/support/deck/` : le générateur du diaporama. `COURS.md` reprend les
  nouvelles notions.

### Le Pi sans écran : salle ou Internet

- `./bin/farci wifi` : `internet` quitte le point d'accès pour un Wi-Fi qui a
  Internet, `salle` y revient, `ajouter` enregistre un réseau sans écrire son
  mot de passe dans l'historique. Sans connexion SSH pendant 5 minutes (et
  sans téléchargement en cours), le Pi recrée seul le Wi-Fi de la salle.
- Point d'accès créé en WPA2/AES (`rsn`, `ccmp`) : les appareils Apple
  refusaient le réglage par défaut.

### Six modèles, selon la machine

- Qwen3.5-4B, Gemma 4 E4B et MedGemma 4B (deux généralistes et un modèle
  spécialisé médecine, même gabarit) s'ajoutent au 2B et
  à Ornith-1.5-9B ; Ornith-1.5-35B-A3B pour les machines puissantes
  (`./preload.sh --only models_ornith_moe`).
- `02-inference/ollama/create-model.sh` : `qwen4b`, `gemma4b`, `medgemma4b`, `moe`, `liste` ;
  le choix automatique prend Qwen3.5-4B dès 8 Go de RAM. llama.cpp fait de
  même (`LLAMACPP_GGUF` dans la fiche du poste pour en imposer un autre).
- L'équipe 2 précharge les trois 4B ; le Pi (`--pi`) précharge Qwen3.5-4B.
- `./bin/farci verify-models --urls` contrôle que chaque adresse de
  `models/models.env` répond encore.

### Support de cours et évaluation

- `docs/support/COURS.md` : les attendus, les notions et le déroulé, pour les
  étudiants ; `FARCI-support-de-cours.pptx` : le diaporama de la séance
  (26 diapositives, notes du formateur).
- `docs/support/EVALUATION.md` : pré-test et post-test Wooclap (mêmes
  questions, pour mesurer le gain) et questionnaire de satisfaction.

### Git au centre de l'atelier : GitHub, la forge Gitea, une branche par poste

Nouvelle vision : chaque étudiant repart en sachant se servir de git. GitHub
(joignable depuis la faculté) est la source de vérité, la forge Gitea de la
salle montre qu'une forge s'héberge soi-même, et les fichiers volumineux
viennent d'un serveur de fichiers.

- `docs/GIT.md` (`./bin/farci docs git`) : le parcours pas à pas, pour qui
  n'a jamais utilisé git — cloner, créer sa branche, commiter, pousser, Pull
  Request, recevoir le travail des autres, forker après l'atelier.
- `./bin/farci poste` : où j'en suis dans git, et **la commande git à taper
  ensuite** (il n'en tape aucune). `poste nouveau` écrit la fiche de la
  machine sur sa branche ; `poste verifier` contrôle les fiches (lint, CI).
- Fiche de poste **versionnée** : `postes/equipe-<N>-<surnom>.env`, lue par
  `./bin/farci` tant que l'on est sur la branche `poste/equipe-<N>-<surnom>`
  (ou `FARCI_POSTE`). Ni secret, ni nom de personne.
- Forge Gitea pour toute la salle : lecture sans compte, comptes `equipe-0` à
  `equipe-8` (`GITEA_EQUIPE_PASSWORD`) avec droit d'écriture, `main` réservée
  à `forge-sync`, `seance` ouverte par Pull Request relue. La CI Gitea tourne
  aussi sur les PR vers `seance`. La protection de branche utilise l'API de
  Gitea (`branch_protections`) : l'ancienne route n'existait pas.
- Fichiers volumineux : sites d'origine d'abord (Hugging Face, registres,
  PyPI) ; `FARCI_FICHIERS_URL` (`.env`) est un miroir de secours, où
  `./preload.sh` prend un modèle ou une image que son origine refuse, et
  `bootstrap` les wheels. `./bin/farci partage publier <destination>`
  alimente le serveur par rsync.
- Page `/rejoindre` : cloner (forge de la salle, sinon GitHub, sinon la copie
  du Pi), créer sa branche, puis les fichiers.
- Documentation : `docs/AIRGAP.md` devient « local d'abord » (Internet pour le
  code et les fichiers, jamais pour les données) ; fiches d'équipe, déroulé,
  feuille de séance et guide formateur intègrent le fil git ; l'équipe 0
  tient « la forge de la salle ».

### llama.cpp : la compilation fonctionne

- `LLAMACPP_BUILD=b10600` n'existait pas (la numérotation des tags llama.cpp
  a des trous) : `b11500` (2026-10-08), tag vérifié.
- Le préchargement clone les sources sur l'hôte
  (`02-inference/llamacpp/vendor/llama.cpp`, hors Git) ; le `docker build`
  ne contacte plus GitHub. Base : l'image `python` déjà préchargée (plus de
  `gcc:13` ni de `debian` non figés).
- Binaire autonome (`BUILD_SHARED_LIBS=OFF`, `libgomp1` dans l'image) : la
  version précédente aurait démarré sans ses bibliothèques partagées.
  `LLAMA_CURL` n'existe plus en amont : `LLAMA_OPENSSL=OFF`.

### Nouvelle séance en une commande

- `./bin/farci seance nouvelle [--garder-equipes] [--tout]` : sauvegarde la
  séance dans `$FARCI_DATA_DIR/seances/<date>/`, oublie adresses et noms des
  équipes, `reset-all`, tableau à zéro, partage republié. `--tout` range aussi
  les extractions (déplacées dans la sauvegarde, jamais effacées).
- Correctif : après des adresses saisies dans l'onglet formateur, oublier une
  équipe (`room unset`, `seance nouvelle`) laissait Caddy router vers elle
  (compose ne le recréait pas). Le rechargement de l'accueil lui fait
  désormais relire sa configuration, et l'agrégateur vérifie l'ensemble EXACT
  des amonts servis (un amont en trop est corrigé en 30 s).
- `tableau reset` dit ce qu'il ne fait pas : les briques encore servies
  regagnent leurs points, les noms d'équipe restent.

### Tableau : liens, page Extraction, bonus, stacks au choix

- En haut du tableau : liens **Formateur** et **Extraction**.
- Page **`/tableau/extraction`** : l'étape 2 sur les 10 dossiers du jeu
  rapide — documents bruts, dossier pseudonymisé envoyé au modèle (étiquettes
  surlignées), prompts v1/v2, extraction **en direct** par l'accueil (`/v1`)
  comparée champ par champ au gold, et les runs déjà écrites sur la machine.
- Nouveau badge **« Ça tourne ! » (+30)** : la première pile d'une équipe qui
  n'a pas été la première de la salle.
- Passerelle et observabilité comme l'inférence : **LiteLLM ou Bifrost**,
  **Phoenix ou Langfuse** — la ligne passe au vert avec la stack que l'équipe
  sert, et chacune compte comme brique cœur. `CLINICAL PIPELINE READY` exige
  « une passerelle » (LiteLLM ou Bifrost) au lieu de LiteLLM seul.

### Onglet formateur du tableau

- `/tableau/formateur` (bouton **Formateur** du tableau) : nom de chaque
  équipe, ses étudiants, l'adresse IP de la machine de chaque brique, et le
  suivi en direct (UP / DOWN depuis…, qui sert la brique). Pas de code.
- Enregistrer écrit `config/salle.json` (noms, hors Git) et
  `config/network.env` (adresses, mêmes règles que `room set`), puis recharge
  l'accueil par l'API d'administration de Caddy (port 2019 non publié).
  L'agrégateur relit les adresses à chaque sondage et rétablit les amonts si
  Caddy redémarre avec son ancien environnement.
- Les noms d'équipe remplacent ceux des rôles sur le tableau, dans le fil et
  le classement ; `./bin/farci room` les affiche.
- L'accueil de l'équipe 1 montre l'onglet en lecture seule : les adresses se
  déclarent sur le Pi.

### « Ensuite : » à la fin de chaque commande

- Chaque `./bin/farci <cible>` se termine par la ou les commandes à lancer
  ensuite, différentes en cas d'échec (« Pour comprendre et réparer : »).
  Elles tiennent compte de la brique (`up 02-inference/ollama` propose
  `create-model.sh`), de l'équipe (`FARCI_EQUIPE`, `--equipe N`) et de
  l'adresse de la salle. Aussi après `./preload.sh`, `./verify-airgap.sh` et
  les scripts lancés directement (Gitea, runner, `create-model.sh`…).
- Un seul registre : `scripts/suite.def` (clé, quand, commande, pourquoi),
  vérifié par `./bin/farci selftest` : chaque cible a sa suite, chaque
  commande citée existe.
- Sur la sortie d'erreur, seulement dans un terminal : les sorties JSON et les
  tubes restent propres. `FARCI_SUITE=0` les coupe, `FARCI_SUITE=1` les force.
- llama.cpp sert Qwen3.5-2B quand le 9B n'est pas préchargé (poste léger).

### Deux stacks par brique, préchargement adapté au poste

- `./preload.sh` (sans option) précharge **ce poste** : la brique de son équipe
  (`--equipe N` ou `FARCI_EQUIPE`), seulement ce que la machine pourra servir.
  Grosse configuration (GPU NVIDIA ou 32 Go de RAM, `scripts/lib/machine.sh`) :
  Ollama + Ornith-1.5-9B, Langfuse ; sinon llama.cpp + Qwen3.5-2B, Phoenix seul.
  `--core` et `--all` restent pour le poste du formateur ; `bootstrap` ne
  conseille plus `--core` aux étudiants. `verify-airgap.sh --equipe N` vérifie
  le poste.
- Deux options au plus par brique : oMLX et Qwen3.8-27B sont hors atelier
  (plus au casting, ni au préchargement, ni au tableau) ; Flowise devient une
  démonstration du formateur (`--all`). Les alias de la passerelle ne changent pas.
- Casting : Ollama exige une grosse configuration ; les rôles qui en ont besoin
  sont servis en premier.
- Tableau : la ligne Inference est verte avec Ollama **ou** llama.cpp
  (`une_parmi`) ; llama.cpp devient une brique cœur.
- llama.cpp est compilé pour la machine qui le servira (plus de build
  multi-architecture qui échouait sans `containerd`) ; le groupe Langfuse
  précharge aussi PostgreSQL.

### Rejoindre la salle sans rien (étudiant sans `git clone`)

- `./bin/farci partage maj` : le Pi publie le dépôt (`git clone
  http://<Pi>/farci.git`, HTTP simple servi par Caddy), `farci.tar.gz`,
  `farci.zip` et un `network.env` étudiant (adresse de la salle, aucune IP
  d'équipe). `partage wheels` (avec Internet, inclus dans `preload.sh --pi`)
  télécharge les wheels Python pour Linux/WSL et Mac, Python 3.11–3.13
  (`PARTAGE_*` dans `versions.env`) ; `partage offline-x86 <dossier>` partage
  les images préparées sur une machine x86.
- Page **`/rejoindre`** (servie par l'agrégateur) : les commandes à copier,
  l'état de ce qui est publié, le lien de la forge si elle tourne.
- `FARCI_WHEELS_URL=http://<Pi>/partage/wheels/ ./bin/farci bootstrap` :
  installe `.venv/` depuis le Pi quand `offline/wheels/` est vide.
- `preload.sh --pi` précharge aussi la forge (`gitops`) : Gitea peut tourner
  sur le Pi (DEPLOY-PI.md).

### Le tableau de la salle (écran projeté, iPad)

- Chaque tuile (et chaque puce bonus) s'ouvre en **fiche** : à quoi sert la
  brique, l'analogie médicale, le contrat, qui la rend (bouton vers le service
  **de l'étudiant** sur son poste dès qu'il est déclaré, et vers la doublure
  du Pi), et un **test en direct** par l'accueil (modèles servis,
  pseudonymisation d'une phrase…). Lien direct : `/tableau#fiche=<Ligne>`.
- `http://<accueil>/` → `/tableau` : page web servie par l'agrégateur de
  santé, sans ressource externe. Tuiles par brique (✅ équipe, 🛟 référence,
  ⛔ panne), jauge du pipeline, classement des équipes, fil de la séance,
  chrono et phase du déroulé, bandeaux de panne et de bascule, confettis et
  annonce plein écran de CLINICAL PIPELINE READY. Plein écran et écran
  allumé sur iPad.
- Points automatiques (`01-network-dashboard/health-aggregator/tableau.py`) :
  une brique compte quand l'accueil la sert ; barème positif seulement.
  Sauvegarde dans un volume ; `./bin/farci tableau reset` pour une nouvelle
  séance.
- L'agrégateur monte le dépôt en lecture seule : bascules (`rescue`) et
  pannes de chaos sont visibles du tableau et de `/status`.
- `pipeline_state` expose aussi la liste nommée des exigences.
- Tests : `tests/test_tableau.py`.

### Déploiement sur un Raspberry Pi 5 seul

- `DEPLOY-PI.md` : séquence complète et vérifiée pour un Pi 5 (8 Go, Debian
  13 arm64) seul sur un LAN : configuration, préchargement, démarrage,
  vérifications, ports, disque, durée, état arm64 de chaque image.
- `make core-up`, `make dashboard-up`, `make health` (cahier des charges
  FARCI.md) : pile de référence + Docling, adresses utiles, code 0 si le
  service rendu est READY.
- `./preload.sh --pi` (alias de `--reference`, profil un seul modèle 2B) ;
  le mode inclut désormais le manifeste.
- `verify-airgap.sh` : le contrôle compose ne refuse plus les constructions
  locales (agents Arcane), seulement les contextes distants et
  `pull_policy: always`.

### EDS-NLP (AP-HP) — pseudonymiser et extraire des entités

- Service `04-clinical-documents/eds-nlp/` (équipe 4) : `POST /v1/pseudonymiser`
  (EDS-Pseudo, règles + contexte patient, sans PyTorch) et `POST /v1/entites`
  (pseudonymise, puis `eds.llm_markup_extractor` d'EDS-NLP 0.23.0 balise
  diagnostic, intervention, complication, stade via la passerelle de la
  salle). Contrat 4 dans `docs/CONTRACTS.md`.
- Brique **cœur, hors READY** : ligne `EDS-NLP` au tableau, route `/eds` à
  l'accueil (`FARCI_EDS_URL`), doublure sur le Pi, `rescue eds`
  (`rescue 4` bascule Docling et EDS-NLP).
- Image `farci/eds-nlp` construite au préchargement
  (`./preload.sh --only build_eds_nlp`, incluse dans `--core` et
  `--reference`) : compilateur seulement sans paquet précompilé (ARM).
  EDS-Pseudo cloné au commit figé (`EDS_PSEUDO_COMMIT`), pas de PyPI.
- `./bin/farci eds pseudo | entites | compare` : client en Python standard ;
  le contexte patient vient du registre du jeu de données. Étape 2,
  parcours D (10 min) : entités contre JSON, négations manquées.
- Runtime rejoué : mode « annotation XML » (lexique fixe) pour le plan C.
- `rehearse` : étape `eds-nlp` (avertissement). Tests :
  `tests/test_eds_nlp.py`, `tests/test_eds_nlp.sh`.

### Lot 4 — répéter et piloter

- **`./bin/farci rehearse`** : répétition générale de J-1, moins de 15 min,
  verdict PASS / FAIL. Poste (outillage, tests, configuration, images, plan C
  noté contre le gold), salle (accueil, service rendu, contrat, extraction
  réelle) et, sur le Pi, secours (rescue, scénarios 01-04-05-06-07,
  reset-all). Budget et gravité par étape, piste de réparation, rapport dans
  `datasets/reports/`.
- **`./bin/farci forge-sync`** : GitHub source de vérité, Gitea `main` en
  avance rapide seulement (`status`, `push`, `bundle`, `from-bundle`,
  `rapatrier`) ; divergence refusée sans jamais forcer ; branche `seance`
  pour les PR de la séance. `CONTRIBUTING.md`, « Deux forges ».
- **`docs/PILOTAGE.md`** : la feuille imprimable du formateur (avant, minutage
  et points de décision, commandes, incidents, les dix messages et leur moment).
- **Fiches débutant** `docs/wiki/equipe-XX.md` et `chaos.md` : objectif, 5 à 8
  étapes, sonde, « bloqué depuis 10 minutes ? », bonus. Les anciennes
  solutions « from scratch » (réseau Docker partagé) sont retirées.
- `./bin/farci bootstrap` installe les dépendances Python **hors ligne** dans
  `.venv/` (pip refuse le Python système sur Raspberry Pi OS et Homebrew) ;
  `bin/farci` l'utilise une fois l'installation réussie ; `doctor` le signale.
  `./preload.sh --reference` télécharge aussi les wheels.
- Corrigés : `env-check` plantait (`$1: unbound variable`) ; `FARCI_DATA_DIR`
  de `.env` était toujours ignoré (valeur imposée avant la lecture) ;
  `extract --replay` exportait encore des traces ; Open WebUI d'équipe
  inaccessible (inscription fermée sans aucun compte) ; libellés de lignes
  faux dans trois TUTORIAL ; `verify-images --reference`.

### Lot 3 — plans B

- **Adressage « une IP de machine + un port par service »**
  (`config/network.env.example` réécrit) : plus de réseau Docker partagé ni
  d'IP statique de conteneur. `REFERENCE_IP` (le Pi) est la seule adresse
  utile sur un poste étudiant ; les IP d'équipe sont déclarées sur le Pi.
  Chaque service a son propre port publié, vérifié unique par `network-check`.
- **Pile de référence** `reference/` (Raspberry Pi 5, 8 Go, arm64) : accueil
  Caddy de la salle, agrégateur, runtime rejoué, LiteLLM, Phoenix, Open WebUI ;
  options Ollama (modèle 2B) et Docling. Guide : `reference/README.md`
  (préparation, Wi-Fi en point d'accès, secours, ce qui reste à vérifier).
  `./preload.sh --reference`, à lancer sur le Pi.
- **Repli pédagogique** : l'accueil (même Caddyfile pour le Pi et l'équipe 1)
  sert, pour chaque route, la brique de l'équipe puis celle de la référence
  (`scripts/services.py upstreams`). Tableau : `✅ UP` (équipe) / `🛟 REF`
  (référence), deux verdicts (pipeline des équipes, service rendu), ligne
  « PANNE EN COURS ». Il montre ce que l'accueil **sert**, pas seulement ce
  qui répond (`scripts/board.py`).
- Nouvelles commandes : `./bin/farci room` (déclarer une machine ;
  `room set reference <ip>` en cas de changement de réseau), `rescue
  <brique>` / `rescue --off`, `reset-all`, `replay`.
- **Plan C, runtime rejoué** (`reference/replay/`) : contrat OpenAI,
  réponses enregistrées synthétiques (prompt v1 et v2, flux SSE,
  `reasoning_content`), modèle `med-chaos` hors schéma pour le scénario 04.
  `./bin/farci extract --replay` : extraction sans Docker, modèle ni réseau.
  Client Python sans SDK obligatoire (repli `urllib`).
- Runtimes : tous servent le nom logique `med-extraction` ;
  `02-inference/ollama/create-model.sh principal|secours|auto` (modèle 2B
  sous 16 Go de RAM). LiteLLM passe par l'accueil (`/runtime/v1`) et n'exige
  plus de base ni de clé (clés et quotas : bonus PostgreSQL).
- **Chaos à l'accueil** : `exclude` (la référence répond) ou `block`
  (personne ne répond) d'une route, réversibles ; chaque scénario annonce son
  attendu puis le **vérifie** (`ATTENDU` / `INATTENDU`, code de sortie).
- `./bin/farci doctor` : Docker absent n'est plus bloquant (plan B indiqué),
  section « Réseau de la salle ».
- `docs/INSTRUCTOR_GUIDE.md` : table incident → symptôme → commande → temps
  (Docker, RAM, lenteur, passerelle, port, IP, Wi-Fi, réseau absent, retard,
  étudiant sans machine). `docs/ARCHITECTURE.md` § 3, `docs/CHAOS.md`,
  `docs/AIRGAP.md` (arm64) et les TUTORIAL 01–03 alignés.
- Tests : `tests/test_replay.py`, `tests/test_fallback.py` (amonts, rescue,
  chaos, tableau contre de vrais serveurs HTTP). Les tests d'intégration
  visent l'accueil, ou la brique locale si son IP n'est pas déclarée.

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
