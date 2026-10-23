# TUTORIAL — Équipe 4 : Documents cliniques et pseudonymisation

## Mission

Préparer les documents avant qu'un modèle ne les lise : **pseudonymiser**
(aucun identifiant direct ne part vers le modèle) et, pour les PDF, **convertir**
en texte structuré avec Docling. Et servir à la salle **EDS-NLP**, la
bibliothèque de TAL clinique de l'AP-HP : son pseudonymiseur (EDS-Pseudo) et
son extraction d'entités par LLM (`eds.llm_markup_extractor`).

- **Objectif minimal** : Docling répond (ligne `Documents` verte), le service
  EDS-NLP répond (ligne `EDS-NLP` verte) et les tests de pseudonymisation
  passent.
- **Bonus** : convertir les PDF du dataset et comparer la sortie Docling au
  texte d'origine ; comparer les deux pseudonymiseurs (le nôtre et EDS-Pseudo).

## Ce que votre service apporte

Le dataset de l'atelier est versionné en **texte** (`datasets/raw/*.txt`) :
c'est lui que lit le pipeline noté. Les PDF (`./bin/farci generate-dataset --pdf`,
écrits dans `datasets/pdf/`) servent à montrer ce que fait Docling sur un vrai
document mis en page.

La pseudonymisation est appelée par le pipeline de l'étape 2 sur chaque
dossier : IPP, NIR, nom, prénom et dates deviennent `[IPP_0]`, `[NOM_0]`…

Le service EDS-NLP (`04-clinical-documents/eds-nlp/`, contrat dans
`docs/CONTRACTS.md`) offre deux points d'entrée, joints par l'accueil de la
salle (`/eds`) :

- `POST /v1/pseudonymiser` : EDS-Pseudo, **règles + contexte patient** (le
  nom, l'IPP, le NIR que le dossier informatisé connaît déjà) ;
- `POST /v1/entites` : pseudonymise, puis demande au LLM de la salle de
  **recopier le texte en balisant** `<diagnostic>`, `<intervention>`,
  `<complication>`, `<stade>` ; EDS-NLP réaligne les balises sur le texte.

À l'étape 2, toute la salle compare cette extraction d'**entités** à
l'extraction en **JSON** du parcours Python : `./bin/farci eds compare`.

## Ce que vous devez comprendre

- **Pseudonymiser n'est pas anonymiser** : la table de correspondance permet de
  revenir en arrière, et les quasi-identifiants (âge, sexe, dates) peuvent
  suffire à ré-identifier un patient.
- **Un dictionnaire de noms ne suffit jamais** : on remplace aussi tout ce qui
  suit une étiquette explicite (« Patient : »).
- **Dépendance partielle** : si Docling tombe (scénario 05), le parcours texte
  continue. EDS-NLP est hors de `CLINICAL PIPELINE READY` pour la même raison.
- **Le contexte change tout** : sans données du patient, les règles d'EDS-Pseudo
  ne trouvent sur nos dossiers que la date de naissance ; avec, nom, prénom,
  IPP et NIR (`./bin/farci eds pseudo <fichier> --sans-contexte`).
- **Entités ou JSON ?** Une entité est un morceau du texte, à sa place ; une
  variable JSON est une valeur déduite. Une complication balisée dans
  « Fistule pancréatique : Non » est une **négation manquée**.

## Vos dépendances

Le réseau (équipe 1). Le pipeline de l'étape 2 dépend de vous.

## Votre IP

Docling : `DOCLING_IP`, port `DOCLING_PORT`. EDS-NLP : `EDS_NLP_IP`, port
`EDS_NLP_PORT`. Les applications passent par l'accueil : `/docling`, `/eds`.
`./bin/farci room set 4 <ip>` déclare les deux.

## Installation

Images `docling` (variante CPU) et `farci/eds-nlp` préchargées :
`./bin/farci verify-images`. L'image EDS-NLP est **construite** au
préchargement (`./preload.sh --only build_eds_nlp`) pour l'architecture de la
machine : sur un Mac Apple Silicon, utiliser celle construite sur le Pi
(même architecture arm64).

## Configuration

- `04-clinical-documents/docling/docker-compose.yml` : OCR désactivé (CPU).
- `04-clinical-documents/deidentification/rules.py` : les règles, dans l'ordre
  dates, identifiants, contacts, adresses, noms.
- `04-clinical-documents/eds-nlp/prompt.md` et `exemples.txt` : le prompt
  d'annotation XML et ses exemples ; `service.py` : les deux pipelines.

## Démarrage

```bash
./bin/farci up 04-clinical-documents/docling
./bin/farci up 04-clinical-documents/eds-nlp
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
curl -s http://127.0.0.1:5002/health           # EDS-NLP de cette machine
```

## Test contractuel

```bash
./bin/farci test
```

Ligne `docling` : `PASS` si un PDF existe, sinon `SKIP` (générer les PDF avec
`./bin/farci generate-dataset --pdf`). Ligne `eds-nlp` : `PASS` si le service
pseudonymise sans laisser d'identité visible.

## Vérification sur le tableau de bord

Lignes `Documents` et `EDS-NLP` vertes (`🛟 REF` tant que la référence vous
remplace).

## Commit

Les règles de pseudonymisation et leurs tests. Jamais de fichier de
correspondance (`mapping.json`) : il permet de ré-identifier.

## Pull Request

Montrer un document avant et après pseudonymisation, et la sortie de
`./bin/farci test-unit -k deidentification`.

## Définition de DONE

```text
[ ] Docling et EDS-NLP démarrés
[ ] lignes Documents et EDS-NLP vertes
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
| EDS-NLP : `image absente` | image non construite sur ce poste | `./preload.sh --only build_eds_nlp` (avec Internet), ou `docker load` depuis la clé USB |
| EDS-NLP : 502 sur `/v1/entites` | le LLM de la salle ne répond pas | `./bin/farci status` ; `/v1/pseudonymiser` marche toujours |
| `./bin/farci eds compare` trop long | modèle sur processeur | `--limit 2` |
