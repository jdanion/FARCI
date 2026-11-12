# Git dans l'atelier — ce que vous emportez

Vous repartirez de FARCI en sachant vous servir de **git** : récupérer un
projet, en faire votre version, la publier, la faire relire. C'est un objectif
de l'atelier au même titre que la plateforme elle-même, et il concerne
**toutes** les équipes.

`./bin/farci poste` vous dit à tout moment où vous en êtes et **quelle
commande git taper ensuite**. Il ne la tape pas à votre place : c'est vous qui
apprenez.

---

## L'idée, en langage de médecine

Git est le **dossier patient du projet**. Rien ne s'efface, tout est daté et
signé : qui a changé quoi, quand, et pourquoi. On peut toujours revenir à
l'état d'hier, et comparer deux versions ligne à ligne.

| Terme | Analogie | Ce que c'est vraiment |
|---|---|---|
| **Dépôt** (repository) | le dossier patient complet | le projet **et tout son historique** |
| **Commit** | une observation datée et signée | un état du projet, avec un message qui explique le changement |
| **Branche** | un protocole adapté à un service | une ligne de travail parallèle : votre version, sans toucher celle des autres |
| **Cloner** | recevoir une copie du dossier | télécharger le dépôt entier sur votre machine |
| **Remote** | l'établissement d'où vient le dossier | un dépôt distant que votre clone connaît (`origin`, `salle`…) |
| **Push** / **fetch** | transmettre / recevoir les nouvelles observations | envoyer vos commits, recevoir ceux des autres |
| **Pull Request** | la demande d'avis à un confrère | « voici ma branche, relisez-la avant de l'intégrer » |
| **Fork** | votre propre copie du dossier, chez vous | une copie du dépôt sur **votre** compte, où vous avez le droit d'écrire |
| **Forge** (GitHub, Gitea) | les archives de l'hôpital | le serveur qui héberge les dépôts et les Pull Requests |

---

## Les trois lieux du projet

```
        GitHub                         la forge Gitea de la salle
  github.com/jdanion/FARCI                 (auto-hébergée)
   la SOURCE DE VÉRITÉ          main   = copie de GitHub (forge-sync)
   lecture pour tous            seance = le travail commun de la séance
   écriture : votre fork        poste/equipe-N-… = une branche par machine
          │                                │
          │  git clone                     │  git clone · git push · Pull Request
          ▼                                ▼
   ┌─────────────────────────────────────────────┐
   │            VOTRE MACHINE (le clone)         │
   │   branche poste/equipe-2-atlas              │
   │   fiche   postes/equipe-2-atlas.env         │
   └─────────────────────────────────────────────┘
          ▲
          │  ./preload.sh  (téléchargement simple, PAS git)
   Hugging Face, registres Docker, PyPI (miroir de secours du formateur)
```

- **GitHub** est joignable depuis la faculté. C'est l'adresse à retenir : elle
  existera encore après l'atelier.
- **Gitea** est une forge **que l'on héberge soi-même** : trois conteneurs sur
  une machine de la salle, et l'on a « son GitHub » sans Internet ni tiers.
  C'est ce qu'un hôpital fait quand le code ne doit pas sortir de ses murs.
  Dans la salle, c'est **là que vous poussez** et que vous ouvrez vos Pull
  Requests. Les gestes sont les mêmes que sur GitHub.
- **Les fichiers volumineux** (un modèle pèse de 1 à 18 Go) ne vont jamais dans
  Git, qui garde tout pour toujours. `./preload.sh` les prend sur leur site
  d'origine (Hugging Face, registres Docker) ; si l'un est bloqué, sur le
  miroir du formateur (`FARCI_FICHIERS_URL` dans `.env`) ou sur le Pi.

---

## Deux temps : en ligne, puis en local

Un ordinateur ne peut être que sur un Wi-Fi à la fois, et la salle travaille
sur son propre réseau, sans Internet. La séance se déroule donc en deux temps.

| Temps | Réseau | Ce que vous faites | Dépôt distant |
|---|---|---|---|
| **1. En ligne** — chez vous, ou en début de séance | celui de la faculté, ou le vôtre | cloner depuis GitHub, télécharger votre brique (`./preload.sh`), créer votre branche, premier commit | `origin` : GitHub, en lecture |
| **2. En local** — le reste de la séance | `FARCI-SALLE`, le Wi-Fi du Pi | `./bin/farci poste salle`, pousser, Pull Request, relecture | `salle` : la forge Gitea, en écriture |

**Aucun compte GitHub n'est nécessaire** : le projet est public, on le clone
sans s'identifier. Et sur la forge de la salle, le compte de votre équipe
existe déjà : `./bin/farci poste salle` le branche sur votre clone, sans rien
à saisir.

Le basculement est annoncé par le formateur : « tout le monde a ce qu'il lui
faut ? On passe en local. » À partir de là, plus rien ne sort de la salle.

---

## Le parcours, étape par étape

### 1. Cloner

Depuis GitHub, partout où il y a Internet, **sans compte** :

```bash
git clone https://github.com/jdanion/FARCI farci
cd farci
```

Arrivé dans la salle sans avoir cloné ? La forge du Pi a le même projet
(l'adresse est sur la page `/rejoindre`) :

```bash
git clone http://<forge>/FARCI/farci.git farci
cd farci
```

C'est le même projet. La seule différence est l'adresse que votre clone
retient sous le nom `origin`.

### 2. Regarder avant de toucher

```bash
git status            # où suis-je, qu'ai-je modifié ?
git log --oneline -5  # les cinq derniers commits
git branch -a         # les branches, ici et sur la forge
git remote -v         # les dépôts distants que ce clone connaît
```

Dites qui vous êtes : chaque commit est signé.

```bash
git config user.name  "equipe-2"
git config user.email "equipe-2@farci.local"
```

Dans la salle, c'est le compte de votre équipe. Chez vous, votre nom et votre
adresse.

### 3. Créer votre branche

```bash
git switch -c poste/equipe-2-atlas
```

`equipe-2` est votre équipe, `atlas` le **surnom de la machine** (pas le vôtre :
un dépôt ne contient pas de nom de personne). À partir de maintenant, ce que
vous commitez reste sur cette branche. `main` n'est pas touchée.

### 4. Adapter le projet à votre machine et à votre rôle

```bash
./bin/farci poste nouveau
```

La commande écrit `postes/equipe-2-atlas.env`, la **fiche de poste** : ce que
la machine est (mémoire, carte graphique) et ce qu'elle fait dans le projet
(équipe, runtime, parcours). Relisez-la et corrigez-la : un portable de 16 Go
ne servira pas le modèle 9B, il prend `llamacpp` ; une machine avec GPU prend
`ollama`.

Cette fiche est **lue par `./bin/farci` tant que vous êtes sur votre branche**.
Changez de branche, la configuration change : c'est exactement à cela que sert
une branche.

Ce qui va dans votre branche : la fiche, et tout réglage versionné que votre
matériel impose (un paramètre de `02-inference/llamacpp/params.json`, une
limite mémoire dans un `docker-compose.yml`). Ce qui n'y va **jamais** : les
mots de passe (`.env`), les adresses de la salle (`config/network.env`), un
modèle, un nom de personne.

### 5. Commiter

```bash
git status
git diff                                   # ce qui va partir, ligne à ligne
git add postes/equipe-2-atlas.env
git commit -m "poste: atlas, 16 Go sans GPU, llama.cpp et modèle 2B"
```

Un commit = **une** modification, avec un message qui dit pourquoi.

### 6. Rejoindre la forge de la salle, et pousser

C'est le basculement : vous êtes maintenant sur le Wi-Fi `FARCI-SALLE`.

```bash
./bin/farci poste salle
git remote -v
git push -u salle poste/equipe-2-atlas
```

`./bin/farci poste salle` ajoute à votre clone un **second dépôt distant**,
nommé `salle` : la forge Gitea du Pi. Elle y enregistre aussi le compte de
votre équipe (`equipe-2`), qui existe déjà. `git remote -v` vous montre le
résultat : `origin` pointe toujours vers GitHub, où vous ne pouvez que lire ;
`salle` pointe vers la forge, où vous publiez. Un même projet peut avoir
plusieurs dépôts distants : c'est ce qui rend git indépendant d'un site.

À la main, cela s'écrirait `git remote add salle http://<forge>/FARCI/farci.git`.

### 7. Ouvrir une Pull Request

Dans le navigateur, sur la forge : **Nouvelle demande d'ajout**, de votre
branche vers `seance`. Une **autre équipe** la relit et l'approuve : personne
ne valide son propre travail. `./bin/farci poste` vous donne le lien direct.

### 8. Recevoir le travail des autres

```bash
git fetch salle
git merge salle/seance
```

Chaque équipe ajoute **son** fichier dans `postes/` : les fusions se passent
sans conflit. Un conflit n'arrive que si deux personnes modifient la même
ligne ; git vous le montre, vous choisissez, vous commitez.

---

## Les branches du projet

| Branche | Qui y écrit | À quoi elle sert |
|---|---|---|
| `main` | personne à la main : `./bin/farci forge-sync` y copie GitHub | la référence, identique sur GitHub et sur Gitea |
| `seance` | une Pull Request relue par une autre équipe | le travail commun de la salle, pendant la séance |
| `poste/equipe-<N>-<surnom>` | vous | votre machine, votre rôle |

Ce qui mérite de survivre à la séance remonte ensuite vers GitHub par une Pull
Request (`CONTRIBUTING.md`, « Deux forges »).

---

## Après l'atelier

**Continuer sur GitHub** (c'est là, et seulement là, qu'un compte GitHub
sert). Sur la page du projet, *Fork* crée votre copie.
Votre clone garde tout votre historique : il suffit de lui présenter ce
nouveau dépôt.

```bash
git remote add moi https://github.com/<votre-compte>/FARCI.git
git push -u moi poste/equipe-2-atlas
```

**Héberger votre propre forge.** La brique de l'équipe 0 est une forge Gitea
complète, prête à tourner sur n'importe quelle machine avec Docker :

```bash
./bin/farci read 0
./bin/farci up 00-gitops
```

Un service, un hôpital ou un laboratoire qui ne peut pas confier son code à
un tiers travaille ainsi : mêmes commandes git, mêmes Pull Requests, serveur
chez soi.

---

## Quand ça coince

| Ce que vous voyez | Ce qui se passe | Quoi faire |
|---|---|---|
| `Please tell me who you are` | git ne sait pas qui signe | les deux `git config` de l'étape 2 |
| `Authentication failed` au push | vous poussez vers GitHub (`origin`), ou le compte n'est pas branché | `./bin/farci poste salle`, puis `git push -u salle <votre branche>` |
| `protected branch` | vous poussez sur `main` ou `seance` | c'est voulu : poussez **votre** branche, puis Pull Request |
| `rejected … fetch first` | la forge a des commits que vous n'avez pas | `git fetch salle` puis `git merge salle/<votre branche>` |
| `forge injoignable` | vous n'êtes pas sur le Wi-Fi de la salle | rejoindre `FARCI-SALLE`, puis `./bin/farci poste salle` |
| `CONFLICT` pendant un merge | deux modifications de la même ligne | ouvrir le fichier, garder la bonne version, `git add`, `git commit` |
| vous avez commité sur `main` | la branche n'a pas été créée avant | `git switch -c poste/equipe-<N>-<surnom>` : le commit vous suit |
| `detached HEAD` | vous regardez un ancien commit | `git switch <votre branche>` |
| vous ne savez plus où vous en êtes | — | `./bin/farci poste`, puis `git status` |

Rien n'est perdu tant que c'est commité. En cas de doute, **ne forcez
jamais** (`--force`) : levez la main.

---

## Aide-mémoire

```bash
git clone <adresse> farci        # recevoir le projet
git status                       # où j'en suis
git switch -c <branche>          # créer ma branche
git add <fichier>                # choisir ce qui part
git commit -m "message"          # enregistrer, avec une explication
./bin/farci poste salle          # en salle : brancher la forge (dépôt distant « salle »)
git push -u salle <branche>      # publier
git fetch salle                  # recevoir
git merge salle/seance           # intégrer le travail commun
git log --oneline --graph --all  # voir l'histoire, branches comprises
```

## Voir aussi

- `./bin/farci poste` — où j'en suis, et la commande suivante
- `./bin/farci read 0` — la forge Gitea de la salle
- `CONTRIBUTING.md` — les règles du dépôt, GitHub et Gitea
- `docs/AIRGAP.md` — ce qui passe par Internet, et ce qui n'y passe jamais
