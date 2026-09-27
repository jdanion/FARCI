# FARCI — parcours Python

## Installation

```bash
cd 07-applications/python
pip install -r requirements.txt
```

## Utilisation

```bash
# Tous les PDF
python run_pipeline.py --input ../datasets/raw --output ../datasets/extracted/python

# Un seul PDF
python run_pipeline.py --input ../datasets/raw/patient_001.pdf

# Avec le prompt v2
python run_pipeline.py --input ../datasets/raw --prompt v2
```

## Tableau comparatif

```bash
python make_table.py --input ../datasets/extracted/python
```
