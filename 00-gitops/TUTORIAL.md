# TUTORIAL — Équipe 0 : GitOps (brique bonus)

## Mission

Monter la forge de l'atelier (Gitea) et son intégration continue (act_runner),
pour que chaque équipe livre sa brique par Pull Request.

- **Objectif minimal** : Gitea répond, la ligne `GitOps` passe au vert.
- **Bonus** : runner enregistré, `main` protégée, la CI (`./bin/farci ci`)
  tourne sur chaque PR.

Brique **bonus** : elle n'entre pas dans `CLINICAL PIPELINE READY`. Si elle
manque, le formateur la remplace par une démonstration.

## Ce que votre service apporte

Une trace écrite de qui a changé quoi, et une vérification automatique avant
intégration. C'est la « procédure » de l'hôpital : ce qui est versionné est ce
qui est installé.

## Ce que vous devez comprendre

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

Le runner déclare le label `farci` : c'est le `runs-on:` des workflows de
`.gitea/workflows/`.

## Démarrage

```bash
./bin/farci up 00-gitops
00-gitops/gitea/bootstrap.sh          # organisation, administrateur, dépôt
./bin/farci forge-sync push           # main de GitHub → Gitea (ou from-bundle sans Internet)
00-gitops/runner/register-runner.sh   # vérifie l'enregistrement du runner
00-gitops/post-provision.sh           # protège la branche main
```

GitHub reste la source de vérité : Gitea `main` n'avance que par
`./bin/farci forge-sync` (avance rapide). Les PR de la séance visent la
branche `seance` ; voir `CONTRIBUTING.md`, « Deux forges ».

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

`./bin/farci status` : ligne `GitOps` verte. Dans Gitea, l'onglet *Actions*
du dépôt montre le workflow `tests` vert sur une PR de test.

## Commit

Les fichiers de `00-gitops/` et `.gitea/`. Aucun mot de passe : ils restent
dans `.env`.

## Pull Request

Ouvrir une PR de démonstration (`feat/equipe-0/demo`) et montrer à la salle :
la CI qui tourne, la relecture, le refus d'un push direct sur `main`.

## Définition de DONE

```text
[ ] Gitea démarré
[ ] ligne GitOps verte sur ./bin/farci status
[ ] ./bin/farci test : gitops PASS
[ ] runner enregistré, workflow tests vert sur une PR
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `GITEA_DB_PASSWORD requis` | secrets absents | compléter `.env` (voir `.env.example`) |
| Gitea redémarre en boucle | base PostgreSQL pas prête | `./bin/farci logs 00-gitops` |
| le job CI reste « en attente » | runner absent ou label différent de `farci` | `00-gitops/runner/register-runner.sh` |
