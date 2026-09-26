# FARCI — Gold Standard

Le gold standard est la **référence absolue** pour l'évaluation.
Il est généré **directement depuis le registre** (`datasets/tools/cases.py`),
jamais via un LLM.

## Fichiers

- `patient_XXX.json` — un fichier par patient
- `validate_gold.py` — validation de l'intégrité

## Règles

1. **Déterministe** : même graine → mêmes fichiers
2. **Source de vérité** : le registre Python, pas le LLM
3. **null ≠ 0** : `null` = absent, `0` = valeur réelle

## Validation

```bash
python 06-evaluation/gold-standard/validate_gold.py
```
