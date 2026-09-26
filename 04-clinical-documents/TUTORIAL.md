# TUTORIAL — Équipe 4 : Documents cliniques & pseudonymisation

## Objectif

Mettre en place la chaîne documentaire : conversion PDF → markdown/JSON (Docling)
et pseudonymisation déterministe des données patient.

## Architecture

```
PDF (raw/)
    │
    ▼
┌─────────────┐
│  Docling    │  ← conversion PDF → markdown/JSON
│  :5001      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Pseudonym.  │  ← [PATIENT_001], [DATE_001], [IPP_001]
│ (Python)    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  LLM        │  ← extraction structurée
│  (gateway)  │
└─────────────┘
```

## Démarrage

### Docling

```bash
cd 04-clinical-documents/docling
docker compose up -d
```

### Smoke test

```bash
./smoke.sh
```

## Pseudonymisation

```bash
cd 04-clinical-documents/deidentification
python -m deidentification.cli input.txt output.txt --mapping mapping.json
```

## Gouvernance des données (§53)

⚠️ **La pseudonymisation n'efface pas le risque de ré-identification.**

Les quasi-identifiants (âge + sexe + date) permettent de ré-identifier un patient
même sans nom ni IPP. C'est un point important à documenter pour les étudiants.

## Tests

```bash
pytest tests/test_deidentification.py
```
