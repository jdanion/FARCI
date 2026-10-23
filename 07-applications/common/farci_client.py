"""FARCI — client OpenAI-compatible pointé sur Caddy.

Utilise le SDK OpenAI mais pointe vers la gateway FARCI via Caddy.
"""

from __future__ import annotations

import os

from openai import OpenAI

from .observability import llm_span


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
    return url


def get_client() -> OpenAI:
    """Retourne un client OpenAI configuré pour FARCI."""
    return OpenAI(
        api_key=os.environ.get("FARCI_API_KEY") or os.environ.get("GATEWAY_KEY_STANDARD", ""),
        base_url=gateway_url(),
    )


def chat_completion(
    messages: list[dict],
    model: str = "med-extraction",
    temperature: float = 0,
    max_tokens: int = 4096,
) -> str:
    """Appelle la gateway et retourne le contenu texte (jamais reasoning_content)."""
    client = get_client()
    with llm_span(model) as facts:
        response = client.chat.completions.create(
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
