# Équipe 1 — Réseau & Dashboard (Caddy, Uptime Kuma, health-aggregator)

## Attendus pédagogiques

- Comprendre ce qu'est un reverse proxy et pourquoi on l'utilise
- Comprendre la notion de réseau Docker et d'IP statique
- Comprendre ce qu'est un healthcheck et pourquoi il est critique
- Comprendre la différence entre un dashboard et un moniteur
- Savoir agréger l'état de santé de plusieurs services

## Solution simple (scripts)

```bash
# 1. Démarrer Caddy + Uptime Kuma + health-aggregator
cd 01-network-dashboard
docker compose up -d

# 2. Vérifier Caddy
curl http://192.168.50.15/healthz

# 3. Vérifier Uptime Kuma
curl http://192.168.50.16:3001

# 4. Vérifier health-aggregator
curl http://192.168.50.15:8081/status

# 5. Seeder les moniteurs Uptime Kuma
./scripts/uptime-kuma-seed.sh
```

## Solution from scratch

### 1. Créer le réseau Docker avec sous-réseau

```bash
docker network create \
  --subnet=192.168.50.0/24 \
  farci
```

### 2. Démarrer Caddy

```bash
docker run -d \
  --name farci-caddy \
  --network farci \
  -p 80:80 \
  -v $(pwd)/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v caddy-data:/data \
  caddy:2.11.4-alpine
```

### 3. Démarrer Uptime Kuma

```bash
docker run -d \
  --name farci-uptime-kuma \
  --network farci \
  -p 3001:3001 \
  -v uptime-kuma-data:/app/data \
  louislam/uptime-kuma:2.5.5
```

### 4. Démarrer health-aggregator

```bash
docker run -d \
  --name farci-health-aggregator \
  --network farci \
  -p 8081:8081 \
  -v $(pwd)/health-aggregator:/app:ro \
  -v $(pwd)/../../config/services.yaml:/app/config/services.yaml:ro \
  python:3.13.15-slim-trixie \
  python /app/app.py
```

### 5. Configurer les routes Caddy

Le Caddyfile définit les routes :
- `/v1/*` → gateway
- `/docling/*` → Docling
- `/kuma/*` → Uptime Kuma
- `/status` → health-aggregator
- `/healthz` → health-aggregator

### 6. Créer les moniteurs Uptime Kuma

```bash
# Via l'API REST
curl -X POST http://192.168.50.16:3001/api/monitors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "CLINICAL AI PIPELINE",
    "type": "http",
    "url": "http://192.168.50.15/healthz",
    "interval": 30
  }'
```

## Vérifications

- [ ] Caddy accessible sur http://192.168.50.15
- [ ] Uptime Kuma accessible sur http://192.168.50.16:3001
- [ ] health-aggregator répond sur /status
- [ ] 14 moniteurs créés dans 7 groupes
