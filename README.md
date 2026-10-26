# FARCI

**F**orge & **A**gents en **R**éseau pour le **C**alcul d'**I**nférence

> Un atelier où l'on **construit** une plateforme d'IA pour la recherche
> clinique, où l'on **s'en sert** pour extraire des variables d'un dossier
> médical, puis où l'on **casse** la plateforme pour vérifier qu'elle résiste.

---

## Les trois étapes

```
ÉTAPE 1
Construire la plateforme
        │
        │   les équipes montent chacune leur brique,
        │   le dashboard passe de 🔴 🔴 🔴 🔴 🔴 🔴 🔴 à 🟢 🟢 🟢 🟢 🟢 🟢 🟢
        ▼
ÉTAPE 2
Utiliser la plateforme
pour une extraction clinique
        │
        │   le même problème pour tout le monde :
        │   des documents médicaux → des variables structurées
        ▼
ÉTAPE 3
Casser la plateforme
et observer sa résilience
        │
        │   on arrête un runtime, on sature une clé, on renvoie
        │   un JSON invalide : le pipeline doit tenir, ou expliquer pourquoi
        ▼
```

---

## Le vocabulaire, en langage de médecine

Si vous savez expliquer ceci à un collègue non informaticien, vous avez compris
l'atelier.

| Terme | Analogie | Ce que c'est vraiment |
|---|---|---|
| **LLM** (grand modèle de langage) | un **collaborateur junior** très instruit | un composant **probabiliste** : il écrit des phrases plausibles, il ne consulte pas une base de connaissances. Il peut donc se tromper avec beaucoup d'aplomb. |
| **Modèle** (les poids) | l'**ensemble des connaissances** accumulées | un fichier de chiffres. Rien ne s'exécute tout seul. |
| **Runtime d'inférence** (Ollama, llama.cpp) | le **laboratoire** qui utilise ces connaissances | le logiciel qui charge le modèle et répond à des requêtes. **Le même modèle peut tourner dans deux runtimes différents, avec des performances différentes.** |
| **Passerelle LLM** (gateway : LiteLLM, Bifrost) | le **standard téléphonique** de l'hôpital | un point d'entrée unique qui sait : distribuer les appels, réessayer, changer de serveur en cas de panne, mesurer le débit, et donner des clés aux différents services. |
| **Reverse proxy** (Caddy) | l'**accueil** de l'hôpital | une adresse unique et stable. Les patients ne connaissent pas les numéros de service. |
| **Application** | le **protocole de soins** | la logique métier : ce qu'on fait du résultat. Elle ne doit connaître **ni** le modèle, **ni** le runtime. |
| **Structured output** | un **formulaire administratif** typé | une réponse dans un format fixe et validable, plutôt qu'un paragraphe libre. |
| **Pseudonymisation** | l'**anonymisation** du dossier de recherche | remplacer les identifiants par des jetons avant tout traitement, tout en gardant la possibilité de relier les données entre elles. |
| **Observabilité** | la **traçabilité** des soins | pouvoir reconstituer ce qui s'est passé : quelle requête, quel modèle, quelle latence, quelle erreur. |
| **Évaluation** | la **revue de littérature** | comparer une méthode à une référence connue. Un chiffre seul ne veut rien dire. |
| **GitOps** | le **dossier de procédures** vivant | l'infrastructure est décrite dans un dépôt Git. Ce qui est versionné est ce qui est installé. |
| **DevOps** | la **chaîne de fabrication** | ce qui permet de construire, tester et déployer de façon répétable. |
| **LLMOps** | la **maintenance des équipements** | tout ce qui entoure un modèle en production : versions, mesures, garde-fous. |

**Le message central** : une application d'IA en médecine n'est pas « appeler une
API ». C'est un système. C'est pour cela qu'il faut GitOps, DevOps, LLMOps, une
gouvernance des données et une évaluation.

---

## Démarrage rapide

### 1. Ce qu'il faut savoir avant de commencer

| Question | Réponse |
|---|---|
| `git clone` suffit-il ? | **Non.** Les images Docker, les poids de modèles et les wheels Python sont volontairement **hors du dépôt** (un modèle pèse 6 à 18 Go). Il faut en plus le répertoire `FARCI_DATA_DIR` (clé USB ou disque du formateur). |
| Faut-il Internet ? | **Non, pas pendant l'atelier.** Tout est préchargé avant. `verify-airgap.sh` le vérifie. |
| Docker est-il nécessaire ? | **Oui**, c'est lui qui fait tourner les briques. |
| `make` est-il nécessaire ? | **Non.** `make <cible>` et `./bin/farci <cible>` exécutent le même code. |

### 2. Préparer la machine

```bash
cp .env.example .env
cp config/network.env.example config/network.env
./bin/farci doctor        # ma machine est-elle prête ?
./bin/farci bootstrap     # crée les répertoires, le lien offline/, les .env
./bin/farci lint          # le dépôt est-il conforme ?
```

Si `make` est installé, `./bin/farci X` et `make X` font la même chose.

### 3. Voir où en est la construction

```bash
./bin/farci status              # le tableau de progression (§49)
./bin/farci status --watch      # en continu, pour l'écran de l'amphithéâtre
```

Au démarrage, tout est rouge. C'est **voulu** : le dashboard se remplit au fil
de l'étape 1, et c'est la démonstration en direct de ce qu'un atelier construit.

### 4. Toutes les commandes

```bash
./bin/farci help
```

---

## Les modèles

Un modèle n'est pas un runtime. Le dépôt utilise deux modèles, interchangeables
derrière la même passerelle :

| Rôle | Modèle | Taille (Q4) | Licence | Où il tourne |
|---|---|---|---|---|
| Principal, grosse configuration (GPU ou 32 Go) | **Ornith-1.5-9B** | ~5,9 Go | MIT | Ollama |
| Postes légers, secours, développement et CI | Qwen3.5-2B | ~1,2 Go | Apache-2.0 | llama.cpp (et Ollama) |

L'application ne voit que le nom logique `med-extraction`. Changer de modèle ne
demande **aucune** modification du code métier : c'est l'objet même de l'atelier.

> **Note d'honnêteté** : le cahier des charges prévoyait des modèles de 1–2 Go et
> 3–4 Go. Les deux familles choisies ici ne descendent pas en dessous de 9 Go et
> 27 Go. Un troisième modèle minuscule est donc prévu pour la CI et les machines
> de développement, et **exclu du score final** pour ne pas mélanger deux
> méthodes. Voir `docs/ARCHITECTURE.md`.

---

## Comment le dépôt est organisé

| Chemin | Contenu |
|---|---|
| `00-gitops/` … `08-arcane-agents/` | une équipe par dossier, avec son `TUTORIAL.md` (`./bin/farci read <équipe>`) |
| `config/services.yaml` | **source de vérité** : quels services existent, où, comment les sonder |
| `config/network.env.example` | les adresses IP, seul endroit où elles apparaissent |
| `versions.env` | toutes les versions figées, jamais `latest` |
| `scripts/` | toute la logique ; `scripts/targets.def` liste les commandes |
| `datasets/` | dossiers médicaux synthétiques (texte) + gold standard |
| `chaos/` | scénarios de panne réversibles |
| `tests/` | tests unitaires (`./bin/farci test-unit`) et contractuels (`./bin/farci test`) |
| `docs/` | architecture, contrats, air-gap, chaos, guide formateur |
| `offline/` | lien symbolique vers les artefacts lourds (§ ci-dessus) |

---

## Les dix messages de l'atelier

1. Un LLM est un composant probabiliste, pas une base de données.
2. Le modèle et le logiciel qui l'exécute sont deux choses différentes.
3. Une application ne doit pas dépendre directement d'un moteur ou d'un fournisseur.
4. Une API standard permet de remplacer une implémentation sans réécrire l'application.
5. Une donnée générée par un LLM doit être validée avant d'entrer dans une base de recherche.
6. Une performance n'a de sens que comparée à une référence.
7. Le prompt, le modèle, les paramètres, les données et le code font partie de la méthode.
8. Une IA destinée à la recherche clinique nécessite GitOps, DevOps, LLMOps, gouvernance des données et évaluation.
9. Une infrastructure correctement conçue doit continuer à fonctionner malgré certaines pannes.
10. L'observabilité permet de comprendre pourquoi un système fonctionne ou échoue.

---

## Où aller ensuite

| Vous êtes… | Lisez |
|---|---|
| formateur | `docs/INSTRUCTOR_GUIDE.md`, et la feuille de séance `docs/PILOTAGE.md` |
| étudiant débutant | sa fiche : `docs/wiki/equipe-XX.md` |
| responsable d'une équipe | `./bin/farci read <équipe>` |
| curieux de l'architecture | `docs/ARCHITECTURE.md` |
| intéressé par les contrats | `docs/CONTRACTS.md` |
| inquiet du fonctionnement hors ligne | `docs/AIRGAP.md` |

Contribuer : `CONTRIBUTING.md`.
