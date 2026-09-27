# FARCI — Contrat LLM Gateway (FARCI §18)

Ce contrat définit l'interface entre les applications et la gateway LLM.
La gateway masque les runtimes et expose un nom de modèle logique unique.

---

## Principe : le gateway est un mur

L'application **ne voit jamais** les vrais noms de modèles
(`ornith-1.5-9b`, `qwen3.8-27b`). Elle utilise des **aliases logiques** :

| Alias | Cible | Usage |
|---|---|---|
| `med-extraction` | Ollama (primaire) + llama.cpp (fallback) | défaut |
| `med-extraction-lite` | Qwen3.5-2B | CI, tests rapides |
| `med-extraction-max` | Qwen3.8-27B | postes ≥ 24 Go VRAM |
| `med-extraction-mac` | oMLX | Mac ≥ 32 Go RAM |

---

## Endpoints

### `GET /v1/models`

Retourne **uniquement** les aliases `med-extraction*` (jamais les vrais noms).

```json
{
  "object": "list",
  "data": [
    {"id": "med-extraction", "object": "model"},
    {"id": "med-extraction-lite", "object": "model"},
    {"id": "med-extraction-max", "object": "model"}
  ]
}
```

### `POST /v1/chat/completions`

**Authentification obligatoire :**
```
Authorization: Bearer sk-...
```

| Clé | Rate limit | Comportement si dépassé |
|---|---|---|
| `sk-standard` | 10 RPM | 429 + `Retry-After` |
| `sk-priority` | 120 RPM | 429 + `Retry-After` |

**En-têtes de réponse :**
- `x-litellm-model-id` : modèle logique utilisé (toujours un alias)
- `x-fallback-applied` : `true` si le fallback a été utilisé
- `x-litellm-attempt` : numéro de tentative (1, 2, ...)

**En-têtes de requête :**
- `X-Request-Id` : propagé au runtime
- `traceparent` : propagé (OpenTelemetry)

---

## Comportement en cas de panne

Si le runtime primaire est indisponible :
1. La gateway essaie le runtime secondaire (fallback)
2. Si le fallback répond 200, la réponse est retournée avec `x-fallback-applied: true`
3. **Le client ne change pas** : même endpoint, même contrat

---

## Le gateway est le mur anti-raisonnement

Nos modèles sont des *reasoning models*. Le gateway :
1. Envoie `think: false` au runtime (Ollama) ou `--reasoning off` (llama.cpp)
2. Coupe `reasoning_content` de la réponse
3. Le journalise séparément (pour analyse d'erreur)
4. Ne retourne que le JSON dans `content`

**Sans cela, Pydantic échoue et l'étape 2 s'effondre.**

---

## Codes d'erreur

| Code | Signification |
|---|---|
| 400 | Requête invalide |
| 401 | Clé API absente ou invalide |
| 429 | Rate limit dépassé (+ `Retry-After`) |
| 500 | Erreur interne |
| 503 | Primaire et secondaire tous deux KO |

---

## Tests

```bash
# Test du contrat (paramétrable par implémentation)
IMPL=litellm ./tests/test_gateway_contract.sh
IMPL=bifrost ./tests/test_gateway_contract.sh

# Test de failover
./tests/test_failover.sh
```
