"""FARCI — retry avec backoff et repair JSON."""

from __future__ import annotations

import json
import time
from typing import Callable


def retry_with_backoff(
    func: Callable,
    max_retries: int = 2,
    initial_delay: float = 1.0,
    backoff_factor: float = 2.0,
):
    """Exécute une fonction avec retry et backoff exponentiel."""
    delay = initial_delay
    last_exception = None

    for attempt in range(max_retries + 1):
        try:
            return func()
        except Exception as e:
            last_exception = e
            if attempt < max_retries:
                time.sleep(delay)
                delay *= backoff_factor

    raise last_exception


def repair_json(text: str) -> dict:
    """Tente de réparer un JSON malformé."""
    # Supprimer les balises ```json ... ```
    if "```json" in text:
        text = text.split("```json")[1].split("```")[0]
    elif "```" in text:
        text = text.split("```")[1].split("```")[0]

    # Supprimer les espaces et retours à la ligne
    text = text.strip()

    return json.loads(text)
