# Déroulé du workshop — 4 heures

Trois étapes, une séance de **240 minutes**, un seul formateur. On construit,
on utilise, on casse — et, d'un bout à l'autre, **on se sert de git** : chaque
étudiant clone le projet, crée la branche de son poste, la pousse sur la forge
de la salle et la fait relire (`docs/GIT.md`). Ce document dit **quoi** se passe et **pourquoi** ;
`docs/INSTRUCTOR_GUIDE.md` dit **comment** le piloter.

---

## Le minutage

| Horaire | Durée | Moment | Ce qui doit être vrai à la fin |
|---|---|---|---|
| 0:00 – 0:20 | 20 min | **Accueil, en ligne** : les 3 étapes, le vocabulaire ; chacun finit de cloner et de télécharger sa brique. Puis **le basculement** : tout le monde rejoint `FARCI-SALLE` | chaque étudiant sait dans quelle équipe il est, a son clone, **sa branche**, sa brique, et a lancé `./bin/farci poste salle` puis `./bin/farci doctor` |
| 0:20 – 1:50 | 90 min | **Étape 1 — Construire** : équipes cœur seulement | `CLINICAL PIPELINE READY` sur le tableau |
| 1:50 – 2:00 | 10 min | **Pause** | — |
| 2:00 – 2:50 | 50 min | **Étape 2 — Utiliser** : parcours Python (principal) et Open WebUI ; EDS-NLP (10 min) ; Flowise en démo | chaque équipe a une run dans `datasets/extracted/` |
| 2:50 – 3:10 | 20 min | **Évaluation** et lecture d'une trace | le classement des runs est projeté, une trace est lue ensemble |
| 3:10 – 3:45 | 35 min | **Étape 3 — Casser** : 4 scénarios pilotés par le formateur | chaque panne a été prédite, observée, réparée |
| 3:45 – 4:00 | 15 min | **Clôture** : chacun explique une notion avec ses mots ; ce que vous emportez | la branche de chaque poste est sur la forge ; chacun sait la pousser sur son fork GitHub |
| | **240 min** | | |

### Dans l'étape 1 (90 min)

| Horaire | Quoi |
|---|---|
| 0:20 – 0:30 | chaque équipe lit sa fiche débutant (`docs/wiki/equipe-XX.md`) et écrit la fiche de son poste (`./bin/farci poste nouveau`) : **premier commit** ; le formateur rappelle l'objectif minimal |
| 0:30 – 1:15 | **objectif minimal** : sa ligne passe au vert sur le tableau (45 min max) |
| 1:15 – 1:35 | test contractuel, puis **push et Pull Request** vers `seance`, relue par une autre équipe ; objectif bonus ; le formateur fait vivre le tableau |
| ~1:30 | **moment clé** : `CLINICAL PIPELINE READY` |
| 1:35 – 1:50 | marge : rattrapage des équipes en retard ; le formateur fusionne une Pull Request devant la salle, chacun la reçoit (`git fetch`, `git merge`) ; démos bonus (Langfuse, MLflow) |

### Dans l'étape 3 (35 min)

Quatre scénarios, environ 8 minutes chacun : **pari de la salle** (« survivra /
ne survivra pas »), panne, observation sur le tableau et dans les traces,
réparation, leçon en une phrase. Détail : `docs/CHAOS.md`.

| Ordre | Scénario | Pourquoi celui-là |
|---|---|---|
| 1 | **01** — runtime principal coupé | la redondance existe-t-elle vraiment ? L'extraction répond toujours (🛟) |
| 2 | **04** — JSON invalide | une sortie de LLM n'est pas une donnée : rien n'est écrit |
| 3 | **06** — passerelle de l'équipe coupée, **ou 05** — Docling coupé | point d'entrée stable / dépendance partielle |
| 4 | **07** — observabilité coupée | l'observabilité n'est pas sur le chemin de production |

---

## Deux temps : en ligne, puis en local

Un portable ne peut être que sur un Wi-Fi à la fois, et le Pi n'a qu'une
radio : la séance sépare donc ce qui demande Internet de ce qui se fait dans
la salle.

| Temps | Réseau | Ce qui s'y fait |
|---|---|---|
| **1. En ligne** — avant la séance, sinon de 0:00 à 0:20 | celui de la faculté, ou le sien | cloner depuis GitHub (**sans compte**), `./preload.sh --equipe <N>`, créer sa branche, premier commit |
| **Le basculement** — vers 0:20 | — | le formateur vérifie que chacun a son clone et sa brique, puis : « on passe en local » ; tout le monde rejoint `FARCI-SALLE` |
| **2. En local** — le reste de la séance | `FARCI-SALLE`, le Wi-Fi du Pi | `./bin/farci poste salle`, les trois étapes, push, Pull Requests ; **plus rien ne sort de la salle** |

Le basculement est un moment de la séance, pas un détail technique : c'est là
que l'on dit que les dossiers, les questions et les réponses resteront sur
place. Qui arrive sans clone le prend sur la forge du Pi (page `/rejoindre`).

## Qui héberge quoi

| Sur le Pi du formateur | Sur les machines des équipes |
|---|---|
| l'accueil : Caddy et le tableau de la salle | les runtimes et leurs modèles (équipe 2) |
| la forge Gitea, ses comptes `equipe-<N>` | la passerelle (équipe 3) |
| la doublure de chaque service (🛟) | les documents, l'observabilité, l'évaluation, les applications |

Ce dont toute la salle dépend est tenu par le Pi ; ce que l'on compare et que
l'on casse est tenu par les équipes. Les équipes 0 (forge) et 1 (accueil) ne
se constituent que si des étudiants veulent reprendre ces services.

## Le fil git de la séance

Git n'est pas une brique parmi d'autres : c'est ce que **chaque** étudiant
fait, quelle que soit son équipe.

| Moment | Geste | Ce qu'il apprend |
|---|---|---|
| en ligne | `git clone` depuis GitHub | un dépôt, c'est le projet **et** son historique |
| en ligne | `git switch -c poste/equipe-<N>-<surnom>` | une branche : sa version, sans toucher celle des autres |
| en ligne | `./bin/farci poste nouveau`, relecture, `git add`, `git commit` | adapter le projet à **son** matériel et à **son** rôle ; un commit s'explique |
| basculement | `./bin/farci poste salle`, puis `git remote -v` | un même projet, deux dépôts distants : `origin` (GitHub) et `salle` (la forge) |
| 1:15 | `git push -u salle …`, Pull Request vers `seance` | publier, demander une relecture |
| 1:15 – 1:50 | relire la PR d'une **autre** équipe | personne ne valide son propre travail |
| 1:35, puis à volonté | `git fetch salle`, `git merge salle/seance` | recevoir le travail commun |
| clôture | *Fork* sur GitHub, `git remote add`, `git push` | le projet continue après la salle ; on peut aussi héberger sa forge |

Les fichiers volumineux ne passent pas par git : `./preload.sh` les prend sur
leur site d'origine pendant le temps en ligne (`docs/AIRGAP.md`).

---

## Briques cœur et briques bonus

Le découpage fait foi dans `config/services.yaml` (champ `tier`).
`CLINICAL PIPELINE READY` ne dépend **que** de briques cœur : Caddy,
l'agrégateur de santé, **au moins un** runtime, LiteLLM et Docling. Phoenix est
une brique cœur pour son équipe, mais volontairement **hors** de READY : son
arrêt ne doit pas arrêter l'extraction (scénario 07).

| Équipe | Dossier | Cœur (étape 1) | Bonus ou démo du formateur |
|---|---|---|---|
| 1 | `01-network-dashboard/` | Caddy + health-aggregator, **tenus par le Pi** ; une équipe volontaire peut les reprendre | Uptime Kuma |
| 2 | `02-inference/` | Ollama + 9B (GPU ou 32 Go) **ou** llama.cpp + 2B (tout poste) | — |
| 3 | `03-llm-gateway/` | LiteLLM | clés et quotas, Bifrost |
| 4 | `04-clinical-documents/` | Docling + pseudonymisation + EDS-NLP (hors READY) | PDF convertis par Docling |
| 5 | `05-observability/` | Phoenix | Langfuse, collecteur OTel |
| 7 | `07-applications/` | Open WebUI prêt pour l'étape 2 | Flowise (démo) |
| 0 | `00-gitops/` | — (hors READY : la forge Gitea est **tenue par le Pi**) | reprise de la forge par une équipe volontaire, runner + CI |
| 6 | `06-evaluation/` | — (l'évaluation est en ligne de commande pour tous) | MLflow |
| 8 | `08-arcane-agents/` | — | agents de supervision, webhook GitOps |

Les équipes 0, 6 et 8 ne sont constituées que s'il reste des étudiants une fois
les briques cœur pourvues (`./bin/farci casting` le dit). Sinon, les équipes 6
et 8 sont des démonstrations du formateur pendant la marge de 1:35 – 1:50, et
la forge reste celle du formateur : elle sert de toute façon.

L'étape 3 n'est pas une équipe : elle se joue ensemble.

---

## Objectifs par équipe

Chaque équipe a **un objectif minimal** (sa ligne verte sur le tableau en moins
de 45 minutes) et **un objectif bonus**. L'objectif minimal tient en une
commande de démarrage et une vérification ; le bonus est là pour ceux qui vont
vite.

| Équipe | Objectif minimal (< 45 min) | Ligne du tableau | Objectif bonus |
|---|---|---|---|
| 1 Réseau | `./bin/farci up 01-network-dashboard` | Network | sondes Uptime Kuma (`scripts/uptime-kuma-seed.sh`) |
| 2 Inférence | Ollama démarré, modèle importé (`02-inference/ollama/create-model.sh`) | Inference | llama.cpp sur le même GGUF, benchmark (`02-inference/bench/bench.sh`) |
| 3 Passerelle | LiteLLM répond à `med-extraction` via l'accueil | LLM Gateway | démo de repli ; clés virtuelles et quota (PostgreSQL requis, `03-llm-gateway/litellm/bootstrap-keys.sh`) |
| 4 Documents | Docling et EDS-NLP démarrés + `./bin/farci test-unit -k deidentification` vert | Documents, EDS-NLP | conversion des PDF (`./bin/farci generate-dataset --pdf`), pseudonymiseurs comparés |
| 5 Observabilité | Phoenix démarré | Observability | Langfuse sur le même flux OTLP |
| 7 Applications | Open WebUI démarré, branché sur `/v1` | Open WebUI | premier dossier extrait par le parcours Python |

**Au départ, tout est 🛟.** La pile de référence du formateur (le Raspberry
Pi, `reference/README.md`) rend déjà chaque service : quand une équipe
livre, le formateur déclare sa machine (`./bin/farci room set <n> <ip>`) et
sa ligne passe de `🛟 REF` à `✅ UP`. Moment fort : la salle voit chaque
brique **remplacer** la doublure.

**Bloqué depuis 10 minutes ?** On lève la main. Rien à basculer : la
référence sert déjà à la place de l'équipe, qui continue à comprendre et à
réparer la sienne. Si la brique répond **mal** (trop lente), le formateur
lance `./bin/farci rescue <brique>`. La séance continue.

---

## Étape 1 — Construire l'infrastructure

Pour chaque équipe :

1. lire sa fiche : `./bin/farci read <équipe>` ;
2. écrire la fiche de son poste sur sa branche et la commiter :
   `./bin/farci poste nouveau`, puis `./bin/farci poste` ;
3. démarrer sa brique : `./bin/farci up <dossier>` ;
4. vérifier sa ligne : `./bin/farci status` ;
5. lancer le test contractuel : `./bin/farci test` ;
6. pousser sa branche et ouvrir sa Pull Request vers `seance`, relue par une
   autre équipe ; puis bonus.

En parallèle, l'écran projette `./bin/farci status --watch`. Chaque passage au
vert est annoncé à voix haute. Le passage à `CLINICAL PIPELINE: READY` est **le**
moment de l'étape 1 : avant, le pipeline n'est pas utilisable.

### Ordre de dépendances

```
  équipe 1 (réseau + tableau)
        │
        ├─► équipe 2 (inférence) ──► équipe 3 (passerelle) ──► équipe 7 (applications)
        ├─► équipe 4 (documents)
        └─► équipe 5 (observabilité)
```

Toutes les équipes démarrent **en même temps** : une équipe n'attend pas la
précédente pour monter sa brique, seulement pour la voir passer par Caddy.

---

## Étape 2 — Le même problème, plusieurs interfaces

**Le problème** : à partir de dossiers médicaux synthétiques, extraire des
variables structurées de recherche clinique, et les comparer à une référence.

**Ce qui est commun à tous** : le jeu de données, le schéma, la passerelle, le
modèle logique `med-extraction`, le gold standard.

| Parcours | Pour qui | Commande |
|---|---|---|
| A — Python (**principal**) | tout le monde : c'est là qu'on voit la validation | `./bin/farci extract --subset quick --run <équipe>` |
| B — Open WebUI | les étudiants sans machine utilisable, et ceux qui veulent jouer avec le prompt | navigateur, puis `07-applications/open-webui/export-submissions.sh` |
| C — Flowise | démonstration du formateur (10 min) | — |
| D — EDS-NLP (AP-HP) | toute la salle, 10 min, sur le service de l'équipe 4 | `./bin/farci eds entites <fichier>`, puis `./bin/farci eds compare --limit 2` |

Les parcours A à C produisent `datasets/extracted/<run>/patient_<IPP>.json` avec
**exactement** le même schéma. C'est ce qui rend la comparaison possible.

Le parcours D répond à une autre question : au lieu d'une **variable déduite**
(JSON), le modèle balise des **entités**, des morceaux du texte à leur place,
après la pseudonymisation EDS-Pseudo. On compare au gold ce qui est retrouvé,
et ce qui est balisé en trop (une complication « Non » balisée : une négation
manquée). Deux outils de la recherche clinique réelle, la même passerelle.

---

## Évaluation et lecture d'une trace (20 min)

```bash
./bin/farci evaluate --subset quick
```

Le classement des runs (complétude, JSON valides, précision, rappel, F1,
latence) est projeté. Puis on ouvre **une** trace dans Phoenix : le même
dossier, vu de l'intérieur (modèle réel, latence, tokens). La trace et le score
racontent la même histoire de deux façons.

---

## Étape 3 — Casser la plateforme (35 min)

```bash
./bin/farci chaos list
./bin/farci chaos scenario-01      # on casse
./bin/farci chaos status           # ce qui est encore cassé
./bin/farci chaos reset            # on répare
```

Le but n'est pas de tout casser : c'est de vérifier que **le pipeline continue
de fonctionner là où l'architecture le prévoit**, et qu'il s'explique clairement
là où elle ne le prévoit pas. Les scénarios 02 et 03 restent disponibles pour
les équipes en avance ou pour une séance plus longue.

---

## Clôture (15 min)

Chaque étudiant explique **une** notion avec ses mots, à partir des dix messages
du README : modèle ≠ runtime, passerelle, validation, référence,
observabilité… C'est le critère de réussite de la séance.

Dernier geste : `./bin/farci poste` sur chaque machine. La branche du poste
est sur la forge ; le formateur montre le *fork* sur GitHub et le
`git remote add` qui permet de l'y pousser. Le projet, et la façon de s'en
servir, sortent de la salle avec chaque étudiant.

---

## Voir aussi

- `docs/GIT.md` — le parcours git de chaque étudiant
- `docs/INSTRUCTOR_GUIDE.md` — la logistique, les checklists, les plans B
- `docs/ARCHITECTURE.md` — pourquoi cette architecture
- `docs/CONTRACTS.md` — les trois contrats
- `docs/CHAOS.md` — les scénarios détaillés
- `docs/AIRGAP.md` — ce qui passe par Internet, et ce qui n'y passe jamais
