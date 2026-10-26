# TUTORIAL — Équipe 8 : Agents Arcane et déploiement GitOps (brique bonus)

## Mission

Placer un petit agent de supervision à côté de chaque brique et déclencher un
déploiement automatique quand la branche `seance` change (webhook Gitea → `gitops.sh`).

- **Objectif minimal** : les agents tournent et signalent l'état de leur brique.
- **Bonus** : une PR fusionnée sur `seance` redéploie une brique sans intervention.

Brique **bonus** : démonstration du formateur si personne ne la prend.

## Ce que votre service apporte

La boucle complète du GitOps : ce qui est fusionné dans le dépôt est ce qui
tourne, et un écart se voit.

## Ce que vous devez comprendre

- **Réconciliation** : l'état voulu est dans Git, l'état réel est sur les
  machines ; un agent compare et corrige.
- **Idempotence** : relancer un déploiement identique ne change rien.

## Vos dépendances

GitOps (équipe 0) pour le webhook ; les briques à superviser.

## Votre IP

Les agents n'ont pas d'adresse fixe ; chacun reçoit l'URL de sa brique par
`TARGET_URL`, construite depuis `config/network.env` dans
`08-arcane-agents/docker-compose.yml`.

## Installation

Image `python` préchargée : les agents sont construits localement à partir
d'elle (`PYTHON_IMAGE_TAG`, `versions.env`).

## Configuration

- `.env` : `WEBHOOK_SECRET` (partagé avec le webhook Gitea),
  `ALERT_WEBHOOK_URL` (optionnel).
- `08-arcane-agents/arcane-agent/config.yaml` : intervalles de sonde.

## Démarrage

```bash
./bin/farci up 08-arcane-agents
```

## Test local

```bash
./bin/farci logs 08-arcane-agents
```

Chaque agent écrit l'état de sa brique toutes les 30 s.

## Test contractuel

Fusionner une PR sur la branche `seance` dans Gitea (jamais sur `main`, qui ne reçoit que GitHub : `CONTRIBUTING.md`) : `08-arcane-agents/gitops/webhook-handler.sh`
doit apparaître dans les journaux du récepteur, suivi de `gitops.sh`.

## Vérification sur le tableau de bord

Pas de ligne dédiée : les agents surveillent les lignes existantes de
`./bin/farci status`.

## Commit

Code des agents et du webhook. Jamais le secret du webhook.

## Pull Request

Montrer le journal d'un redéploiement déclenché par un push.

## Définition de DONE

```text
[ ] agents démarrés, un par brique
[ ] webhook reçu et déploiement idempotent
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `WEBHOOK_SECRET requis` | secret absent | l'ajouter dans `.env` |
| un agent signale « down » en boucle | la brique n'est pas démarrée | `./bin/farci status` |
| la construction échoue hors ligne | image `python` absente | `./bin/farci verify-images` |
