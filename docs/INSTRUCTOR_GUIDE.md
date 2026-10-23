# Guide formateur

Ce document est la logistique de l'atelier. Il ne contient pas de théorie : il
contient ce qu'il faut **faire, dans quel ordre, et quoi vérifier**.

---

## J-7 — Préparation avec Internet

- [ ] Cloner le dépôt sur la machine de référence
- [ ] Vérifier Docker et Python : `./bin/farci doctor`
- [ ] Fixer les versions : elles sont dans `versions.env`, déjà vérifiées
- [ ] `./preload.sh --core` (compter **une bonne demi-journée** selon le débit)
- [ ] `./preload.sh --only models_qwen38` si des postes le justifient
- [ ] `scripts/lock-requirements.sh` pour verrouiller et télécharger les wheels
- [ ] Vérifier les empreintes : `./bin/farci verify-manifest`
- [ ] `./bin/farci verify-airgap`
- [ ] Répartir `$FARCI_DATA_DIR` (clé USB, disque, ou copie locale par poste)
- [ ] Tester le démarrage sur **une** machine, complètement, une fois
- [ ] Le jeu de données est versionné (`datasets/raw/*.txt`, `datasets/gold/`) ;
      pour la démonstration Docling : `./bin/farci generate-dataset --pdf`
- [ ] `./bin/farci ci` est vert sur la machine de référence
- [ ] Imprimer ou projeter `./bin/farci help` et le tableau de progression

### Les deux erreurs qui coûtent le plus de temps

1. **Oublier que `make` peut manquer.** Le dépôt fonctionne sans : `make X` et
   `./bin/farci X` sont équivalents. Le dire en début de séance.
2. **Oublier que `git clone` ne suffit pas.** Il faut aussi `$FARCI_DATA_DIR`.
   Le dire **avant** que les étudiants ne perdent vingt minutes.

---

## J-1 — Dernière vérification

- [ ] Rejouer `./preload.sh --core` : doit être rapide (tout est là)
- [ ] `./verify-airgap.sh --strict` doit passer
- [ ] `./bin/farci lint` est vert
- [ ] `./bin/farci selftest` est vert
- [ ] Les adresses de `config/network.env` correspondent au **vrai** réseau de la salle
- [ ] Chaque équipe a une adresse attitrée
- [ ] Vérifier la RAM et le disque de chaque poste : `./bin/farci doctor`
- [ ] Avoir un plan B : une machine de secours avec les images déjà chargées

---

## J0 — Dans la salle

- [ ] L'écran de projection affiche `./bin/farci status --watch`
- [ ] Chaque étudiant a lancé `./bin/farci doctor` et `./bin/farci bootstrap`
- [ ] Chaque équipe a une branche créée
- [ ] Le tableau de bord affiche `🔴 🔴 🔴 🔴 🔴 🔴 🔴` : c'est **normal et voulu**
- [ ] Rappeler les 3 étapes à voix haute avant de commencer

---

## Déroulé conseillé

| Moment | Durée | Activité | Point d'attention |
|---|---|---|---|
| Introduction | 30 min | les 3 étapes, le vocabulaire, le tableau de bord | ne pas montrer le code tout de suite |
| Étape 1 | 2 h 30 | chaque équipe monte sa brique | faire applaudir chaque passage au vert |
| Bascule | 15 min | `CLINICAL PIPELINE READY` | **moment clé**, tout le monde le voit |
| Étape 2 | 1 h 30 | extraction clinique, 3 parcours | insister sur la validation |
| Évaluation | 20 min | `./bin/farci evaluate` | comparer les parcours entre eux |
| Étape 3 | 1 h | les scénarios de chaos | le scénario 07 doit rester vert |
| Clôture | 20 min | chacun explique une différence avec ses mots | c'est le critère de réussite |

---

## Les questions que l'on vous posera, et la réponse courte

| Question | Réponse en une phrase |
|---|---|
| « C'est quoi la différence entre un modèle et un runtime ? » | Le modèle est le fichier de connaissances, le runtime est le logiciel qui l'exécute — comme un livre et la personne qui le lit. |
| « Pourquoi ne pas appeler l'API directement ? » | Parce qu'alors ton application dépend d'un fournisseur, et qu'un jour tu voudras le remplacer. |
| « Le modèle a-t-il inventé des données ? » | Peut-être : c'est un composant probabiliste. C'est pour cela qu'on valide avant d'écrire. |
| « F1 de 0,84, c'est bon ? » | Sans gold standard, ce chiffre ne veut rien dire. Avec, il veut dire qu'il reste 16 % d'écart à expliquer. |
| « Pourquoi ça marche sans Internet ? » | Parce que tout a été préchargé, et que rien dans la chaîne ne dépend d'un service distant. |
| « C'est de l'IA de Supersante ? » | Non. C'est de l'ingénierie : contrats, versions, tests, mesure. L'IA n'en est qu'une brique. |

---

## Si ça ne marche pas

| Symptôme | Cause probable | À faire |
|---|---|---|
| `permission denied` sur un script | bit `+x` manquant | `chmod +x scripts/cmd/*.sh bin/farci` (le lint le signale) |
| une cible n'apparaît pas dans `help` | registre `targets.def` mal formé | `./bin/farci selftest` dit exactement laquelle |
| `adresse non résolue` | `config/network.env` absent | `cp config/network.env.example config/network.env` |
| une image Docker manque | préchargement incomplet | `./bin/farci verify-images`, puis `docker load -i offline/images/<image>.tar` |
| `CLINICAL PIPELINE` reste rouge | un `critical: true` est tombé | `./bin/farci status --json` pour voir lequel |
| le modèle ne démarre pas | RAM insuffisante | modèle de secours Qwen3.5-2B (`FARCI_MODEL_CI`, alias `med-extraction-lite`) |

---

## Après l'atelier

- [ ] `./bin/farci chaos reset` et vérifier le retour au vert
- [ ] Récupérer les extractions : `datasets/extracted/`
- [ ] Comparer les scores des trois parcours : `./bin/farci evaluate --report-dir datasets/reports`
- [ ] Noter ce qui a fonctionné et ce qui a bloqué, phase par phase
- [ ] Conserver `versions.env` et le manifeste : c'est ce qui rendra l'atelier
      reproductible l'année prochaine

---

## Voir aussi

- `docs/AIRGAP.md` — le préchargement en détail
- `docs/WORKSHOP_FLOW.md` — le déroulé des étapes
- `docs/CHAOS.md` — les scénarios et leur résultat attendu
- `CONTRIBUTING.md` — le flux Git du dépôt
