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
| J-7 | miroir de secours (si Hugging Face ou un registre est bloqué à la faculté) : `./bin/farci partage publier <destination rsync>` depuis une machine préchargée (`--core`) ; vérifier `FARCI_FICHIERS_URL` depuis un autre poste | ☐ |
| J-7 | message aux étudiants : `git clone` depuis GitHub, puis `./preload.sh --equipe <N>` (sa brique, selon la machine) | ☐ |
| J-1 | **forge Gitea sur le Pi** : `./bin/farci up 00-gitops`, `00-gitops/gitea/bootstrap.sh`, `./bin/farci forge-sync push`, `00-gitops/post-provision.sh`, `./bin/farci room set gitea <IP du Pi>` | ☐ |
| J-1 | **sur le Pi** : `./bin/farci rehearse` → **PASS** (moins de 15 min) | ☐ |
| J-1 | **sur un portable** branché au Wi-Fi du Pi : `./bin/farci rehearse` → **PASS** | ☐ |
| J0 −30 min | `sudo nmcli con up farci-ap` puis `./bin/farci up reference` | ☐ |
| J0 −20 min | écran projeté : l'iPad sur `http://<REFERENCE_IP>/` (tableau de la salle, tout en `🛟`), puis **`./bin/farci seance nouvelle`** sur le Pi : équipes, adresses, scores et chrono à zéro (la séance précédente est sauvegardée) | ☐ |
| J0 −20 min | `./bin/farci forge-sync push` (la forge rattrape GitHub), puis `./bin/farci partage maj` sur le Pi ; au tableau : **`http://<REFERENCE_IP>/rejoindre`** (cloner, sa branche, les fichiers) | ☐ |
| J0 −10 min | au tableau : SSID, `REFERENCE_IP`, adresse de la forge, comptes `equipe-<N>` et mot de passe de la salle, adresse Open WebUI `REFERENCE_IP:3080` | ☐ |

Un **FAIL** de `rehearse` la veille se corrige la veille : la ligne en échec
donne la piste. Le rapport est dans `datasets/reports/rehearse-*.txt`.

---

## Le minutage et ses points de décision

| Heure | Moment | Point de décision |
|---|---|---|
| 0:00 | Accueil : git en trois lieux ; `git clone`, `git switch -c poste/equipe-<N>-<surnom>`, `./bin/farci doctor` pour tous | Docker absent ou cassé → binôme, tout de suite ; pas de git → binôme pour git aussi |
| 0:20 | Étape 1 : chaque équipe lit sa fiche (`docs/wiki/equipe-XX.md`) ; `./bin/farci poste nouveau`, premier commit | — |
| 1:15 | push et Pull Request vers `seance` ; chaque équipe en relit une autre | une équipe en retard pousse à la pause : rien ne dépend de sa PR |
| 0:30 → 1:15 | Objectif minimal ; je déclare chaque machine dans l'onglet **Formateur** du tableau (`/tableau/formateur`), ou `./bin/farci room set <n> <ip>` | **1:00** : une équipe encore `🛟` continue sans bloquer personne |
| ~1:30 | **CLINICAL PIPELINE READY** : on le montre à tous | **1:40** au plus tard : on passe à la suite, avec ce qui sert (`✅` ou `🛟`) |
| 1:50 | **Pause** — jamais supprimée | je répare pendant la pause |
| 2:00 | Étape 2 : `./bin/farci extract --subset quick --run <équipe>` ; EDS-NLP : `./bin/farci eds compare --limit 2` | lent → `./bin/farci rescue inference` |
| 2:50 | Évaluation : `./bin/farci evaluate --subset quick`, une trace lue | une seule trace si retard |
| 3:10 | Étape 3 : 01, 04, 06 (ou 05), 07 — pari avant chaque panne | retard → 01, 04, 07 seulement |
| 3:45 | Clôture : chacun explique une notion ; `./bin/farci poste` sur chaque machine, le fork GitHub montré une fois | jamais coupée |

**20 minutes de retard** : démos bonus supprimées, un scénario de moins.
Pause, évaluation et clôture restent.

---

## Mes commandes (sur le Pi)

| Je veux… | Commande |
|---|---|
| voir qui sert quoi | `./bin/farci room` |
| savoir où en est un étudiant dans git | `./bin/farci poste`, sur **son** poste |
| faire rattraper GitHub à la forge | `./bin/farci forge-sync push` |
| garder le travail de la séance | `./bin/farci forge-sync rapatrier seance`, puis une PR sur GitHub |
| déclarer une équipe | onglet **Formateur** du tableau (nom, étudiants, IP, suivi UP/DOWN), ou `./bin/farci room set <n> <ip>` |
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
| GitHub injoignable | la forge de la salle a le même projet : `git clone` depuis elle (`/rejoindre`) |
| forge tombée | cloner depuis GitHub ; les commits restent sur les postes, on pousse à son retour |
| un push refusé | compte `equipe-<N>` ? branche `poste/…` et non `main` ou `seance` ? `./bin/farci poste` |
| un fichier lourd manque | `./preload.sh --equipe <N> --skip-existing` (serveur de fichiers), sinon `http://<REFERENCE_IP>/partage/` |
| le Pi doit télécharger quelque chose, sans câble | `./bin/farci wifi internet`, puis `./bin/farci wifi salle` (il y revient seul après 5 min sans SSH) |
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
