"""FARCI — client OpenAI-compatible pointé sur Caddy.

Utilise le SDK OpenAI mais pointe vers la gateway FARCI via Caddy.
"""

from __future__ import annotations

import os

from openai import OpenAI


def get_client() -> OpenAI:
    """Retourne un client OpenAI configuré pour FARCI."""
    return OpenAI(
        api_key=os.environ.get("FARCI_API_KEY", "sk-standard-placeholder"),
        base_url=os.environ.get("FARCI_GATEWAY_URL", "http://192.168.50.15/v1"),
    )


def chat_completion(
    messages: list[dict],
    model: str = "med-extraction",
    temperature: float = 0,
    max_tokens: int = 4096,
) -> str:
    """Appelle la gateway et retourne le contenu texte."""
    client = get_client()
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens,
    )
    return response.choices[0].message.content or ""
