# Équipe 1 — Réseau & Dashboard (Caddy, Uptime Kuma, health-aggregator)

## Attendus pédagogiques

- Comprendre ce qu'est un reverse proxy et pourquoi on l'utilise
- Comprendre la notion de réseau Docker et d'IP statique
- Comprendre ce qu'est un healthcheck et pourquoi il est critique
- Comprendre la différence entre un dashboard et un moniteur
- Savoir agréger l'état de santé de plusieurs services

## Solution simple (scripts)

```bash
# 1. Démarrer Caddy + health-aggregator (+ Uptime Kuma, bonus)
./bin/farci up 01-network-dashboard

# 2. Vérifier : ligne Network verte, test network PASS
./bin/farci status
./bin/farci test

# 3. Bonus : créer les sondes Uptime Kuma depuis le registre
scripts/uptime-kuma-seed.sh
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Créer le réseau Docker avec sous-réseau

```bash
docker network create \
  --subnet="$FARCI_SUBNET" \
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
curl -X POST $UPTIME_KUMA_URL/api/monitors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "CLINICAL AI PIPELINE",
    "type": "http",
    "url": "$CADDY_URL/healthz",
    "interval": 30
  }'
```

## Vérifications

- [ ] Caddy accessible sur $CADDY_URL
- [ ] Uptime Kuma accessible sur $UPTIME_KUMA_URL
- [ ] health-aggregator répond sur /status
- [ ] 14 moniteurs créés dans 7 groupes
