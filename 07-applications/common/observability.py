"""FARCI — instrumentation OpenTelemetry du client (contrat : 05-observability/CONTRACT.md).

Écrite UNE fois, elle envoie les spans en OTLP/HTTP vers
OTEL_EXPORTER_OTLP_ENDPOINT (dérivée de config/network.env : Phoenix par
défaut). Phoenix et Langfuse consomment le même flux.

Règle non négociable (ARCHITECTURE §7, scénario 07) : l'observabilité est sur
le chemin d'OBSERVATION, jamais sur le chemin de production.
  - si le SDK OpenTelemetry n'est pas installé : aucun span, aucun échec ;
  - si l'endpoint est absent ou injoignable : export abandonné après 1 s,
    en arrière-plan (BatchSpanProcessor), sans lever d'exception ;
  - FARCI_TRACE=off coupe tout.
"""

from __future__ import annotations

import os
import time
from contextlib import contextmanager

_TRACER = None
_READY = False


def _setup():
    """Construit le traceur au premier appel ; None si l'observabilité est coupée."""
    global _TRACER, _READY
    if _READY:
        return _TRACER
    _READY = True
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "").strip()
    if os.environ.get("FARCI_TRACE", "on") == "off" or not endpoint:
        return None
    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
    except ImportError:
        return None
    resource = Resource.create({
        "service.name": os.environ.get("OTEL_SERVICE_NAME", "farci-app"),
        "service.namespace": os.environ.get("OTEL_SERVICE_NAMESPACE", "farci"),
    })
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=endpoint, timeout=1)
    provider.add_span_processor(BatchSpanProcessor(exporter, export_timeout_millis=1000))
    trace.set_tracer_provider(provider)
    _TRACER = trace.get_tracer("farci")
    return _TRACER


@contextmanager
def llm_span(model: str, operation: str = "chat.completion"):
    """Span d'un appel LLM. Rend un dict où l'appelant range ce qu'il apprend
    de la réponse (modèle réel, tokens) ; les attributs suivent CONTRACT.md."""
    tracer = _setup()
    facts: dict = {}
    started = time.monotonic()
    if tracer is None:
        yield facts
        return
    with tracer.start_as_current_span(operation) as span:
        span.set_attribute("gen_ai.request.model", model)
        span.set_attribute("operation", operation)
        try:
            yield facts
        except Exception as exc:
            span.set_attribute("status", "error")
            span.set_attribute("error", f"{type(exc).__name__}: {exc}")
            raise
        else:
            span.set_attribute("status", "ok")
        finally:
            span.set_attribute("latency", round((time.monotonic() - started) * 1000))
            for key in ("gen_ai.response.model", "gen_ai.usage.input_tokens",
                        "gen_ai.usage.output_tokens"):
                if facts.get(key) is not None:
                    span.set_attribute(key, facts[key])
