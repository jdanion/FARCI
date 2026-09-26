# Les contrats

Ce document réunit les **trois** contrats du projet. Un contrat est une
description précise de ce qu'une brique doit offrir, indépendante de la
technologie qui l'implémente.

C'est le document le plus important de l'atelier : c'est lui qui permet de
remplacer une implémentation sans réécrire l'application.

---

## Vue d'ensemble

| Couche | Implémentations | Contrat | Test |
|---|---|---|---|
| Inférence | Ollama, llama.cpp, oMLX | `GET /v1/models`, `POST /v1/chat/completions` | `tests/test_inference_contract.sh` |
| Passerelle LLM | LiteLLM, Bifrost | le contrat OpenAI **+** authentification, alias, quota, repli | `tests/test_gateway_contract.sh` |
| Observabilité | Phoenix, Langfuse | export **OTLP** vers `OTEL_EXPORTER_OTLP_ENDPOINT` | `tests/test_observability.sh` |

---

## Contrat 1 — Inférence

Une implémentation d'inférence **doit** offrir, sur son port d'écoute :

```http
GET  /v1/models
→ 200 {
    "object": "list",
    "data": [ { "id": "<identifiant>", "object": "model" } ]
  }
```

```http
POST /v1/chat/completions
Content-Type: application/json

{ "model": "<identifiant>",
  "messages": [ { "role": "user", "content": "..." } ],
  "temperature": 0, "stream": false }
→ 200 {
    "id": "...",
    "object": "chat.completion",
    "model": "<identifiant>",
    "choices": [ { "index": 0,
                   "message": { "role": "assistant",
                                "content": "...",
                                "reasoning_content": "..."  },
                   "finish_reason": "stop" } ],
    "usage": { "prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0 } }
```

### Exigences transversales

| # | Exigence | Conséquence si elle manque |
|---|---|---|
| I1 | `stream: false` supporté | les tests ne peuvent pas compter les jetons simplement |
| I2 | `usage` renseigné | pas de mesure de coût ni de latence par jeton |
| I3 | `model` **stable** entre deux appels | l'évaluation ne peut pas attribuer un résultat à une configuration |
| I4 | `X-Request-Id` et `traceparent` **propagés** | les traces se perdent d'une couche à l'autre |
| I5 | 401 si une clé est exigée | une interface ouverte sur le réseau pédagogique |
| I6 | **aucun appel sortant** | l'air-gap est rompu |
| I7 | un endpoint de santé sur une **URL réelle** | le tableau de bord ment |

### I8 — `reasoning_content` (exigence obtenue de la réalité)

Les deux modèles retenus sont des **modèles à raisonnement** : ils ouvrent leur
réponse par un bloc de raisonnement. Le contrat impose donc :

- `content` contient **uniquement** la réponse exploitable — jamais de raisonnement,
  jamais de bloc ```` ```json ````, jamais de texte avant ou après ;
- `reasoning_content`, s'il existe, est une chaîne **distincte** et facultative ;
- le client DOIT refuser un `content` qui contient du raisonnement.

C'est un cas d'école : le contrat a dû être complété **après** le choix des
modèles. Un contrat écrit avant, sans cette exigence, aurait produit un système
qui marche avec un modèle et casse avec l'autre.

---

## Contrat 2 — Passerelle LLM

Le contrat d'inférence, **plus** ce que la gateway apporte en propre :

```http
GET  /v1/models
→ SEULEMENT le modèle logique "med-extraction*" est visible.
   Le vrai nom du modèle ne doit jamais fuir vers le client.
```

```http
POST /v1/chat/completions
Authorization: Bearer sk-...
```

| # | Exigence | Détail |
|---|---|---|
| G1 | Authentification par clé virtuelle | 401 si absente ou inconnue |
| G2 | Alias de modèle | l'application demande `med-extraction`, jamais `ornith-1.5-9b` |
| G3 | Limitation de débit | clé standard : 10 RPM → **429** + `Retry-After` ; clé prioritaire : 120 RPM |
| G4 | Repli automatique | primaire arrêté → le secondaire répond **200**, le client ne change pas d'adresse |
| G5 | Indication de repli | un en-tête permet de savoir qu'un repli a eu lieu (observabilité du comportement) |
| G6 | Le raisonnement est neutralisé | `think: false` / équivalent, sinon le structured output casse |
| G7 | Distribution réaliste | ce qui précède est fait par la gateway, pas par le client |

---

## Contrat 3 — Observabilité

Le contrat n'est pas « Phoenix » ni « Langfuse » : c'est **OpenTelemetry**.

Le code d'instrumentation est écrit **une fois** et pointe vers une variable
d'environnement. Le même flux peut alimenter les deux backends.

Une trace minimale doit contenir :

| Champ | Origine |
|---|---|
| `trace_id` | OTel |
| `service` | attribut de ressource |
| `operation` | nom du span |
| `model` | `gen_ai.request.model` — le nom **logique** |
| `latency` | durée du span |
| `status` | `OK` / `ERROR` |
| `error` | message le cas échéant |
| `input_tokens`, `output_tokens` | si le runtime les expose |

### Contraintes

- O1 : la perte de l'observabilité **ne doit pas** interrompre l'extraction
  (scénario de chaos n° 7 le vérifie) ;
- O2 : l'export est asynchrone, avec un délai court et un échec silencieux ;
- O3 : la trace ne doit **pas** contenir le raisonnement du modèle ;
- O4 : le raisonnement est ailleurs, dans les journaux d'erreur, pour l'analyse.

---

## Comment ajouter une implémentation en quatre étapes

C'est l'exercice qui valide que le contrat est bon.

1. **Implémenter** les endpoints décrits ci-dessus, et rien de plus.
2. **Écrire** le test contractuel de la couche, en ne connaissant que le contrat.
3. **Faire passer** le test existant **sans le modifier**.
4. **Brancher** dans `config/services.yaml` avec des chemins de santé, et la
   brique apparaît dans le tableau de progression.

Si l'étape 3 exige de toucher au test, ce n'est pas une nouvelle implémentation
de la même chose : c'est un contrat différent. Il faut alors écrire un nouveau
contrat, et assumer que les deux couches ne sont pas interchangeables.

---

## Voir aussi

- `docs/ARCHITECTURE.md` — pourquoi ces couches
- `02-inference/CONTRACT.md`, `03-llm-gateway/CONTRACT.md`,
  `05-observability/CONTRACT.md` — les copies Detailed par équipe
- `tests/` — les tests qui vérifient ces contrats
