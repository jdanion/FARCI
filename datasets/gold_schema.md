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

## Les règles qui tranchent

Le gold n'est pas « ce qui est écrit dans le document » : c'est ce qu'un
clinicien **retient** pour le registre. Chaque règle ci-dessous tranche un cas
où le texte peut se lire de deux façons. Les dossiers à pièges
(`datasets/README.md`) sont construits sur ces règles ; la consigne
`extraction_clinique.md` les donne au modèle.

| Champ | Règle | Le piège dans les documents |
|---|---|---|
| `age`, `sex` | ceux du patient | l'âge d'un parent dans les antécédents ; le sexe à déduire de « Madame », « la patiente », « H 71 a. » |
| `diagnosis` | le diagnostic qui motive le geste, libellé du registre | « ADK canalaire pancréas », « TNE G2 pancréas » ; le cancer d'un parent |
| `histology` | le type histologique, sans le siège | idem, en abrégé |
| `procedure_type` | le terme de l'opérateur : `DPC`, `Duodénopancréatectomie`, `Whipple modifié` | une cholécystectomie ou une appendicectomie des antécédents |
| `approach` | la voie de **cette** intervention ; une cœlioscopie terminée en laparotomie est `cœlioscopie convertie` | l'antécédent opéré par l'autre voie ; « laparoscopie », « coelio », « voie ouverte » |
| `venous_resection` | une veine a été réséquée | contact ou engainement au scanner, dissection laborieuse « sans résection » |
| `tumor_size_mm` | plus grand axe **sur la pièce**, en mm | la mesure du scanner (toujours différente) ; « 3,1 cm » ; « 17 x 23 x 14 mm » ; kyste, nodule ou micronodule d'un autre organe |
| `pT`, `pN` | 8e édition, écrits `pT3`, `pN1` | « T3 N1 », « pT3N1 » ; le stade de la 7e édition cité entre parenthèses |
| `nodes_examined`, `nodes_positive` | nombres du curage | « 3N+/24 » ; « deux métastatiques » ; « indemnes » = 0, pas `null` |
| `margin_R` | `R0`, `R1`, `R2` | « tissu sain », « envahie microscopiquement », « résidu macroscopique » |
| `pancreatic_fistula` | grade B ou C (ISGPS 2016) | la **fuite biochimique** : amylase élevée sur le drain, sans retentissement → `false` |
| `delayed_gastrojejunostomy` | gastroparésie | « DGE », « SNG jusqu'à J9 » ; un iléus bref → `false` |
| `hemorrhage` | hémorragie post-opératoire confirmée | pertes sanguines peropératoires ; hémorragie « suspectée, écartée par l'angioscanner » |
| `length_of_stay` | jours en chirurgie | « sortie à J14 », « quatorze jours » ; le séjour en soins de suite ne s'ajoute pas |
| `readmission` | réhospitalisation dans les 30 jours | une consultation non programmée avec retour à domicile → `false` |

On peut ne pas être d'accord avec une règle : c'est une discussion clinique,
et elle se tranche par une demande de fusion sur ce fichier, pas en changeant
le score.

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
