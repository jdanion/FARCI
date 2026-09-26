# FARCI — Contrat d'inférence (FARCI §16)

Ce contrat définit l'interface entre la gateway et les runtimes d'inférence.
Toute implémentation (Ollama, llama.cpp, oMLX) doit s'y conformer.

---

## Endpoints

### `GET /v1/models`

Retourne la liste des modèles disponibles.

**Réponse 200 :**
```json
{
  "object": "list",
  "data": [
    {
      "id": "ornith-1.5-9b-q5km",
      "object": "model",
      "owned_by": "farci"
    }
  ]
}
```

### `POST /v1/chat/completions`

Génère une complétion de chat.

**Requête :**
```json
{
  "model": "ornith-1.5-9b-q5km",
  "messages": [
    {"role": "system", "content": "You are a medical extraction engine."},
    {"role": "user", "content": "Extract from: [document]"}
  ],
  "temperature": 0,
  "stream": false,
  "max_tokens": 4096
}
```

**Réponse 200 :**
```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "model": "ornith-1.5-9b-q5km",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "{\"patient_id\": \"1234567890123\", ...}"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 512,
    "completion_tokens": 256,
    "total_tokens": 768
  }
}
```

### `GET /health` et `GET /healthz`

**Réponse 200 :**
```json
{"status": "ok"}
```

---

## Exigence critique : `reasoning_content`

Nos modèles (Ornith-1.5-9B, Qwen3.8-27B) sont des *reasoning models*. Leurs réponses
peuvent contenir un bloc de raisonnement AVANT le contenu utile.

**Règle absolue :**
- `content` contient **uniquement** le JSON exploitable
- `reasoning_content` (optionnel) contient le raisonnement, s'il est présent
- Le gateway DOIT neutraliser le raisonnement pour l'extraction (`think: false`)

**Exemple de réponse avec raisonnement :**
```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "reasoning_content": "Je vais extraire les champs du document...",
        "content": "{\"patient_id\": \"1234567890123\"}"
      }
    }
  ]
}
```

**Comportement attendu :**
1. Si `reasoning_content` est présent, l'application doit l'ignorer (pas de parse JSON)
2. Si `content` contient du raisonnement mélangé au JSON → erreur de validation
3. Le gateway coupe le raisonnement et le journalise séparément

---

## Exigences communes

| Exigence | Valeur |
|---|---|
| `model` | Nom logique stable (jamais le nom de fichier GGUF) |
| `stream` | Supporté (`false` par défaut) |
| `temperature` | Respectée (0 = déterministe) |
| `max_tokens` | Respecté |
| `X-Request-Id` | Propagé (observabilité) |
| `traceparent` | Propagé (OpenTelemetry) |
| Air-gap | Aucun appel sortant |

---

## Codes d'erreur

| Code | Signification |
|---|---|
| 400 | Requête invalide (schéma JSON non conforme) |
| 401 | Clé API manquante ou invalide |
| 429 | Rate limit dépassé |
| 500 | Erreur interne du runtime |
| 503 | Runtime indisponible |

---

## Implémentations

| Runtime | Fichier | Notes |
|---|---|---|
| Ollama | `02-inference/ollama/` | `OLLAMA_HOST`, `OLLAMA_KEEP_ALIVE=-1` |
| llama.cpp | `02-inference/llamacpp/` | `--jinja`, `--reasoning off`, GBNF |
| oMLX | `02-inference/omlx/` | Mac uniquement, Metal, hors Docker |

---

## Tests

```bash
BASE_URL=http://192.168.50.20:8080/v1 ./tests/test_inference_contract.sh
```

Le test vérifie :
- La forme de la réponse (schéma)
- La présence de `usage`
- La stabilité du champ `model`
- L'isolation de `reasoning_content`
- Le comportement `temperature=0`
- La latence
