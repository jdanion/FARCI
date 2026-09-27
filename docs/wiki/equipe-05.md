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
cd 05-observability/phoenix
docker compose up -d

# 2. Démarrer Langfuse
cd ../langfuse
cp .env.example .env
docker compose up -d

# 3. Tester
./tests/test_observability.sh
```

## Solution from scratch

### 1. Démarrer Phoenix

```bash
docker run -d \
  --name farci-phoenix \
  --network farci \
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
  --network farci \
  -p 3000:3000 \
  -e DATABASE_URL=postgresql://langfuse:langfuse@farci-langfuse-postgres:5432/langfuse \
  -e NEXTAUTH_SECRET=changeme \
  -e NEXTAUTH_URL=http://192.168.50.52:3000 \
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
