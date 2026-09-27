# FARCI — Contrat d'observabilité (FARCI §23)

Le vrai contrat d'observabilité est **OTLP** (OpenTelemetry Protocol).
Phoenix et Langfuse sont des backends qui consomment ce flux.

---

## Trace minimale obligatoire

Chaque requête LLM doit produire une trace avec :

| Champ | Type | Description |
|---|---|---|
| `trace_id` | string | Identifiant de trace (propagé) |
| `service` | string | Nom du service (`farci-app`, `gateway`, `runtime`) |
| `operation` | string | `chat.completion`, `convert.file`, etc. |
| `model` | string | Modèle logique (`med-extraction`) |
| `latency` | ms | Durée de l'opération |
| `status` | string | `ok`, `error` |
| `error` | string? | Message d'erreur si `status=error` |
| `input_tokens` | int? | Tokens en entrée |
| `output_tokens` | int? | Tokens en sortie |

---

## Attributs OTel `gen_ai.*`

Attributs standards OpenTelemetry pour le monitoring LLM :

| Attribut | Exemple | Description |
|---|---|---|
| `gen_ai.request.model` | `med-extraction` | Modèle logique demandé |
| `gen_ai.response.model` | `ornith-1.5-9b-q5km` | Modèle réel utilisé |
| `gen_ai.usage.input_tokens` | 512 | Tokens en entrée |
| `gen_ai.usage.output_tokens` | 256 | Tokens en sortie |
| `gen_ai.system` | `ollama` | Runtime utilisé |

---

## Propagation `traceparent`

Le header `traceparent` (W3C Trace Context) est propagé de bout en bout :

```
Client → Caddy → Gateway → Runtime
```

Chaque service :
1. Extrait `traceparent` de la requête entrante
2. Crée un span enfant
3. Injecte `traceparent` dans la requête sortante

---

## Deux backends, un seul code

`07-applications/common/observability.py` (OTel SDK) est écrit **une fois**
et pointe vers `OTEL_EXPORTER_OTLP_ENDPOINT`.

Phoenix **et** Langfuse reçoivent le même flux OTLP (les deux acceptent l'ingest).

---

## Collecteur OTel (optionnel)

Le collecteur est un **fan-out** optionnel :
- Profil `otel` : `docker compose --profile otel up -d`
- Reçoit les spans, les distribue à Phoenix et Langfuse
- Permet de parler de fan-out sans le rendre obligatoire (§61.2)

---

## Non-régression (§42)

Le pipeline doit fonctionner **avec l'observabilité coupée** :
- Exporter en `none` ou `console`
- Les spans ne bloquent jamais le chemin critique
- Timeouts courts (1s) + failure callback silencieux

---

## Gouvernance

> **Les traces sont aussi un sujet de gouvernance.**

Le gateway masque le vrai modèle (`ornith-1.5-9b` → `med-extraction`).
Les traces montrent le modèle logique, pas le modèle réel.
C'est un choix de sécurité : les utilisateurs ne connaissent que l'alias.
