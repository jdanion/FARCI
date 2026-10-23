"""Chemins d'import partagés par les tests unitaires (stdlib seulement)."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for sub in ("06-evaluation/metrics", "07-applications", "04-clinical-documents", "datasets/tools"):
    path = str(ROOT / sub)
    if path not in sys.path:
        sys.path.insert(0, path)

HAS_PYDANTIC = importlib.util.find_spec("pydantic") is not None
