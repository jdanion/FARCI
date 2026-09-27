# TUTORIAL — Étape 2 : les trois applications

## Objectif

Mettre en place les trois parcours d'extraction :
- **A — Python** (recommandé)
- **B — Open WebUI**
- **C — Flowise**

## Contrat commun (FARCI §33)

- Même schéma, même dataset, même gateway, même alias `med-extraction`
- Chaque sortie → `datasets/extracted/<student>/<patient>.json`
- **Écrit seulement si Pydantic valide**

## Parcours A — Python

```bash
cd 07-applications/python
pip install -r requirements.txt
python run_pipeline.py --input ../datasets/raw --output ../datasets/extracted/python
```

## Parcours B — Open WebUI

```bash
cd 07-applications/open-webui
docker compose up -d
./post-setup.sh
```

## Parcours C — Flowise

```bash
cd 07-applications/flowise
docker compose up -d
```

## Évaluation

```bash
python 06-evaluation/metrics/evaluate.py --runs python webui flowise
```
