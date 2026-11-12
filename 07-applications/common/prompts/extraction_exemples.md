# FARCI — prompt d'extraction exemples

<!-- Stratégie : montrer plutôt qu'expliquer (« few-shot »). Aucune définition :
     un dossier fictif, écrit en abrégé, et la réponse attendue. Le dossier de
     l'exemple n'existe pas dans le jeu de données. -->

Tu es un moteur d'extraction de données cliniques. Renvoie **uniquement** un JSON conforme au
schéma, comme dans l'exemple. `patient_id` est repris du pseudonyme, jamais inventé.

## Exemple

Dossier :

```
CRO
Patient : [NOM_0]
IPP : [IPP_0]
H 64 a. - ADK canalaire pancréas. ATCD : cholécystectomie par laparotomie.
Geste : DPC. Voie : coelio puis conversion laparotomie.
Veine : contact VMS, libérée sans résection. Pertes 400 mL.
---
ANAPATH
ADK canalaire, 3,4 cm de grand axe. T3 N1 - 2N+/21. Marges : R1 (rétroporte).
---
TDM TAP
Masse tête pancréas 30 mm.
---
CRH - SORTIE
Amylase drain élevée à J3, fuite biochimique sans conséquence. DGE : 0.
Déglobulisation à J5, hémorragie écartée au scanner.
Sortie J12 puis soins de suite. Consultation à J20, pas de réhospitalisation.
```

Réponse :

```json
{
  "patient_id": "IPP_0",
  "age": 64,
  "sex": "M",
  "diagnosis": "adénocarcinome canalaire du pancréas",
  "procedure_type": "DPC",
  "approach": "cœlioscopie convertie",
  "venous_resection": false,
  "tumor_size_mm": 34,
  "histology": "adénocarcinome canalaire",
  "pT": "pT3",
  "pN": "pN1",
  "nodes_examined": 21,
  "nodes_positive": 2,
  "margin_R": "R1",
  "pancreatic_fistula": false,
  "delayed_gastrojejunostomy": false,
  "hemorrhage": false,
  "length_of_stay": 12,
  "readmission": false
}
```

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
