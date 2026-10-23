# Équipe 0 — GitOps (Gitea + runner)

## Attendus pédagogiques

- Comprendre ce qu'est une forge Git et pourquoi on en utilise une
- Comprendre la différence entre Git et GitHub/Gitea
- Comprendre ce qu'est un runner CI/CD et son rôle
- Comprendre la notion de branche protégée et de Pull Request
- Savoir créer un utilisateur, un dépôt, et un runner

## Solution simple (scripts)

```bash
# 1. Secrets : compléter .env (modèle : .env.example), puis démarrer
./bin/farci up 00-gitops

# 2. Organisation, administrateur, dépôt
00-gitops/gitea/bootstrap.sh

# 3. Runner (label « farci ») et protection de main
00-gitops/runner/register-runner.sh
00-gitops/post-provision.sh

# 4. Vérifier : ligne GitOps verte, test gitops PASS
./bin/farci status
./bin/farci test
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

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
curl -X POST $GITEA_URL/api/v1/admin/users \
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
curl -X POST $GITEA_URL/api/v1/orgs \
  -H "Content-Type: application/json" \
  -u "farci-admin:mot-de-passe-admin" \
  -d '{"username": "FARCI", "full_name": "FARCI Workshop"}'

# Créer le dépôt
curl -X POST $GITEA_URL/api/v1/orgs/FARCI/repos \
  -H "Content-Type: application/json" \
  -u "farci-admin:mot-de-passe-admin" \
  -d '{"name": "farci", "default_branch": "main"}'
```

### 6. Enregistrer le runner

```bash
docker run -d \
  --name farci-act-runner \
  --network farci \
  -e GITEA_INSTANCE_URL=$GITEA_URL/ \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=token-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitea/act_runner:0.6.1
```

### 7. Protéger la branche main

```bash
curl -X PATCH $GITEA_URL/api/v1/repos/FARCI/farci/branches/main/protection \
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

- [ ] Gitea accessible sur $GITEA_URL
- [ ] Runner enregistré et actif
- [ ] Push direct sur `main` rejeté
- [ ] PR créée et workflow déclenché
