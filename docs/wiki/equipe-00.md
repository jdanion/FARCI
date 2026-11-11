# Équipe 0 — La forge de la salle (Gitea)

> Fiche débutant. La référence technique complète est
> `00-gitops/TUTORIAL.md` (`./bin/farci read 0`).

## Votre objectif

Tenir **la forge de la salle** : un Gitea, le « GitHub hébergé chez soi », où
**toutes les équipes** clonent le projet, poussent la branche de leur poste et
font relire leurs **Pull Requests**. La forge n'entre pas dans
`CLINICAL PIPELINE READY`, mais toute la salle s'en sert.

C'est le dossier de procédures de l'hôpital : ce qui est écrit et relu est
ce qui est appliqué — et il reste dans les murs.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine » ; Docker est indispensable (le runner en dépend).
2. **Préparer les secrets** — dans `.env` : `GITEA_ADMIN_PASSWORD`,
   `GITEA_DB_PASSWORD`, `GITEA_SECRET_KEY`, `GITEA_INTERNAL_TOKEN`,
   `GITEA_RUNNER_TOKEN` (remplacer les valeurs d'exemple), et
   `GITEA_EQUIPE_PASSWORD`, le mot de passe de la salle.
3. **Démarrer** — `./bin/farci up 00-gitops`.
4. **Créer l'organisation, le dépôt et les comptes** —
   `00-gitops/gitea/bootstrap.sh` : un compte `equipe-0` … `equipe-8`.
5. **Recevoir le code de GitHub** — `./bin/farci forge-sync push` : `main`
   est la copie de GitHub ; une branche `seance` est créée pour les PR.
6. **Protéger et brancher la CI** — `00-gitops/runner/register-runner.sh`,
   puis `00-gitops/post-provision.sh` (`main` et `seance` protégées).
7. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set gitea <votre-ip>`) : la page `/rejoindre` de la
   salle affiche le `git clone` de votre forge.
8. **Relire** — les Pull Requests des autres équipes vers `seance` : une
   fiche par machine dans `postes/`.

## Votre branche

Comme tout le monde : `git switch -c poste/equipe-0-<surnom>`, puis
`./bin/farci poste nouveau`. `./bin/farci poste` donne la commande git
suivante ; le guide est `docs/GIT.md`.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # gitops   PASS
```

Et `./bin/farci status --all` : `GitOps ✅ UP`. La vraie preuve : une autre
équipe a cloné depuis votre forge et y a poussé sa branche.

## Bloqué depuis 10 minutes ?

Levez la main : la forge du formateur (sur le Pi) continue de servir la
salle, et GitHub reste joignable pour cloner.

| Ce que vous voyez | À essayer |
|---|---|
| Gitea ne démarre pas | `./bin/farci logs 00-gitops` : base de données, mots de passe dans `.env` |
| `forge-sync` refuse | normal si `main` a reçu un commit direct : lisez le message, rien n'est perdu |
| une équipe ne peut pas pousser | compte `equipe-<N>` et mot de passe de la salle ; pas sur `main` ni `seance` |
| le runner ne prend aucun job | le label du workflow (`runs-on: farci`) et l'enregistrement du runner |

## Bonus

- Montrer qu'un push direct sur `main` ou `seance` est **refusé**.
- `CONTRIBUTING.md`, « Deux forges » : pourquoi GitHub reste la source de
  vérité et comment une PR de la séance y remonte (`forge-sync rapatrier`).
