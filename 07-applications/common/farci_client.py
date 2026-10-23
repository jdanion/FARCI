"""FARCI — client OpenAI-compatible pointé sur Caddy.

Utilise le SDK OpenAI, pointé vers la passerelle FARCI via Caddy. C'est la
démonstration du message 4 : une API standard, une seule URL à changer.

Si le SDK `openai` n'est pas installé (poste mal équipé, runner de CI), le
même appel est fait en Python standard (urllib) : même requête, même
contrat, aucune dépendance. Le SDK reste la voie enseignée.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

from .observability import llm_span

try:
    from openai import OpenAI
except ImportError:  # repli stdlib, voir la docstring
    OpenAI = None

TIMEOUT = float(os.environ.get("FARCI_LLM_TIMEOUT", "300"))


def gateway_url() -> str:
    """URL de la passerelle, derrière Caddy.

    Aucune adresse par défaut : FARCI_GATEWAY_URL est dérivée de
    config/network.env par scripts/dev-env.sh (./bin/farci la fournit).
    """
    url = os.environ.get("FARCI_GATEWAY_URL", "").strip()
    if not url:
        raise SystemExit(
            "FARCI_GATEWAY_URL absente : lancer via ./bin/farci, ou "
            "« source scripts/dev-env.sh && farci_load_env » (config/network.env)"
        )
    return url.rstrip("/")


def api_key() -> str:
    return os.environ.get("FARCI_API_KEY") or os.environ.get("GATEWAY_KEY_STANDARD", "")


def get_client():
    """Retourne un client OpenAI configuré pour FARCI."""
    if OpenAI is None:
        raise RuntimeError("SDK openai absent : pip install -r requirements.txt")
    return OpenAI(api_key=api_key() or "farci", base_url=gateway_url(), timeout=TIMEOUT)


def _post_chat(payload: dict) -> dict:
    """POST /chat/completions en Python standard (repli sans SDK)."""
    request = urllib.request.Request(
        gateway_url() + "/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key()}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"passerelle : HTTP {exc.code} {exc.read()[:200]!r}") from exc


def chat_completion(
    messages: list[dict],
    model: str = "med-extraction",
    temperature: float = 0,
    max_tokens: int = 4096,
) -> str:
    """Appelle la gateway et retourne le contenu texte (jamais reasoning_content)."""
    with llm_span(model) as facts:
        if OpenAI is not None:
            response = get_client().chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            facts["gen_ai.response.model"] = response.model
            if response.usage:
                facts["gen_ai.usage.input_tokens"] = response.usage.prompt_tokens
                facts["gen_ai.usage.output_tokens"] = response.usage.completion_tokens
            return response.choices[0].message.content or ""
        data = _post_chat({"model": model, "messages": messages,
                           "temperature": temperature, "max_tokens": max_tokens})
        usage = data.get("usage") or {}
        facts["gen_ai.response.model"] = data.get("model")
        facts["gen_ai.usage.input_tokens"] = usage.get("prompt_tokens")
        facts["gen_ai.usage.output_tokens"] = usage.get("completion_tokens")
        return data["choices"][0]["message"].get("content") or ""
