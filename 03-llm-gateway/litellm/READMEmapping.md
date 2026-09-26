# FARCI — Mapping LiteLLM → termes FARCI

| Concept LiteLLM | Terme FARCI | Signification |
|---|---|---|
| `model_name` | Alias logique | Nom masqué (`med-extraction`) |
| `api_base` | Runtime URL | URL du runtime Ollama/llama.cpp |
| `master_key` | Clé formateur | Clé prioritaire (120 RPM) |
| `rpm_limit` | Rate limit | Requêtes par minute |
| `fallbacks` | Bascule | Secondaire si primaire KO |
| `callbacks` | Observabilité | Langfuse/Phoenix |
| `drop_params` | Tolérance | Ignorer params inconnus |
| `routing_strategy` | Stratégie | `least-busy` par défaut |
