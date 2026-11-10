# TUTORIAL — Équipe 0 : la forge de la salle (Gitea)

## Mission

Tenir la forge de l'atelier : un **Gitea hébergé dans la salle**, où **toutes
les équipes** clonent le projet, poussent la branche de leur poste et ouvrent
leurs Pull Requests (`docs/GIT.md`).

- **Objectif minimal** : Gitea répond, le projet y est (`main` et `seance`),
  les comptes `equipe-0` à `equipe-8` peuvent pousser, la ligne `GitOps`
  passe au vert.
- **Ensuite** : relire et fusionner les Pull Requests de la salle vers
  `seance` ; runner enregistré, la CI (`./bin/farci ci`) tourne sur chaque PR.

La forge n'entre pas dans `CLINICAL PIPELINE READY` : l'extraction ne dépend
pas d'elle. Mais toute la salle s'en sert dès l'accueil : le formateur l'ouvre
sur le Pi avant la séance, et votre équipe la reprend sur sa machine.

## Ce que votre service apporte

Le « GitHub de la salle » : le même projet que sur GitHub, mais sur une machine
que l'on possède. Une trace écrite de qui a changé quoi, une relecture avant
intégration, et rien qui dépende d'Internet ou d'un tiers. C'est ce
qu'installe un hôpital dont le code ne doit pas sortir des murs.

## Ce que vous devez comprendre

- **Git est décentralisé** : GitHub et Gitea hébergent le **même** dépôt. Un
  clone peut connaître les deux (`git remote -v`) ; les commandes sont les
  mêmes.
- **GitHub reste la source de vérité** : Gitea `main` n'en est que la copie
  (`./bin/farci forge-sync`). Le travail de la séance vit sur `seance` et sur
  les branches `poste/*`.
- **GitOps = le dossier de procédures vivant** : l'infrastructure est décrite
  dans un dépôt ; on la modifie par une demande relue, pas à la main.
- **CI** : à chaque PR, une machine rejoue les contrôles (`./bin/farci ci`).
  Un humain relit, la machine vérifie.

## Vos dépendances

Aucune. Le runner a besoin de Docker sur la machine qui l'héberge.

## Votre IP

`GITEA_IP`, port `GITEA_PORT` (`config/network.env`).

## Installation

Images `gitea`, `act_runner`, `postgres` et `node` (image des jobs de CI)
préchargées : `./bin/farci verify-images --all`.

## Configuration

Dans `.env` (jamais commité) : `GITEA_ADMIN_PASSWORD`, `GITEA_DB_PASSWORD`,
`GITEA_SECRET_KEY`, `GITEA_INTERNAL_TOKEN`, `GITEA_RUNNER_TOKEN`. Les valeurs
d'exemple sont dans `.env.example` : les remplacer.

`GITEA_EQUIPE_PASSWORD` est le mot de passe commun des comptes `equipe-0` à
`equipe-8` : il s'écrit au tableau, il ne protège que la durée de la séance.
On **lit** la forge sans compte (réseau de la salle), on y **écrit** avec le
compte de son équipe.

Le runner déclare le label `farci` : c'est le `runs-on:` des workflows de
`.gitea/workflows/`.

## Démarrage

```bash
./bin/farci up 00-gitops
00-gitops/gitea/bootstrap.sh          # organisation, administrateur, dépôt, comptes des équipes
./bin/farci forge-sync push           # main de GitHub → Gitea, et création de seance
00-gitops/runner/register-runner.sh   # vérifie l'enregistrement du runner
00-gitops/post-provision.sh           # protège main (copie) et seance (PR relue)
```

Sans Internet, `./bin/farci forge-sync from-bundle <fichier>` remplace le
`push` (le fichier vient de `forge-sync bundle`, fait là où GitHub répond).

GitHub reste la source de vérité : Gitea `main` n'avance que par
`./bin/farci forge-sync` (avance rapide). Les PR de la séance visent la
branche `seance` ; voir `CONTRIBUTING.md`, « Deux forges ».

Puis donnez l'adresse à la salle : le formateur lance
`./bin/farci room set gitea <votre IP>` sur le Pi, et la page `/rejoindre`
affiche la commande `git clone` de **votre** forge.

## Test local

```bash
./bin/farci status
```

La ligne `GitOps` doit être verte.

## Test contractuel

```bash
./bin/farci test
```

La ligne `gitops` doit être `PASS`.

## Vérification sur le tableau de bord

`./bin/farci status` : ligne `GitOps` verte. Dans Gitea, la liste des branches
se remplit de `poste/equipe-…` : une par machine de la salle. L'onglet
*Actions* du dépôt montre le workflow `tests` vert sur une PR.

## Commit

Comme toutes les équipes, sur la branche de votre poste
(`./bin/farci poste`) : sa fiche dans `postes/`, et vos réglages de
`00-gitops/` et `.gitea/`. Aucun mot de passe : ils restent dans `.env`.

## Pull Request

Vous êtes les premiers à ouvrir la vôtre vers `seance`, pour montrer à la
salle : la relecture par une autre équipe, la CI qui tourne, le refus d'un
push direct sur `main` ou sur `seance`. Ensuite, vous relisez celles des
autres.

## Définition de DONE

```text
[ ] Gitea démarré
[ ] main et seance présentes, comptes equipe-0 à equipe-8 créés
[ ] ligne GitOps verte sur ./bin/farci status
[ ] ./bin/farci test : gitops PASS
[ ] une autre équipe a cloné depuis la forge et poussé sa branche
[ ] runner enregistré, workflow tests vert sur une PR
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `GITEA_DB_PASSWORD requis` | secrets absents | compléter `.env` (voir `.env.example`) |
| une équipe ne peut pas pousser | compte ou mot de passe | compte `equipe-<N>`, mot de passe `GITEA_EQUIPE_PASSWORD` ; relancer `00-gitops/gitea/bootstrap.sh` |
| `protection de seance : échec` | la branche n'existe pas encore | `./bin/farci forge-sync push`, puis `00-gitops/post-provision.sh` |
| Gitea redémarre en boucle | base PostgreSQL pas prête | `./bin/farci logs 00-gitops` |
| le job CI reste « en attente » | runner absent ou label différent de `farci` | `00-gitops/runner/register-runner.sh` |
