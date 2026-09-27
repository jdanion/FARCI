# FARCI — v1 vs v2 : ce qui a changé et pourquoi

## Changements

| Aspect | v1 | v2 | Pourquoi |
|---|---|---|---|
| Ordre d'extraction | Non spécifié | Par section du document | Réduit les oublis |
| Microstructure | Non spécifiée | Interdite si non demandée | Évite les hallucinations |
| Format strict | JSON simple | JSON Schema natif | Meilleure validation |

## F1 attendu

| Combinaison | F1 attendu |
|---|---|
| v1 + Ornith-1.5-9B | ~0.71 |
| v2 + Ornith-1.5-9B | ~0.79 |
| v2 + Qwen3.8-27B | ~0.88 |

*(valeurs illustratives)*

## Leçon

La **méthode** (prompt) compte autant que le **modèle**.
