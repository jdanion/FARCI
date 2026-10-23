# Équipe 7 — Applications (Python, Open WebUI, Flowise)

## Attendus pédagogiques

- Comprendre le rôle d'une application cliente
- Comprendre pourquoi l'application ne voit jamais le vrai modèle
- Comprendre la notion de contrat commun (même schéma, même dataset, même alias)
- Comprendre la différence entre les trois parcours (Python, Open WebUI, Flowise)
- Savoir valider une sortie JSON avec Pydantic

## Solution simple (scripts)

```bash
# Parcours A — Python (principal)
pip install --no-index --find-links offline/wheels -r requirements.txt
./bin/farci extract --subset quick --run python
./bin/farci evaluate --subset quick

# Parcours B — Open WebUI
./bin/farci up 07-applications/open-webui
07-applications/open-webui/post-setup.sh

# Parcours C — Flowise : démonstration du formateur
./bin/farci up 07-applications/flowise
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### Parcours A — Python

```python
# Depuis la racine du dépôt, après « source scripts/dev-env.sh && farci_load_env » :
#   PYTHONPATH=07-applications python3
from pathlib import Path

from common.farci_client import chat_completion
from common.pipeline import run

bilan = run(
    raw_dir=Path("datasets/raw"),
    output_dir=Path("datasets/extracted/python"),
    complete=lambda messages, model: chat_completion(messages, model=model),
    model="med-extraction",
    prompt_version="v1",
)
print(bilan)   # {'ecrits': ..., 'rejetes': ..., 'erreurs': ...}
```

### Parcours B — Open WebUI

```bash
docker run -d \
  --name farci-open-webui \
  -p 8080:8080 \
  -e OPENAI_API_BASE_URL=$FARCI_GATEWAY_URL \
  -e DEFAULT_MODEL=med-extraction \
  -v open-webui-data:/app/backend/data \
  ghcr.io/open-webui/open-webui:0.11.4
```

### Parcours C — Flowise

```bash
docker run -d \
  --name farci-flowise \
  -p 3000:3000 \
  -e FLOWISE_USERNAME=admin \
  -e FLOWISE_PASSWORD=farci-admin \
  -v flowise-data:/root/.flowise \
  flowiseai/flowise:3.1.4
```

### Validation Pydantic

```python
from common.schemas import ClinicalExtraction

# Valide un JSON
data = {"patient_id": "123", "age": 67, ...}
extraction = ClinicalExtraction(**data)

# JSON invalide → ValidationError
try:
    ClinicalExtraction(**{"patient_id": "123"})  # champs manquants
except ValidationError as e:
    print(f"Validation échouée: {e}")
```

## Vérifications

- [ ] Les 3 parcours produisent le même schéma
- [ ] `make evaluate` compare les 3 parcours
- [ ] Aucun fichier invalide n'est écrit
