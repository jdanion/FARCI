# TUTORIAL — Équipe 4 : Documents cliniques et pseudonymisation

## Mission

Préparer les documents avant qu'un modèle ne les lise : **pseudonymiser**
(aucun identifiant direct ne part vers le modèle) et, pour les PDF, **convertir**
en texte structuré avec Docling.

- **Objectif minimal** : Docling répond (ligne `Docling` verte) et les tests de
  pseudonymisation passent.
- **Bonus** : convertir les PDF du dataset et comparer la sortie Docling au
  texte d'origine.

## Ce que votre service apporte

Le dataset de l'atelier est versionné en **texte** (`datasets/raw/*.txt`) :
c'est lui que lit le pipeline noté. Les PDF (`./bin/farci generate-dataset --pdf`,
écrits dans `datasets/pdf/`) servent à montrer ce que fait Docling sur un vrai
document mis en page.

La pseudonymisation est appelée par le pipeline de l'étape 2 sur chaque
dossier : IPP, NIR, nom, prénom et dates deviennent `[IPP_0]`, `[NOM_0]`…

## Ce que vous devez comprendre

- **Pseudonymiser n'est pas anonymiser** : la table de correspondance permet de
  revenir en arrière, et les quasi-identifiants (âge, sexe, dates) peuvent
  suffire à ré-identifier un patient.
- **Un dictionnaire de noms ne suffit jamais** : on remplace aussi tout ce qui
  suit une étiquette explicite (« Patient : »).
- **Dépendance partielle** : si Docling tombe (scénario 05), le parcours texte
  continue.

## Vos dépendances

Le réseau (équipe 1). Le pipeline de l'étape 2 dépend de vous.

## Votre IP

Docling : `DOCLING_IP`, port `DOCLING_PORT`. Les applications passent par
Caddy : `/docling`.

## Installation

Image `docling` (variante CPU) préchargée : `./bin/farci verify-images`.

## Configuration

- `04-clinical-documents/docling/docker-compose.yml` : OCR désactivé (CPU).
- `04-clinical-documents/deidentification/rules.py` : les règles, dans l'ordre
  dates, identifiants, contacts, adresses, noms.

## Démarrage

```bash
./bin/farci up 04-clinical-documents/docling
```

Pseudonymiser un document à la main :

```bash
PYTHONPATH=04-clinical-documents python3 -m deidentification.cli \
  datasets/raw/patient_1234567890123_cro.txt datasets/pseudonymized/patient_1234567890123_cro.txt
```

## Test local

```bash
04-clinical-documents/docling/smoke.sh
./bin/farci test-unit -k deidentification
```

## Test contractuel

```bash
./bin/farci test
```

Ligne `docling` : `PASS` si un PDF existe, sinon `SKIP` (générer les PDF avec
`./bin/farci generate-dataset --pdf`).

## Vérification sur le tableau de bord

Ligne `Docling` verte.

## Commit

Les règles de pseudonymisation et leurs tests. Jamais de fichier de
correspondance (`mapping.json`) : il permet de ré-identifier.

## Pull Request

Montrer un document avant et après pseudonymisation, et la sortie de
`./bin/farci test-unit -k deidentification`.

## Définition de DONE

```text
[ ] Docling démarré
[ ] ligne Docling verte
[ ] tests de pseudonymisation verts (aucune fuite sur les 80 documents)
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| Docling met plusieurs minutes à démarrer | chargement des modèles de mise en page | patienter, `./bin/farci logs 04-clinical-documents/docling` |
| `ModuleNotFoundError: deidentification` | lancé sans `PYTHONPATH` | reprendre la commande ci-dessus depuis la racine |
| un nom reste en clair | absent du dictionnaire et sans étiquette | ajouter la règle dans `rules.py` et un cas dans `tests/test_deidentification.py` |
