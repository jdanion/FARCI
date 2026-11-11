# Guide formateur

Ce document est la logistique de l'atelier. Il ne contient pas de théorie : il
contient ce qu'il faut **faire, dans quel ordre, et quoi vérifier** pour tenir
**4 heures**, seul, sans panne bloquante. Le déroulé pédagogique est dans
`docs/WORKSHOP_FLOW.md`.

---

## J-7 — Préparation avec Internet

- [ ] Préparer le Pi (pile de référence et Wi-Fi de la salle) :
      **`reference/README.md`**, dont `./preload.sh --reference` lancé **sur le Pi**
- [ ] Cloner le dépôt sur une machine x86 pour préparer les postes étudiants
- [ ] Vérifier Docker et Python : `./bin/farci doctor`
- [ ] Les versions sont figées dans `versions.env` (tags vérifiés dans les registres)
- [ ] Poste du formateur : `./preload.sh --core` (compter **une bonne demi-journée**
      selon le débit) : images sauvegardées en `.tar`, modèle principal **et** modèle 2B
- [ ] Postes étudiants : `./preload.sh --equipe <N>` sur chaque poste (ou
      `FARCI_EQUIPE` dans `config/workshop.env`) : seulement la brique de l'équipe,
      selon la machine — Ollama + 9B et Langfuse sur les grosses configurations
      (GPU NVIDIA ou 32 Go), llama.cpp + 2B et Phoenix seul ailleurs
- [ ] `scripts/lock-requirements.sh` pour verrouiller et télécharger les wheels
- [ ] Vérifier les empreintes : `./bin/farci verify-manifest`
- [ ] `./bin/farci verify-airgap`
- [ ] Miroir de secours, au cas où Hugging Face ou un registre Docker serait
      bloqué ou saturé depuis la faculté :
      `./bin/farci partage publier <destination rsync>` (modèles, wheels, images
      de cette machine), puis contrôler `FARCI_FICHIERS_URL` (`.env`) depuis un
      autre poste. Les étudiants n'ont plus qu'à cloner et lancer `./preload.sh`
- [ ] Écrire aux étudiants : l'adresse GitHub du projet, `git` à installer,
      `git clone` puis `./preload.sh --equipe <N>` ; joindre `docs/GIT.md`
- [ ] Tester le démarrage **de toute la chaîne cœur** sur une machine, une fois
- [ ] Le jeu de données est versionné (`datasets/raw/*.txt`, `datasets/gold/`) ;
      pour la démonstration Docling : `./bin/farci generate-dataset --pdf`
- [ ] `./bin/farci ci` est vert sur la machine de référence
- [ ] Recueillir le matériel des étudiants (RAM, Mac, GPU) et lancer
      `./bin/farci casting --students eleves.json` : la section « Briques cœur
      sans équipe » dit ce que le formateur devra servir lui-même

### Les deux erreurs qui coûtent le plus de temps

1. **Oublier que `make` peut manquer.** Le dépôt fonctionne sans : `make X` et
   `./bin/farci X` sont équivalents. Le dire en début de séance.
2. **Oublier que `git clone` ne donne que le code.** Les modèles et les images
   viennent de `./preload.sh` (sites d'origine, miroir en secours). Le dire **avant** que les
   étudiants ne perdent vingt minutes.

---

## J-1 — La répétition générale : `./bin/farci rehearse`

Une commande, moins de 15 minutes, un verdict **PASS / FAIL** :

```bash
./bin/farci rehearse          # sur le Pi : poste + salle + secours (rescue, chaos, reset-all)
./bin/farci rehearse          # sur un portable branché au Wi-Fi du Pi : poste + salle
```

| Partie | Ce qui est vérifié |
|---|---|
| poste | outillage (selftest), tests unitaires, configuration, images (`--reference` sur le Pi), modèles, **plan C** (extraction rejouée + score ≥ 0,9) |
| salle | accueil joignable, service rendu, Docling (avertissement), contrat de la passerelle, 3 dossiers extraits par l'accueil |
| secours | `rescue inference` visible au tableau, scénarios 01, 04, 05, 06, 07 avec leur attendu, `reset-all` sans reste |

Chaque étape en échec affiche ses dernières lignes et **la piste de
réparation**. Le rapport est écrit dans `datasets/reports/rehearse-*.txt`.
Un `FAIL` se corrige la veille, puis on relance.

Reste à faire à la main :

- [ ] `./verify-airgap.sh --strict` sur un poste étudiant type
- [ ] la RAM et le disque de chaque poste connu : `./bin/farci doctor`
- [ ] ouvrir la forge Gitea sur le Pi (toute la salle s'en sert) :
      `./bin/farci up 00-gitops`, `00-gitops/gitea/bootstrap.sh`,
      `./bin/farci forge-sync push`, `00-gitops/post-provision.sh`, puis
      `./bin/farci room set gitea <IP du Pi>` ; depuis un portable : cloner,
      créer une branche, pousser avec le compte `equipe-1`
- [ ] imprimer `docs/PILOTAGE.md`

## J0 — Dans la salle (avant l'arrivée des étudiants)

- [ ] Le Pi crée le Wi-Fi (`sudo nmcli con up farci-ap`) et porte la pile de
      référence (`./bin/farci up reference`)
- [ ] L'écran de projection affiche le **tableau de la salle** :
      `http://<REFERENCE_IP>/` (un iPad ou un navigateur suffit ; à défaut,
      `./bin/farci status --watch` sur le Pi). Tout est `🛟`, c'est **normal et
      voulu** — aucune équipe n'a encore livré, la référence rend le service
- [ ] `./bin/farci seance nouvelle` sur le Pi : équipes, adresses, scores et
      chrono à zéro (la répétition de la veille ne compte pas ; elle est
      sauvegardée dans `$FARCI_DATA_DIR/seances/`)
- [ ] L'adresse d'Open WebUI de la référence (`REFERENCE_IP:OPEN_WEBUI_PORT`)
      est notée au tableau, pour qui n'a pas de machine utilisable
- [ ] La forge est à jour (`./bin/farci forge-sync push`), le partage publié
      (`./bin/farci partage maj`) ; au tableau : `http://<REFERENCE_IP>/rejoindre`,
      l'adresse de la forge, les comptes `equipe-<N>` et le mot de passe de la salle
- [ ] Les fiches d'équipe sont prêtes (`docs/wiki/equipe-XX.md`, `./bin/farci read <équipe>`)
- [ ] La liste des équipes (sortie de `./bin/farci casting`) est affichée

---

## Le minutage, et ce qu'on coupe si on prend du retard

| Horaire | Moment | À dire / à faire | Si on a du retard |
|---|---|---|---|
| 0:00 – 0:20 | Accueil | les 3 étapes, `make` ≠ obligatoire ; git en trois lieux (GitHub, la forge, votre machine) ; chacun clone, crée sa branche (`./bin/farci poste`) et lance `./bin/farci doctor` | passer le vocabulaire en 5 min, il revient à la clôture ; **ne pas** couper le clone et la branche |
| 0:20 – 0:30 | Étape 1 : lancement | chaque équipe lit sa fiche et commite la fiche de son poste, objectif minimal annoncé | — |
| 0:30 – 1:15 | Étape 1 : objectif minimal | déclarer chaque machine (onglet Formateur du tableau, ou `room set`) ; faire applaudir chaque passage de 🛟 à ✅ | à **1:00**, une équipe encore 🛟 continue à diagnostiquer, la référence sert à sa place : personne n'attend |
| ~1:30 | **CLINICAL PIPELINE READY** | moment clé : on le montre à tous | ne pas attendre au-delà de **1:40** : la suite se joue avec ce que sert la salle (✅ ou 🛟) |
| 1:15 – 1:35 | Push et Pull Requests | chaque équipe pousse sa branche et relit la PR d'une autre | une équipe en retard pousse à la pause |
| 1:35 – 1:50 | Bonus et démos | une PR fusionnée devant la salle, puis Langfuse, MLflow, llama.cpp | **première marge** : supprimer les démos bonus, garder la fusion |
| 1:50 – 2:00 | Pause | — | **ne jamais la supprimer** : c'est là que le formateur répare |
| 2:00 – 2:50 | Étape 2 | parcours Python sur le jeu rapide ; Open WebUI ; Flowise en démo 10 min | jeu rapide seulement (`--subset quick`), Flowise supprimée |
| 2:50 – 3:10 | Évaluation | classement projeté, une trace lue ensemble | une seule trace |
| 3:10 – 3:45 | Étape 3 | 01, 04, 06 (ou 05), 07 ; pari de la salle avant chaque panne | **deuxième marge** : garder 01, 04 et 07 seulement |
| 3:45 – 4:00 | Clôture | chacun explique une notion avec ses mots | jamais coupée : c'est le critère de réussite |

**Retard de 20 minutes** : on supprime les démos bonus (−15 min) et le scénario
06/05 (−8 min), on garde la pause, l'évaluation et la clôture intactes. Les
briques encore `🛟` y restent : la suite ne dépend pas d'elles.

---

## Objectif minimal de chaque équipe

| Équipe | Vert quand… | Commande clé |
|---|---|---|
| 1 Réseau | ligne Network | `./bin/farci up 01-network-dashboard` |
| 2 Inférence | ligne Inference | `./bin/farci up 02-inference/ollama` puis `02-inference/ollama/create-model.sh` |
| 3 Passerelle | ligne LLM Gateway | `./bin/farci up 03-llm-gateway/litellm` |
| 4 Documents | lignes Documents et EDS-NLP + pseudonymisation testée | `./bin/farci up 04-clinical-documents/docling` puis `./bin/farci up 04-clinical-documents/eds-nlp` |
| 5 Observabilité | ligne Observability | `./bin/farci up 05-observability/phoenix` |
| 7 Applications | ligne Open WebUI | `./bin/farci up 07-applications/open-webui` |

Les briques bonus (GitOps, MLflow, Langfuse, Bifrost, Uptime Kuma, agents
Arcane) n'entrent **jamais** dans `CLINICAL PIPELINE READY` : elles
apparaissent sur la ligne « Bonus » du tableau (`./bin/farci status --all` pour
le détail).

---

## Les questions que l'on vous posera, et la réponse courte

| Question | Réponse en une phrase |
|---|---|
| « C'est quoi la différence entre un modèle et un runtime ? » | Le modèle est le fichier de connaissances, le runtime est le logiciel qui l'exécute — comme un livre et la personne qui le lit. |
| « Pourquoi ne pas appeler l'API directement ? » | Parce qu'alors ton application dépend d'un fournisseur, et qu'un jour tu voudras le remplacer. |
| « Le modèle a-t-il inventé des données ? » | Peut-être : c'est un composant probabiliste. C'est pour cela qu'on valide avant d'écrire. |
| « F1 de 0,84, c'est bon ? » | Sans gold standard, ce chiffre ne veut rien dire. Avec, il veut dire qu'il reste 16 % d'écart à expliquer. |
| « Pourquoi ça marche sans Internet ? » | Parce que tout a été préchargé, et que rien dans la chaîne ne dépend d'un service distant. Internet ne sert qu'à récupérer le code et les fichiers. |
| « Pourquoi Gitea si on a GitHub ? » | Pour montrer qu'une forge s'héberge : mêmes commandes, mais le code reste dans les murs. Un hôpital fait ce choix. |
| « Pourquoi une branche par machine ? » | Parce que chaque machine a son matériel et son rôle : la branche porte ces différences sans toucher au projet commun. |
| « Pourquoi le modèle n'est pas dans git ? » | Git garde tout pour toujours : 6 Go à chaque version. Les gros fichiers vont sur un serveur de fichiers, git garde leur adresse et leur empreinte. |
| « Pourquoi Phoenix n'est pas dans READY ? » | Parce que l'observabilité n'est pas sur le chemin de production : si elle tombe, le soin continue. |
| « C'est de l'IA de Supersante ? » | Non. C'est de l'ingénierie : contrats, versions, tests, mesure. L'IA n'en est qu'une brique. |

---

## Si ça ne marche pas : incident → symptôme → commande → temps

Règle unique : **aucune équipe n'attend une réparation**. La référence sert
pendant que l'équipe diagnostique. Toutes les commandes `room`, `rescue`,
`reset-all` se lancent **sur le Pi**.

| Incident | Symptôme | Commande de repli | Temps |
|---|---|---|---|
| Docker absent ou cassé sur un poste | `./bin/farci doctor` : docker absent / injoignable | rien à faire côté salle : la ligne reste `🛟 REF`. L'équipe travaille en binôme sur une autre machine, ou suit la brique sur l'Open WebUI de la référence | 1 min |
| RAM insuffisante pour le 9B | conteneur Ollama tué, `out of memory`, ou doctor < 16 Go | `02-inference/ollama/create-model.sh secours` (même nom `med-extraction`, rien d'autre à changer) | 3 min |
| Modèle trop lent (> 60 s par dossier) | extraction qui traîne, tableau ✅ mais salle bloquée | `./bin/farci rescue inference` ; plus tard `./bin/farci rescue --off inference` | 10 s |
| Passerelle de l'équipe tombée | ligne `LLM Gateway` en `🛟 REF` | rien : l'accueil a basculé seul. Si elle répond mal : `./bin/farci rescue passerelle` | 0 / 10 s |
| Conflit de port sur un poste | `port is already allocated` au `up` | `./bin/farci doctor` (section ports) ; arrêter le service qui occupe le port. Chaque service a son propre port (`config/network.env`) | 2 min |
| Machine déclarée à la mauvaise IP | ligne restée `🛟 REF` alors que l'équipe est verte chez elle | onglet Formateur (IP et état de chaque brique), ou `./bin/farci room` puis `./bin/farci room set <n> <ip>` | 1 min |
| Wi-Fi de la salle tombé | plus aucun poste ne joint `REFERENCE_IP` | sur le Pi : `sudo nmcli con up farci-ap`. Sinon autre point d'accès et, sur chaque poste, `./bin/farci room set reference <ip du Pi>` (voir `reference/README.md`) | 1 / 5 min |
| Plus de réseau du tout | idem, sans solution | chaque équipe continue sur sa machine (`./bin/farci test` vise la brique locale) ; étape 2 : `./bin/farci extract --replay` | 2 min |
| Accueil de la salle (Pi) muet | `./bin/farci status` : tout DOWN | sur le Pi : `./bin/farci up reference` | 2 min |
| Chaos qui ne revient pas au vert | `PANNE EN COURS` sous le tableau | `./bin/farci reset-all` | 30 s |
| Image absente sur un poste | `démarrage impossible — image absente ?` | `./bin/farci verify-images`, puis `./preload.sh --equipe <N> --skip-existing` (registre, sinon serveur de fichiers) ; sans Internet : `http://<REFERENCE_IP>/partage/` puis `docker load -i <image>.tar` | 3 min |
| Push refusé sur la forge | `Authentication failed`, `protected branch` | `./bin/farci poste` sur le poste : compte `equipe-<N>`, branche `poste/…` et non `main` ou `seance` | 1 min |
| GitHub injoignable | `git clone` échoue | cloner depuis la forge de la salle (`/rejoindre`) : c'est le même projet | 1 min |
| Étudiant sans machine utilisable | — | binôme, ou Open WebUI de la référence : `http://REFERENCE_IP:OPEN_WEBUI_PORT` | 0 |
| **20 minutes de retard** | horloge | voir « Le minutage » : démos bonus et un scénario supprimés, les briques en 🛟 y restent | — |

Les causes « de dépôt », plus rares :

| Symptôme | Cause probable | À faire |
|---|---|---|
| `permission denied` sur un script | bit `+x` manquant | `chmod +x scripts/cmd/*.sh bin/farci` (le lint le signale) |
| une cible n'apparaît pas dans `help` | registre `targets.def` mal formé | `./bin/farci selftest` dit exactement laquelle |
| `config/network.env` absent | première installation | `cp config/network.env.example config/network.env` |
| `UP_PASSERELLE manquant` | `docker compose up` lancé à la main | toujours `./bin/farci up <brique>` |
| `CLINICAL PIPELINE` reste `DEGRADED` | une exigence manque | le tableau affiche la liste « Il manque » ; `./bin/farci status --json` pour le détail |

---

## Après l'atelier

- [ ] `./bin/farci reset-all` et vérifier le retour au vert
- [ ] Garder le travail de la séance : `./bin/farci forge-sync rapatrier seance`,
      puis une Pull Request sur GitHub (`CONTRIBUTING.md`, « Deux forges »)
- [ ] Récupérer les extractions : `datasets/extracted/`
- [ ] Archiver le classement : `./bin/farci evaluate --report-dir datasets/reports`
- [ ] Noter ce qui a fonctionné et ce qui a bloqué, moment par moment
- [ ] Conserver `versions.env` et le manifeste : c'est ce qui rendra l'atelier
      reproductible l'année prochaine

---

## Voir aussi

- `docs/PILOTAGE.md` — la feuille imprimable de la séance
- `docs/WORKSHOP_FLOW.md` — le déroulé des étapes et les objectifs par équipe
- `docs/GIT.md` — le parcours git des étudiants
- `docs/AIRGAP.md` — le préchargement, GitHub et le serveur de fichiers
- `docs/CHAOS.md` — les scénarios et leur résultat attendu
- `reference/README.md` — le Pi : pile de référence, Wi-Fi de la salle, secours
- `CONTRIBUTING.md` — le flux Git du dépôt
