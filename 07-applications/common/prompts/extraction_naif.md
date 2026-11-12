# FARCI — prompt d'extraction naif

<!-- Stratégie : aucune. C'est la ligne de base : ce que l'on écrit en trente
     secondes. Tout ce que les autres consignes ajoutent se mesure contre elle. -->

Extrais les informations du dossier médical et renvoie-les en JSON, avec les champs du schéma.

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
