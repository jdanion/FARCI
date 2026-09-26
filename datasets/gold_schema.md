# FARCI — Gold Standard : règles de codage

Ce document définit les règles de codage du gold standard. Il est **la**
référence pour comprendre pourquoi un champ vaut `null` plutôt que `0`, ou
pourquoi une valeur est telle qu'elle est.

---

## Règle fondamentale : `null` ≠ `0`

| Valeur | Signification |
|---|---|
| `0` | **Valeur réelle** : « aucun ganglion envahi », « 0 mm » |
| `null` | **Information absente** : « non précisé dans le dossier » |

**Exemple** : un patient avec `nodes_positive: 0` a eu des ganglions
examinés, mais aucun n'était envahi. Un patient avec `nodes_positive: null`
n'a pas eu de ganglions examinés (ou ce n'est pas documenté).

---

## Variables et codage

### Identifiants
- `patient_id` : IPP factice, format `1234567890123` (13 chiffres)
- `nir` : NIR factice, format `1 23 45 6789 0123 456 78`

### Démographie
- `age` : en années, entier
- `sexe` : `"M"` ou `"F"`

### Diagnostic
- `diagnosis` : chaîne de caractères, ex: `"adénocarcinome canalaire du pancréas"`

### Intervention
- `procedure_type` : `"DPC"`, `"Duodénopancréatectomie"`, `"Whipple modifié"`
- `approach` : `"cœlioscopie"`, `"laparotomie"`, `"cœlioscopie convertie"`
- `venous_resection` : booléen

### Tumeur
- `tumor_size_mm` : en millimètres, nombre décimal, `null` si non précisé
- `histology` : chaîne de caractères

### Classification TNM
- `pT` : `"pT1"`, `"pT2"`, `"pT3"`, `"pT4"`, ou `null`
- `pN` : `"pN0"`, `"pN1"`, `"pN2"`, ou `null`

### Ganglions
- `nodes_examined` : entier, `null` si non précisé
- `nodes_positive` : entier (0 = aucun envahi), `null` si non précisé

### Marges
- `margin_R` : `"R0"`, `"R1"`, `"R2"`, ou `null`

### Complications
- `pancreatic_fistula` : booléen
- `delayed_gastrojejunostomy` : booléen
- `hemorrhage` : booléen

### Séjour
- `length_of_stay` : en jours, entier
- `readmission` : booléen (réadmission à 30 jours)

---

## Cohérence des données

Les cas sont générés de façon **cohérente** :
- Un `pT3` avec `pN2` a généralement une tumeur > 30 mm
- Une `pancreatic_fistula` allonge le `length_of_stay`
- Un `pT4` avec `margin_R: R1` ou `R2` est fréquent
- Un `delayed_gastrojejunostomy` s'accompagne souvent d'une fistule

Cette cohérence est vérifiée par le générateur et permet de détecter
les erreurs d'extraction (un LLM qui « devine » une valeur incohérente
est détecté).

---

## Utilisation

```bash
# Générer le gold standard (20 cas)
python datasets/tools/build_gold.py

# Générer le quick set (10 cas)
python datasets/tools/build_gold.py --quick

# Vérifier l'intégrité
python datasets/tools/build_gold.py --check
```
