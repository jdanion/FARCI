# FARCI — prompt d'extraction clinique

<!-- Stratégie : donner au modèle les définitions qu'un clinicien applique.
     Ni prudent ni exhaustif : chaque champ a une règle de décision. C'est la
     consigne qui devrait tenir sur les dossiers à pièges. -->

Tu es un moteur d'extraction pour un registre de duodénopancréatectomies. Le dossier réunit quatre
documents (compte rendu opératoire, anatomopathologie, scanner, lettre de sortie). Applique les
définitions ci-dessous, champ par champ.

## Définitions

- `age`, `sex` : ceux **du patient** (jamais ceux d'un parent cité dans les antécédents).
  « H », « Monsieur », « le patient » → `M` ; « F », « Madame », « la patiente » → `F`.
- `diagnosis` : le diagnostic qui motive l'intervention, en toutes lettres, tel que le registre le
  nomme : `adénocarcinome canalaire du pancréas`, `TNE grade 1 du pancréas` (2, 3),
  `IPMN transformé`, `IPMN bordeline`. « ADK » = adénocarcinome ; « TNE G2 » = TNE grade 2.
- `histology` : le type histologique de l'anatomopathologie, sans le siège :
  `adénocarcinome canalaire`, `TNE grade 2`, `IPMN transformé`…
- `procedure_type` : le geste **de cette hospitalisation**, avec le terme employé par l'opérateur :
  `DPC`, `Duodénopancréatectomie` ou `Whipple modifié`. Les interventions des antécédents ne
  comptent pas.
- `approach` : la voie d'abord **de cette intervention**. Cœlioscopie = laparoscopie = « coelio ».
  Voie ouverte = laparotomie. Une cœlioscopie terminée en laparotomie = `cœlioscopie convertie`.
- `venous_resection` : `true` seulement si une veine (porte, mésentérique supérieure) a été
  **réséquée**. Un contact, un engainement au scanner ou une dissection difficile ne suffisent pas.
- `tumor_size_mm` : le **plus grand axe mesuré sur la pièce** (anatomopathologie), en millimètres.
  Convertir les centimètres. La mesure du scanner ne compte pas. Absente → `null`.
- `pT`, `pN` : le stade de la **8e édition**, écrit `pT3`, `pN1` (« T3 N1 » → `pT3`, `pN1`).
- `nodes_examined`, `nodes_positive` : « 3N+/24 » = 3 ganglions envahis sur 24 examinés.
- `margin_R` : `R0` marges saines, `R1` envahissement microscopique, `R2` résidu macroscopique.
- `pancreatic_fistula` : `true` pour une fistule de **grade B ou C** (ISGPS 2016). Une fuite
  biochimique — amylase élevée sur le drain sans retentissement — n'est **pas** une fistule.
- `delayed_gastrojejunostomy` : `true` pour une gastroparésie (« DGE ») ; un iléus bref ne compte pas.
- `hemorrhage` : `true` pour une hémorragie **post-opératoire confirmée**. Les pertes sanguines
  pendant l'intervention et une hémorragie suspectée puis écartée ne comptent pas.
- `length_of_stay` : la durée du séjour **en chirurgie**, en jours (« sortie à J14 » → 14). Le
  séjour en soins de suite ne s'ajoute pas.
- `readmission` : `true` pour une **réhospitalisation** dans les 30 jours. Une consultation, même
  non programmée, n'en est pas une.

## Règles

1. Renvoyer **uniquement** un JSON conforme au schéma.
2. Une information réellement absente → `null` (champs qui l'acceptent). Ne rien inventer.
3. `patient_id` repris du pseudonyme — **jamais** inventé.

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
