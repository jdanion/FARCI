# Équipe 4 — Documents cliniques (Docling, pseudonymisation)

## Attendus pédagogiques

- Comprendre le rôle d'un convertisseur de documents (PDF → markdown/JSON)
- Comprendre la notion de pseudonymisation et son importance médicale
- Comprendre la différence entre `null` et `0` dans un schéma
- Comprendre pourquoi la pseudonymisation n'efface pas le risque de ré-identification
- Savoir utiliser le schéma JSON Schema comme contrat

## Solution simple (scripts)

```bash
# 1. Démarrer Docling
cd 04-clinical-documents/docling
docker compose up -d

# 2. Smoke test
./smoke.sh

# 3. Pseudonymiser un document
cd ../deidentification
python -m deidentification.cli input.txt output.txt --mapping mapping.json
```

## Solution from scratch

### 1. Démarrer Docling

```bash
docker run -d \
  --name farci-docling \
  --network farci \
  -p 5001:5001 \
  -e DOCLING_DO_OCR=false \
  -e DOCLING_DO_TABLE_STRUCTURE=true \
  -v docling-cache:/root/.cache \
  ds4sd/docling-serve:0.5.1
```

### 2. Convertir un PDF

```bash
curl -X POST http://192.168.50.40:5001/v1/convert/file \
  -F "file=@document.pdf" \
  -F "to_formats=md,json" \
  -F "do_ocr=false" \
  -F "do_table_structure=true"
```

### 3. Pseudonymiser un texte

```python
from deidentification.rules import pseudonymize_text
from deidentification.mapping import MappingStore

mapping = MappingStore()
text = "Patient Jean Dupont, IPP 1234567890123, né le 15/03/1958"
result = pseudonymize_text(text, mapping)
print(result)
# → "Patient [PRENOM_0] [NOM_0], IPP [IPP_0], né le [DATE_0]"
```

### 4. Comprendre la règle null vs 0

```python
# null = information absente
{"nodes_positive": null}  # → pas de ganglions examinés

# 0 = valeur réelle
{"nodes_positive": 0}  # → ganglions examinés, aucun envahi
```

### 5. Gouvernance des données

La pseudonymisation n'efface pas le risque de ré-identification par
quasi-identifiants (âge + sexe + date). C'est un point important à documenter.

## Vérifications

- [ ] Docling répond sur :5001
- [ ] Conversion PDF → markdown/JSON fonctionnelle
- [ ] Pseudonymisation déterministe
- [ ] Mapping réversible
