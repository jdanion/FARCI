# Équipe 5 — Observabilité (Phoenix, Langfuse, OTel)

## Attendus pédagogiques

- Comprendre ce qu'est OpenTelemetry (OTel) et pourquoi c'est un standard
- Comprendre la notion de trace, span, et attribut
- Comprendre la différence entre un collecteur et un backend
- Comprendre pourquoi l'observabilité ne doit jamais bloquer le chemin critique
- Savoir propager le header `traceparent`

## Solution simple (scripts)

```bash
# 1. Démarrer Phoenix
./bin/farci up 05-observability/phoenix

# 2. Vérifier : ligne Observability verte, test observability PASS
./bin/farci status
./bin/farci test

# 3. Bonus : Langfuse sur le même flux OTLP
./bin/farci up 05-observability/langfuse
05-observability/langfuse/bootstrap.sh
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Démarrer Phoenix

```bash
docker run -d \
  --name farci-phoenix \
  -p 6006:6006 \
  -p 4317:4317 \
  -e PHOENIX_WORKING_DIR=/phoenix \
  -v phoenix-data:/phoenix \
  arizephoenix/phoenix:20.16.0
```

### 2. Démarrer Langfuse

```bash
docker run -d \
  --name farci-langfuse \
  -p 3000:3000 \
  -e DATABASE_URL=postgresql://langfuse:langfuse@farci-langfuse-postgres:5432/langfuse \
  -e NEXTAUTH_SECRET=changeme \
  -e NEXTAUTH_URL=$LANGFUSE_URL \
  -e LANGFUSE_ENABLE_EXPERIMENTAL_OTEL=true \
  langfuse/langfuse:4.46.0
```

### 3. Instrumenter une application

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("chat.completion") as span:
    span.set_attribute("gen_ai.request.model", "med-extraction")
    span.set_attribute("gen_ai.system", "ollama")
    # ... appel LLM ...
```

### 4. Propager traceparent

```python
from opentelemetry.propagate import inject

headers = {}
inject(headers)
# headers contient maintenant 'traceparent'
```

### 5. Non-régression

```python
# L'observabilité ne doit jamais bloquer le chemin critique
import os
os.environ["OTEL_TRACES_EXPORTER"] = "none"
# → les spans sont ignorés, le pipeline continue
```

## Vérifications

- [ ] Phoenix répond sur :6006
- [ ] Langfuse répond sur :3000
- [ ] Traces visibles avec gen_ai.request.model
- [ ] Pipeline fonctionne avec observabilité coupée
