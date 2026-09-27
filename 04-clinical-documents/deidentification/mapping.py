"""FARCI — store de mapping pour pseudonymisation.

Le mapping est sérialisé en JSON pour permettre :
- La ré-identification contrôlée (pseudonymes → valeurs originales)
- La réutilisation (même mapping pour plusieurs documents du même patient)
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional


class MappingStore:
    """Stocke les correspondances pseudonyme → valeur originale."""

    def __init__(self):
        self._mapping: dict[str, str] = {}
        self._counters: dict[str, int] = {}

    def get_counter(self, prefix: str) -> int:
        """Retourne le compteur courant pour un préfixe et l'incrémente."""
        count = self._counters.get(prefix, 0)
        self._counters[prefix] = count + 1
        return count

    def add(self, key: str, value: str):
        """Ajoute une entrée au mapping."""
        self._mapping[key] = value

    def get(self, key: str) -> Optional[str]:
        """Retrouve la valeur originale d'un pseudonyme."""
        return self._mapping.get(key)

    def to_dict(self) -> dict:
        """Exporte le mapping en dictionnaire."""
        return dict(self._mapping)

    def save(self, path: Path):
        """Sérialise le mapping en JSON."""
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self._mapping, f, ensure_ascii=False, indent=2)

    @classmethod
    def load(cls, path: Path) -> "MappingStore":
        """Charge un mapping depuis un fichier JSON."""
        store = cls()
        with open(path, "r", encoding="utf-8") as f:
            store._mapping = json.load(f)
        return store
