# Équipe 0 — GitOps (bonus)

> Fiche débutant. La référence technique complète est
> `00-gitops/TUTORIAL.md` (`./bin/farci read 0`).

## Votre objectif

Monter **la forge de la salle** (Gitea) pour que chaque équipe livre sa
brique par **Pull Request**, relue par un humain et vérifiée par la CI.
Brique **bonus** : elle n'entre pas dans `CLINICAL PIPELINE READY`.

C'est le dossier de procédures de l'hôpital : ce qui est écrit et relu est
ce qui est appliqué.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine » ; Docker est indispensable (le runner en dépend).
2. **Préparer les secrets** — dans `.env` : `GITEA_ADMIN_PASSWORD`,
   `GITEA_DB_PASSWORD`, `GITEA_SECRET_KEY`, `GITEA_INTERNAL_TOKEN`,
   `GITEA_RUNNER_TOKEN` (remplacer les valeurs d'exemple).
3. **Démarrer** — `./bin/farci up 00-gitops`.
4. **Créer l'organisation et le dépôt** — `00-gitops/gitea/bootstrap.sh`.
5. **Recevoir le code** — le formateur vous donne le fichier
   `farci.bundle` (clé USB) : `./bin/farci forge-sync from-bundle farci.bundle`.
   `main` est la copie de GitHub ; une branche `seance` est créée pour vos PR.
6. **Brancher la CI** — `00-gitops/runner/register-runner.sh`, puis
   `00-gitops/post-provision.sh` (protège `main`).
7. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set gitea <votre-ip>`) : les autres équipes trouvent la forge.
8. **Démontrer** — une PR `feat/equipe-0/demo` vers `seance` : la CI tourne,
   un humain relit.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # gitops   PASS
```

Et `./bin/farci status --all` : `GitOps ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main : la forge est un bonus, le formateur la remplace par une
démonstration.

| Ce que vous voyez | À essayer |
|---|---|
| Gitea ne démarre pas | `./bin/farci logs 00-gitops` : base de données, mots de passe dans `.env` |
| `forge-sync` refuse | normal si `main` a reçu un commit direct : lisez le message, rien n'est perdu |
| le runner ne prend aucun job | le label du workflow (`runs-on: farci`) et l'enregistrement du runner |

## Bonus

- Montrer qu'un push direct sur `main` est **refusé**.
- `CONTRIBUTING.md`, « Deux forges » : pourquoi GitHub reste la source de
  vérité et comment une PR de la séance y remonte (`forge-sync rapatrier`).
