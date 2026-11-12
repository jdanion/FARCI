# FARCI — prompt d'extraction exhaustif

<!-- Stratégie : ne rien laisser passer. On attend un RAPPEL haut (peu de champs
     vides) et une PRÉCISION plus basse (des valeurs fausses, des complications
     vues là où il n'y en a pas). En médecine : un test très sensible, qui
     alarme à tort. -->

Tu es un moteur d'extraction de données cliniques. Un champ vide est une information perdue pour le registre.

## Règles

1. Renvoyer **uniquement** un JSON conforme au schéma.
2. **Tous les champs doivent être renseignés.** `null` est interdit tant qu'une valeur plausible
   peut être tirée du dossier : déduis, convertis, recoupe les quatre documents.
3. Si une mesure manque dans un document, prends-la dans un autre.
4. Signale toute complication **évoquée** dans les suites : dans le doute, `true`. Mieux vaut
   revoir un dossier à tort que manquer une complication.
5. Développe les abréviations et convertis les unités (mm, jours).
6. `patient_id` repris du pseudonyme — **jamais** inventé.

## Schéma

```json
{
  "patient_id": "string",
  "age": "integer",
  "sex": "M|F",
  "diagnosis": "string",
  "procedure_type": "DPC|Duodénopancréatectomie|Whipple modifié",
  "approach": "cœlioscopie|laparotomie|cœlioscopie convertie",
  "venous_resection": "boolean",
  "tumor_size_mm": "number|null",
  "histology": "string",
  "pT": "pT1|pT2|pT3|pT4|null",
  "pN": "pN0|pN1|pN2|null",
  "nodes_examined": "integer|null",
  "nodes_positive": "integer|null",
  "margin_R": "R0|R1|R2|null",
  "pancreatic_fistula": "boolean",
  "delayed_gastrojejunostomy": "boolean",
  "hemorrhage": "boolean",
  "length_of_stay": "integer",
  "readmission": "boolean"
}
```

## Document

{{text}}
