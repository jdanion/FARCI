# Équipe 4 — Documents cliniques (Docling, pseudonymisation)

## Attendus pédagogiques

- Comprendre le rôle d'un convertisseur de documents (PDF → markdown/JSON)
- Comprendre la notion de pseudonymisation et son importance médicale
- Comprendre la différence entre `null` et `0` dans un schéma
- Comprendre pourquoi la pseudonymisation n'efface pas le risque de ré-identification
- Savoir utiliser le schéma JSON Schema comme contrat

## Solution simple (scripts)

```bash
# 1. Démarrer Docling et le tester
./bin/farci up 04-clinical-documents/docling
04-clinical-documents/docling/smoke.sh

# 2. Pseudonymiser un document du dataset
PYTHONPATH=04-clinical-documents python3 -m deidentification.cli \
  datasets/raw/patient_1234567890123_cro.txt datasets/pseudonymized/patient_1234567890123_cro.txt

# 3. Vérifier : aucune fuite d'identifiant sur les 80 documents
./bin/farci test-unit -k deidentification
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Démarrer Docling

```bash
docker run -d \
  --name farci-docling \
  --network farci \
  -p 5001:5001 \
  -e DOCLING_DO_OCR=false \
  -e DOCLING_DO_TABLE_STRUCTURE=true \
  -v docling-cache:/root/.cache \
  ghcr.io/docling-project/docling-serve-cpu:v1.35.0
```

### 2. Convertir un PDF

```bash
curl -X POST $DOCLING_URL/v1/convert/file \
  -F "files=@document.pdf" \
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
