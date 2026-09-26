# TUTORIAL — Équipe 5 : Observabilité

## Objectif

Mettre en place l'observabilité du pipeline LLM : traces, spans, métriques.
Deux backends (Phoenix, Langfuse) consomment le même flux OTLP.

## Architecture

```
Application
    │
    ▼ (OTLP/gRPC)
┌──────────────┐
│ OTel Collector│ ← optionnel (profil `otel`)
│ :4317        │
└──────┬───────┘
       │
  ┌────┴────┐
  ▼         ▼
Phoenix   Langfuse
```

## Démarrage

### Phoenix

```bash
cd 05-observability/phoenix
docker compose up -d
```

### Langfuse

```bash
cd 05-observability/langfuse
cp .env.example .env
# Compléter .env
docker compose up -d
```

### OTel Collector (optionnel)

```bash
cd 05-observability/collector
docker compose up -d
```

## Vérification

```bash
# Phoenix
curl http://192.168.50.51:6006/health

# Langfuse
curl http://192.168.50.52:3000/api/public/health

# Test d'observability
./tests/test_observability.sh
```

## Non-régression (§42)

Le pipeline doit fonctionner avec l'observabilité coupée :

```bash
# Dans le code applicatif :
OTEL_TRACES_EXPORTER=none python ...
```

Les spans ne doivent **jamais** bloquer le chemin critique.

## Dépannage

### Phoenix ne démarre pas

```bash
docker logs farci-phoenix
```

### Langfuse : erreur de base de données

```bash
docker logs farci-langfuse-postgres
docker logs farci-langfuse
```

### Traces non visibles

Vérifier que `OTEL_EXPORTER_OTLP_ENDPOINT` est correctement configuré.
