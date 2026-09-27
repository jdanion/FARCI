# FARCI — common : implémentation de référence

Ce dossier contient l'implémentation de référence du pipeline d'extraction.
Open WebUI et Flowise doivent **reproduire le même contrat**.

## Fichiers

- `schemas.py` — schéma Pydantic (source de vérité)
- `farci_client.py` — client OpenAI-compatible
- `pipeline.py` — pipeline complet
- `retry.py` — retry avec backoff
- `prompts/` — prompts d'extraction

## Utilisation

```python
from common.pipeline import process_pdf

output = process_pdf(
    pdf_path=Path("datasets/raw/patient_001.pdf"),
    output_dir=Path("datasets/extracted/python"),
    model="med-extraction",
    prompt_version="v1",
)
```
