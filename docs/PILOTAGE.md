# Pilotage de la séance — la feuille du formateur

À imprimer recto verso et à garder à côté du Pi. Tout ce qui est ici est
détaillé ailleurs (`docs/INSTRUCTOR_GUIDE.md`, `reference/README.md`) : cette
feuille sert à **ne pas avoir à chercher**. `./bin/farci docs pilotage`
l'affiche.

---

## Avant

| Quand | Quoi | Fait |
|---|---|---|
| J-7 | Pi préparé (Internet) : `./preload.sh --reference`, `./bin/farci bootstrap`, point d'accès `farci-ap` | ☐ |
| J-7 | postes étudiants : clé USB `offline/` prête (`./preload.sh --core`) | ☐ |
| J-1 | `./bin/farci forge-sync bundle farci.bundle` (si la forge Gitea est jouée) → clé USB | ☐ |
| J-1 | **sur le Pi** : `./bin/farci rehearse` → **PASS** (moins de 15 min) | ☐ |
| J-1 | **sur un portable** branché au Wi-Fi du Pi : `./bin/farci rehearse` → **PASS** | ☐ |
| J0 −30 min | `sudo nmcli con up farci-ap` puis `./bin/farci up reference` | ☐ |
| J0 −20 min | écran projeté : l'iPad sur `http://<REFERENCE_IP>/` (tableau de la salle, tout en `🛟`), puis **`./bin/farci tableau reset`** sur le Pi : scores et chrono à zéro | ☐ |
| J0 −20 min | `./bin/farci partage maj` sur le Pi ; au tableau : **`http://<REFERENCE_IP>/rejoindre`** pour qui arrive sans `git clone` | ☐ |
| J0 −10 min | au tableau : SSID, `REFERENCE_IP`, adresse Open WebUI `REFERENCE_IP:3080` | ☐ |

Un **FAIL** de `rehearse` la veille se corrige la veille : la ligne en échec
donne la piste. Le rapport est dans `datasets/reports/rehearse-*.txt`.

---

## Le minutage et ses points de décision

| Heure | Moment | Point de décision |
|---|---|---|
| 0:00 | Accueil, `./bin/farci doctor` pour tous | Docker absent ou cassé → binôme, tout de suite |
| 0:20 | Étape 1 : chaque équipe lit sa fiche (`docs/wiki/equipe-XX.md`) | — |
| 0:30 → 1:15 | Objectif minimal ; je déclare chaque machine : `./bin/farci room set <n> <ip>` | **1:00** : une équipe encore `🛟` continue sans bloquer personne |
| ~1:30 | **CLINICAL PIPELINE READY** : on le montre à tous | **1:40** au plus tard : on passe à la suite, avec ce qui sert (`✅` ou `🛟`) |
| 1:50 | **Pause** — jamais supprimée | je répare pendant la pause |
| 2:00 | Étape 2 : `./bin/farci extract --subset quick --run <équipe>` ; EDS-NLP : `./bin/farci eds compare --limit 2` | lent → `./bin/farci rescue inference` |
| 2:50 | Évaluation : `./bin/farci evaluate --subset quick`, une trace lue | une seule trace si retard |
| 3:10 | Étape 3 : 01, 04, 06 (ou 05), 07 — pari avant chaque panne | retard → 01, 04, 07 seulement |
| 3:45 | Clôture : chacun explique une notion | jamais coupée |

**20 minutes de retard** : démos bonus supprimées, un scénario de moins.
Pause, évaluation et clôture restent.

---

## Mes commandes (sur le Pi)

| Je veux… | Commande |
|---|---|
| voir qui sert quoi | `./bin/farci room` |
| déclarer une équipe | `./bin/farci room set <n> <ip>` |
| forcer la référence sur une brique qui répond mal | `./bin/farci rescue <inference\|passerelle\|documents\|eds\|observabilite>` |
| rendre la main à l'équipe | `./bin/farci rescue --off <brique>` |
| jouer une panne | `./bin/farci chaos scenario-NN` |
| tout remettre d'aplomb | `./bin/farci reset-all` |
| changer de réseau (Wi-Fi de secours) | `./bin/farci room set reference <ip du Pi>`, sur chaque poste |

---

## Les incidents, en une ligne

| Incident | Réflexe |
|---|---|
| Docker absent ou cassé sur un poste | binôme ; la ligne reste `🛟`, personne n'attend |
| RAM insuffisante / modèle trop lent | `02-inference/ollama/create-model.sh secours`, sinon `rescue inference` |
| une brique d'équipe tombe | rien : l'accueil bascule seul sur la référence |
| conflit de port | `./bin/farci doctor`, section ports |
| ligne restée `🛟` alors que l'équipe est verte | `./bin/farci room` : IP déclarée ? |
| Wi-Fi tombé | `sudo nmcli con up farci-ap` ; sinon point d'accès de secours + `room set reference` |
| plus de réseau du tout | chaque équipe en local ; étape 2 : `./bin/farci extract --replay` |
| étudiant sans machine | binôme, ou Open WebUI de la référence (`REFERENCE_IP:3080`) |

Le détail, avec le temps de chaque repli : `docs/INSTRUCTOR_GUIDE.md`.

---

## Les dix messages : quand les dire

| # | Message | Moment | Dit |
|---|---|---|---|
| 1 | Un LLM est un composant probabiliste, pas une base de données | étape 2, premier JSON rejeté | ☐ |
| 2 | Le modèle et le logiciel qui l'exécute sont deux choses différentes | étape 1, équipe 2 (`med-extraction` sur deux runtimes) | ☐ |
| 3 | Une application ne dépend pas directement d'un moteur ou d'un fournisseur | étape 1, équipe 3 | ☐ |
| 4 | Une API standard permet de remplacer une implémentation | chaos 06 | ☐ |
| 5 | Une donnée générée par un LLM est validée avant d'entrer en base | chaos 04 | ☐ |
| 6 | Une performance n'a de sens que comparée à une référence | évaluation (gold contre gold = 1.00) | ☐ |
| 7 | Prompt, modèle, paramètres, données et code font partie de la méthode | évaluation, prompt v1 contre v2 | ☐ |
| 8 | L'IA en recherche clinique demande GitOps, DevOps, LLMOps, gouvernance, évaluation | clôture | ☐ |
| 9 | Une infrastructure bien conçue continue malgré certaines pannes | chaos 01 (`✅` → `🛟`) | ☐ |
| 10 | L'observabilité explique pourquoi un système marche ou échoue | évaluation, la trace lue ensemble ; chaos 07 | ☐ |

---

## Notes de séance

Ce qui a bloqué, à quelle heure, et ce qui a débloqué :

```
.......................................................................

.......................................................................

.......................................................................
```
