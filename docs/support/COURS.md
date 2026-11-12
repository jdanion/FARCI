# FARCI — support de cours

**F**orge & **A**gents en **R**éseau pour le **C**alcul d'**I**nférence : la
forge, c'est git ; les agents et le réseau, ce sont les briques que les équipes
montent et relient ; le calcul d'inférence, c'est faire répondre un modèle.

> Brouillon. Ce document dit **ce qui est attendu de vous** pendant l'atelier,
> ce que vous saurez faire en sortant, et les notions à comprendre. Le
> diaporama projeté en séance en est le résumé : `FARCI-support-de-cours.pptx`.

| | |
|---|---|
| **Public** | étudiants en santé, sans prérequis en informatique |
| **Durée** | une séance de 4 heures, en équipes de 2 à 4 |
| **Format** | atelier : on construit, on utilise, on casse |
| **Matériel** | votre ordinateur portable ; à défaut, un binôme |
| **Évaluation** | pré-test et post-test Wooclap, une notion expliquée à l'oral, un questionnaire de satisfaction |

---

## 1. Pourquoi cet atelier

Utiliser une IA en recherche clinique, ce n'est pas « appeler une API ». C'est
faire fonctionner un **système** : un modèle, un logiciel qui l'exécute, un
point d'entrée, des documents à protéger, une mesure de la qualité, des
traces, et une organisation pour faire évoluer tout cela sans le casser.

L'atelier vous fait monter ce système de vos mains, sur les machines de la
salle, puis l'utiliser sur un vrai problème : **extraire des variables
structurées de dossiers médicaux** (synthétiques), et **mesurer** si
l'extraction est juste.

```
ÉTAPE 1  Construire la plateforme      chaque équipe monte une brique
ÉTAPE 2  L'utiliser                    des comptes rendus → des variables, comparées à une référence
ÉTAPE 3  La casser                     on provoque des pannes : que reste-t-il debout ?
```

Et du début à la fin, vous vous servez de **git**, l'outil qui garde
l'historique d'un projet et permet d'y travailler à plusieurs.

---

## 2. Les attendus

### À la fin de la séance, vous saurez expliquer

| # | Notion | En une phrase |
|---|---|---|
| 1 | Un LLM est probabiliste | il écrit le texte le plus plausible, il ne consulte pas une base de connaissances : il peut se tromper avec aplomb |
| 2 | Modèle ≠ runtime | le modèle est un fichier de connaissances, le runtime est le logiciel qui le fait tourner |
| 3 | La passerelle | un point d'entrée unique : l'application ne connaît ni le modèle ni la machine qui répond |
| 4 | Le contrat | une interface standard permet de remplacer une brique sans réécrire le reste |
| 5 | La validation | une sortie de LLM n'est pas une donnée tant qu'elle n'a pas été vérifiée |
| 6 | La référence | un score n'a de sens que comparé à un gold standard |
| 7 | La méthode | prompt, modèle, paramètres, données et code se versionnent ensemble |
| 8 | La résilience | une plateforme bien conçue continue malgré certaines pannes |
| 9 | L'observabilité | les traces disent pourquoi un système marche ou échoue |
| 10 | Local d'abord | le code et les modèles se téléchargent ; les dossiers, eux, ne sortent jamais de la salle |

### Vous saurez faire

**Avec git**

- cloner un projet depuis GitHub ou depuis une forge hébergée sur place (Gitea) ;
- créer votre branche et y adapter le projet à votre machine et à votre rôle ;
- enregistrer une modification (commit) avec un message qui l'explique ;
- la publier (push) et demander une relecture (Pull Request) ;
- relire la Pull Request d'une autre équipe ;
- récupérer le travail des autres.

**Avec la plateforme**

- démarrer la brique de votre équipe et prouver qu'elle fonctionne ;
- lire le tableau de la salle : qui rend quel service, et ce qui manque ;
- lancer une extraction sur des dossiers et lire le résultat ;
- lire un tableau de scores (précision, rappel, F1) ;
- ouvrir une trace et y retrouver le modèle, la durée et l'erreur éventuelle ;
- prédire l'effet d'une panne, puis vérifier votre prédiction.

### Ce qui n'est pas attendu

- savoir programmer ;
- connaître Docker, le réseau ou Linux ;
- retenir des commandes : chaque commande vous donne la suivante ;
- terminer le bonus de votre équipe.

Le critère de réussite est simple : en fin de séance, **chacun explique une
notion avec ses mots**, comme à un collègue non informaticien.

---

## 3. Avant de venir

| À faire | Comment | Durée |
|---|---|---|
| Installer git | Mac : `xcode-select --install` ; Windows : WSL, puis `sudo apt install git` ; Linux : déjà là | 10 min |
| Installer Docker | Docker Desktop (Mac, Windows) ou le paquet de votre distribution | 20 min |
| Cloner le projet | `git clone https://github.com/jdanion/FARCI farci` | 1 min |
| Vérifier la machine | `./bin/farci doctor` | 1 min |
| Télécharger votre brique | `./preload.sh --equipe <N>`, une fois votre équipe connue | 10 à 60 min selon le débit |

Rien de tout cela ne fonctionne ? Venez quand même : vous travaillerez en
binôme, et l'étape 2 se fait aussi dans un navigateur.

---

## 4. Le déroulé

| Horaire | Moment | Ce que vous faites |
|---|---|---|
| 0:00 | **Accueil** | pré-test Wooclap ; les trois étapes ; vous clonez le projet et créez votre branche |
| 0:20 | **Étape 1 — Construire** | vous écrivez la fiche de votre poste (premier commit), puis votre équipe monte sa brique |
| 1:15 | | vous poussez votre branche, ouvrez une Pull Request, relisez celle d'une autre équipe |
| ~1:30 | | **`CLINICAL PIPELINE READY`** : la chaîne complète fonctionne |
| 1:50 | Pause | |
| 2:00 | **Étape 2 — Utiliser** | extraction des dossiers, par programme ou dans un navigateur |
| 2:50 | **Évaluation** | classement des extractions ; une trace lue ensemble |
| 3:10 | **Étape 3 — Casser** | quatre pannes : vous pariez, on casse, on observe, on répare |
| 3:45 | **Clôture** | chacun explique une notion ; post-test et questionnaire Wooclap |

---

## 5. Les notions

### 5.1 Un LLM est un collaborateur junior très instruit

Un grand modèle de langage produit, mot après mot, la suite **la plus
plausible**. Il ne cherche pas dans une base de connaissances et ne sait pas
qu'il ne sait pas. Le résultat est souvent juste, parfois faux, et toujours
bien rédigé. On le traite donc comme le travail d'un interne brillant : on le
relit avant de s'en servir.

### 5.2 Le modèle et le runtime

| | Ce que c'est | Dans l'atelier |
|---|---|---|
| **Modèle** | un fichier de chiffres : les connaissances | de Qwen3.5-2B (1 Go) à Ornith-1.5-9B (6 Go), en passant par deux « 4B » à comparer : Qwen3.5-4B et Gemma 4 E4B |
| **Runtime** | le logiciel qui charge ce fichier et répond | Ollama, llama.cpp |

Lire le nom d'un fichier de modèle, par exemple `Qwen3.5-4B-Q4_K_M.gguf` :

| Morceau | Sens |
|---|---|
| `Qwen3.5` | la famille et la version |
| `4B` | la taille : 4 milliards de paramètres. Plus il y en a, plus le modèle est capable, lourd et lent |
| `Q4_K_M` | la compression (quantification) : 4 bits par paramètre, un fichier quatre fois plus petit, un peu moins précis |
| `.gguf` | le format, lu par Ollama comme par llama.cpp |

Le projet propose six modèles ; chaque poste prend le plus grand que sa
machine supporte. Trois d'entre eux ont le même gabarit (« 4B ») et se
comparent sur les mêmes dossiers : deux **généralistes** de familles
différentes (Qwen3.5-4B, Gemma 4 E4B) et un modèle **spécialisé** en médecine
(MedGemma 4B). Un modèle entraîné sur la médecine extrait-il mieux ? C'est le
score qui répond. On croisera aussi un modèle **à raisonnement** (Ornith, qui
réfléchit avant de répondre) et un **mélange d'experts** (Ornith-1.5-35B-A3B :
35 milliards de paramètres, dont 3 milliards actifs à chaque mot).

Un livre et la personne qui le lit à voix haute. Le même modèle tourne dans
deux runtimes différents, avec des vitesses différentes ; une machine modeste
prend un modèle plus petit. Les applications, elles, demandent toujours
`med-extraction` et ignorent ce qui répond.

### 5.3 La passerelle et le contrat

La passerelle est le **standard téléphonique** de l'hôpital : un seul numéro,
derrière lequel on distribue les appels, on bascule sur un autre poste en cas
de panne, on mesure et on limite.

Cela fonctionne parce que toutes les briques respectent un **contrat** : la
même façon de poser une question et de recevoir une réponse. Tant que le
contrat est tenu, on remplace un runtime par un autre sans toucher à
l'application.

### 5.4 Une sortie de LLM n'est pas une donnée

On demande au modèle de remplir un **formulaire** : âge, sexe, diagnostic,
stade, complications. La réponse est contrôlée contre ce formulaire, écrit
en Python avec la bibliothèque **Pydantic** :

```python
class ClinicalExtraction(BaseModel):
    age: int = Field(ge=0, le=120)                             # un nombre, entre 0 et 120
    sex: str = Field(pattern="^(M|F)$")                        # M ou F, rien d'autre
    pT: Optional[str] = Field(pattern="^(pT1|pT2|pT3|pT4)$")   # exigé, mais peut valoir « non précisé »
    pancreatic_fistula: bool                                   # oui ou non
```

`Optional` ne veut pas dire facultatif : le champ doit être présent, mais peut
valoir `null`, c'est-à-dire « non précisé dans le compte rendu ». Un âge
écrit en toutes lettres, un champ manquant, un champ inventé : la réponse est
**rejetée**, et rien n'entre dans la base de recherche.

Pydantic vérifie la **forme**, pas le fond : un âge de 76 ans est accepté
(c'est un nombre entre 0 et 120) même si le patient en a 67. Repérer cette
erreur-là est le travail de la mesure.

### 5.5 Protéger les documents

Avant tout traitement, les identifiants (nom, date de naissance, numéro de
dossier) sont remplacés par des jetons : c'est la **pseudonymisation**. Les
documents d'un même patient restent reliés entre eux, mais le modèle ne voit
jamais qui il est.

### 5.6 Mesurer : le gold standard

Pour chaque dossier, la bonne réponse est connue d'avance : c'est le **gold
standard**. On compare chaque extraction à cette référence.

| Mesure | Question posée |
|---|---|
| **Précision** | parmi ce que le système a trouvé, quelle part est juste ? |
| **Rappel** | parmi ce qu'il fallait trouver, quelle part a été trouvée ? |
| **F1** | les deux à la fois |

Pour chaque champ de chaque dossier, quatre issues :

| La référence | Le modèle | Issue |
|---|---|---|
| pT3 | pT3 | **trouvé** |
| R0 | non précisé | **manqué** : le rappel baisse |
| non précisée | 28 mm | **inventé** : la précision baisse |
| pN1 | pN2 | **faux** : compte comme manqué et comme inventé |

Un modèle qui se tait a une bonne précision et un mauvais rappel ; un modèle
bavard, l'inverse. Savoir lequel est le plus grave — manquer une complication
ou en inventer une — est une décision clinique, pas informatique.

Exemple : le système signale 10 complications, dont 8 réelles ; il y en avait
16 à trouver. Précision 8/10 = 80 %, rappel 8/16 = 50 %. Un « F1 de 0,84 »
cité sans référence ne veut rien dire.

### 5.7 Observer et résister aux pannes

Chaque requête laisse une **trace** : quel modèle a répondu, en combien de
temps, avec quelle erreur. C'est la traçabilité des soins, appliquée au
logiciel. Elle est branchée **à côté** de la chaîne : si l'outil de traces
tombe, l'extraction continue.

À l'étape 3, on arrête un runtime, on fait renvoyer un JSON invalide, on coupe
la passerelle d'une équipe. Avant chaque panne, la salle parie : la plateforme
tiendra-t-elle ? Une bonne architecture continue de fonctionner là où c'est
prévu, et explique clairement pourquoi elle s'arrête ailleurs.

### 5.8 Local d'abord

| Ce qui circule | Par où |
|---|---|
| le code | GitHub, ou la forge de la salle |
| les modèles et les logiciels, au téléchargement | leurs sites d'origine |
| **les dossiers, les questions, les réponses, les traces** | **rien ne sort de la salle** |

Les modèles tournent sur vos machines. C'est ce qui rend l'approche
acceptable pour des données de santé.

### 5.9 Git : le dossier patient du projet

Git garde tout l'historique d'un projet : qui a changé quoi, quand, pourquoi.

| Terme | Analogie |
|---|---|
| **dépôt** | le dossier patient complet, historique compris |
| **commit** | une observation datée et signée |
| **branche** | un protocole adapté à un service : votre version, sans toucher celle des autres |
| **push** | transmettre vos observations |
| **Pull Request** | demander l'avis d'un confrère avant d'intégrer |
| **forge** | les archives : GitHub sur Internet, Gitea hébergé sur place |

Le projet vit en trois lieux : **GitHub** (la référence, accessible de
partout), **la forge Gitea de la salle** (le même projet, sur une machine que
l'on possède) et **votre ordinateur**. Vous créez une branche à votre nom de
poste, par exemple `poste/equipe-2-atlas`, et vous y décrivez votre machine :
un portable de 16 Go ne fait pas tourner le même modèle qu'une station avec
carte graphique.

Le pas-à-pas complet est dans `docs/GIT.md` (`./bin/farci docs git`), et
`./bin/farci poste` vous donne à tout moment la commande suivante.

---

## 6. Votre équipe

| Équipe | Brique | Ce qu'elle apporte à la salle |
|---|---|---|
| 0 | La forge (Gitea) | là où toute la salle pousse ses branches et relit ses Pull Requests |
| 1 | Réseau et tableau | l'adresse unique de la salle et le tableau projeté |
| 2 | Inférence | un modèle qui tourne et répond |
| 3 | Passerelle | le point d'entrée unique, le repli en cas de panne |
| 4 | Documents | la conversion et la pseudonymisation des comptes rendus |
| 5 | Observabilité | les traces de chaque requête |
| 6 | Évaluation | les scores et le classement |
| 7 | Applications | l'interface de discussion et le programme d'extraction |
| 8 | Agents | la supervision automatique |

Chaque équipe a une fiche d'une page, `docs/wiki/equipe-XX.md`
(`./bin/farci read <équipe>`), avec un objectif minimal atteignable en 45 minutes.

**La règle des dix minutes.** Bloqué depuis dix minutes ? Levez la main. Une
machine de référence rend déjà chaque service à votre place : personne
n'attend, et vous continuez à comprendre et à réparer.

---

## 7. Comment nous saurons que c'est réussi

| Quand | Quoi | Pour savoir |
|---|---|---|
| avant la séance, ou à l'arrivée | pré-test Wooclap, 9 minutes, anonyme | ce que vous connaissez déjà, et ce que vous attendez |
| pendant | la ligne de votre équipe sur le tableau ; votre branche sur la forge | ce que vous avez construit |
| à la clôture | une notion expliquée à l'oral | ce que vous avez compris |
| à la clôture | post-test Wooclap, les mêmes questions | ce que vous avez appris |
| à la clôture | questionnaire de satisfaction | si vos attentes ont été satisfaites, quelles parties vous ont été utiles, ce qu'il faut améliorer |

Les deux tests ne sont pas notés. Leur comparaison, question par question, est
montrée à la salle à la fin. Les questions sont dans `EVALUATION.md`.

---

## 8. Ce que vous emportez

- votre branche, avec votre nom de poste, sur la forge de la salle — et la
  façon de la pousser sur votre propre compte GitHub ;
- le projet complet, que vous pouvez relancer chez vous ;
- la possibilité d'héberger votre propre forge : `./bin/farci up 00-gitops` ;
- dix idées sur ce qu'est, et n'est pas, une IA utilisée en recherche clinique.

## Pour aller plus loin

- `README.md` — le vocabulaire complet, en langage de médecine
- `docs/GIT.md` — git pas à pas
- `docs/WORKSHOP_FLOW.md` — le déroulé détaillé
- `docs/ARCHITECTURE.md` — pourquoi cette architecture
