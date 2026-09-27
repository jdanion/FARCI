# Équipe 0 — GitOps (Gitea + runner)

## Attendus pédagogiques

- Comprendre ce qu'est une forge Git et pourquoi on en utilise une
- Comprendre la différence entre Git et GitHub/Gitea
- Comprendre ce qu'est un runner CI/CD et son rôle
- Comprendre la notion de branche protégée et de Pull Request
- Savoir créer un utilisateur, un dépôt, et un runner

## Solution simple (scripts)

```bash
# 1. Démarrer Gitea + PostgreSQL + runner
cd 00-gitops
docker compose up -d

# 2. Attendre que Gitea soit prêt
curl http://192.168.50.10:3000/api/v1/version

# 3. Bootstrap (création org, admin, dépôt)
export GITEA_ADMIN_PASSWORD="mot-de-passe-admin"
export GITEA_DB_PASSWORD="mot-de-passe-db"
export GITEA_SECRET_KEY="clef-secrete"
export GITEA_INTERNAL_TOKEN="token-interne"
export GITEA_RUNNER_TOKEN="token-runner"
./gitea/bootstrap.sh

# 4. Enregistrer le runner
./runner/register-runner.sh

# 5. Protéger la branche main
./post-provision.sh
```

## Solution from scratch

### 1. Créer le réseau Docker

```bash
docker network create farci
```

### 2. Démarrer PostgreSQL

```bash
docker run -d \
  --name farci-postgres \
  --network farci \
  -e POSTGRES_DB=gitea \
  -e POSTGRES_USER=gitea \
  -e POSTGRES_PASSWORD=mot-de-passe-db \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:18.6-alpine
```

### 3. Démarrer Gitea

```bash
docker run -d \
  --name farci-gitea \
  --network farci \
  -p 3000:3000 \
  -p 2222:22 \
  -e GITEA__database__DB_TYPE=postgres \
  -e GITEA__database__HOST=farci-postgres:5432 \
  -e GITEA__database__NAME=gitea \
  -e GITEA__database__USER=gitea \
  -e GITEA__database__PASSWD=mot-de-passe-db \
  -v gitea-data:/data \
  gitea/gitea:1.27.3
```

### 4. Créer l'utilisateur admin via l'API

```bash
curl -X POST http://192.168.50.10:3000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "farci-admin",
    "password": "mot-de-passe-admin",
    "email": "admin@farci.local",
    "must_change_password": false
  }'
```

### 5. Créer l'organisation et le dépôt

```bash
# Créer l'organisation
curl -X POST http://192.168.50.10:3000/api/v1/orgs \
  -H "Content-Type: application/json" \
  -u "farci-admin:mot-de-passe-admin" \
  -d '{"username": "FARCI", "full_name": "FARCI Workshop"}'

# Créer le dépôt
curl -X POST http://192.168.50.10:3000/api/v1/orgs/FARCI/repos \
  -H "Content-Type: application/json" \
  -u "farci-admin:mot-de-passe-admin" \
  -d '{"name": "farci", "default_branch": "main"}'
```

### 6. Enregistrer le runner

```bash
docker run -d \
  --name farci-act-runner \
  --network farci \
  -e GITEA_INSTANCE_URL=http://192.168.50.10:3000/ \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=token-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitea/act_runner:0.6.1
```

### 7. Protéger la branche main

```bash
curl -X PATCH http://192.168.50.10:3000/api/v1/repos/FARCI/farci/branches/main/protection \
  -H "Content-Type: application/json" \
  -u "farci-admin:mot-de-passe-admin" \
  -d '{
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "enable_status_check": true,
    "block_on_rejected_reviews": true,
    "prevent_push": true
  }'
```

## Vérifications

- [ ] Gitea accessible sur http://192.168.50.10:3000
- [ ] Runner enregistré et actif
- [ ] Push direct sur `main` rejeté
- [ ] PR créée et workflow déclenché
