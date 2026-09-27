# Équipe 8 — Agents Arcane & GitOps

## Attendus pédagogiques

- Comprendre le rôle d'un agent de supervision
- Comprendre la notion de webhook et son intégration avec Git
- Comprendre le principe GitOps (pull + apply)
- Comprendre la notion d'idempotence dans les déploiements
- Savoir vérifier la signature HMAC d'un webhook

## Solution simple (scripts)

```bash
# 1. Démarrer les agents + webhook
cd 08-arcane-agents
docker compose up -d

# 2. Vérifier les agents
docker logs farci-agent-ollama
docker logs farci-agent-gateway

# 3. Tester le webhook
curl -X POST http://192.168.50.60:9000/webhook \
  -H "Content-Type: application/json" \
  -H "X-Gitea-Signature: <signature>" \
  -d '{"ref":"refs/heads/main"}'
```

## Solution from scratch

### 1. Démarrer un agent Arcane

```bash
docker run -d \
  --name farci-agent-ollama \
  --network farci \
  -e TARGET_SERVICE=ollama \
  -e TARGET_URL=http://192.168.50.20:8080 \
  -e CHECK_INTERVAL=30 \
  -v $(pwd)/arcane-agent:/app:ro \
  python:3.13.15-slim-trixie \
  python /app/agent.py
```

### 2. Démarrer le webhook receiver

```bash
docker run -d \
  --name farci-webhook-receiver \
  --network farci \
  -p 9000:9000 \
  -e WEBHOOK_SECRET=mon-secret \
  -e GITOPS_SCRIPT=/app/gitops/gitops.sh \
  -v $(pwd)/gitops:/app/gitops:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  python:3.13.15-slim-trixie \
  python /app/webhook/webhook.py
```

### 3. Configurer le webhook Gitea

```
URL : http://192.168.50.60:9000/webhook
Content type : application/json
Secret : mon-secret
Events : Push, Pull Request
```

### 4. Tester le flux GitOps

```bash
# Un push sur main déclenche :
# 1. Gitea → webhook
# 2. webhook.py vérifie la signature
# 3. gitops.sh pull + apply
# 4. Les agents Arcane supervisent

git push origin main
```

### 5. Vérifier la signature HMAC

```python
import hmac, hashlib

secret = b"mon-secret"
payload = b'{"ref":"refs/heads/main"}'
signature = hmac.new(secret, payload, hashlib.sha256).hexdigest()
# → signature à envoyer dans X-Gitea-Signature
```

## Vérifications

- [ ] 5 agents Arcane actifs (ollama, llamacpp, gateway, docling, mlflow)
- [ ] Webhook receiver écoute sur :9000
- [ ] Push sur main déclenche GitOps
- [ ] Déploiement idempotent
