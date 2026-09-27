# FARCI — Schéma d'extraction clinique

Ce schéma JSON Schema est la **source de vérité** pour l'extraction clinique.
Il est utilisé par :
- Pydantic (validation Python)
- Le prompt LLM (JSON Schema natif)
- Flowise (template de validation)
- Le gold standard (comparaison)

## Règle fondamentale : `null` ≠ `0`

| Valeur | Signification |
|---|---|
| `0` | **Valeur réelle** : « aucun ganglion envahi » |
| `null` | **Information absente** : « non précisé dans le dossier » |

## Fichiers

- `clinical_extraction.schema.json` — schéma JSON Schema (source de vérité)
- `datasets/schemas/clinical_extraction.schema.json` — copie pour le dataset

## Utilisation

### Pydantic

```python
from pydantic import BaseModel

class ClinicalExtraction(BaseModel):
    patient_id: str
    age: int
    sex: str
    # ...
```

### JSON Schema (envoyé au LLM)

```json
{
  "type": "object",
  "properties": {
    "patient_id": {"type": "string"},
    ...
  }
}
```

### Flowise

Le schéma est utilisé dans le nœud de validation pour rejeter les JSON non conformes.
