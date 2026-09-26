# TUTORIAL — Équipe 0 : GitOps

## Objectif

Mettre en place la forge Git (Gitea) et l'intégration continue (act_runner)
pour le workshop FARCI.

## Prérequis

- Docker et Docker Compose installés
- Réseau `farci` créé (`docker network create farci`)
- Variables d'environnement configurées dans `.env`

## Étapes

### 1. Démarrer Gitea

```bash
cd 00-gitops
docker compose up -d
```

### 2. Attendre que Gitea soit prêt

```bash
curl http://192.168.50.10:3000/api/v1/version
```

### 3. Bootstrap (création org, admin, dépôt)

```bash
export GITEA_ADMIN_PASSWORD="mot-de-passe-admin"
export GITEA_DB_PASSWORD="mot-de-passe-db"
export GITEA_SECRET_KEY="clef-secrete"
export GITEA_INTERNAL_TOKEN="token-interne"
export GITEA_RUNNER_TOKEN="token-runner"
./gitea/bootstrap.sh
```

### 4. Enregistrer le runner

```bash
./runner/register-runner.sh
```

### 5. Protéger la branche main

```bash
./post-provision.sh
```

### 6. Créer une Pull Request

```bash
git checkout -b feat/test-pr
# ... modifications ...
git add .
git commit -m "test: PR de démonstration"
git push origin feat/test-pr
# Créer l'UI ou via l'API
```

## Vérifications

- [ ] Gitea accessible sur http://192.168.50.10:3000
- [ ] Runner enregistré et actif
- [ ] Push direct sur `main` rejeté
- [ ] PR créée et workflow déclenché

## Dépannage

### Gitea ne démarre pas

```bash
docker logs farci-gitea
docker logs farci-postgres
```

### Runner non enregistré

```bash
docker logs farci-act-runner
```

### Token invalide

Régénérer le token dans `.env` et redémarrer les conteneurs.
