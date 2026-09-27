# TUTORIAL — Phase 15 : Agents Arcane & GitOps

## Objectif

Déployer un agent de supervision (Arcane) sur chaque brique Docker du pipeline,
et orchestrer les déploiements via GitOps (webhook Gitea → gitops.sh).

## Architecture

```
Gitea (push/PR)
    │
    ▼ (webhook)
┌─────────────┐
│  Webhook    │  ← reçoit les événements Git
│  Receiver   │
└──────┬──────┘
       │
       ▼ (GitOps)
┌─────────────┐
│  gitops.sh  │  ← pull + apply
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Agents Arcane (conteneurs Docker)  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│  │Ollama│ │LLM  │ │Docl.│ │MLfl.│  │
│  │agent │ │agent│ │agent│ │agent│  │
│  └─────┘ └─────┘ └─────┘ └─────┘  │
└─────────────────────────────────────┘
```

## Démarrage

### 1. Agents Arcane

```bash
cd 08-arcane-agents
docker compose up -d
```

### 2. Webhook Receiver

Le webhook receiver est déjà inclus dans le docker-compose.yml.
Il écoute sur le port 9000.

### 3. Configuration du webhook Gitea

Dans Gitea :
1. Aller dans le dépôt → Settings → Webhooks
2. Ajouter un webhook :
   - URL : `http://192.168.50.60:9000/webhook`
   - Content type : `application/json`
   - Secret : `${WEBHOOK_SECRET}`
   - Events : Push, Pull Request

## Fonctionnement

### Agent Arcane

Chaque agent :
1. Vérifie l'état de santé de sa brique cible
2. Log le résultat (🟢 up / 🔴 down)
3. Envoie une alerte si le service est down

### GitOps

1. Un push sur `main` déclenche le webhook
2. Le webhook receiver vérifie la signature
3. `gitops.sh` pull le dépôt et apply les manifests
4. Les agents Arcane supervisent le résultat

## Dépannage

### Agent ne démarre pas

```bash
docker logs farci-agent-ollama
```

### Webhook non reçu

```bash
docker logs farci-webhook-receiver
```

### GitOps échoué

```bash
docker logs farci-webhook-receiver
docker compose -f 02-inference/ollama/docker-compose.yml logs
```
