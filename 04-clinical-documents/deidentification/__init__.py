"""FARCI — pseudonymisation de documents cliniques.

Pseudonymisation déterministe : même entrée → même sortie.
Le mapping est sérialisé pour permettre la ré-identification contrôlée.
"""

from .rules import pseudonymize_text
from .mapping import MappingStore

__all__ = ["pseudonymize_text", "MappingStore"]
