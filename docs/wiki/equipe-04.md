# Équipe 4 — Documents cliniques

> Fiche débutant. La référence technique complète est
> `04-clinical-documents/TUTORIAL.md` (`./bin/farci read 4`).

## Votre objectif

Préparer les documents **avant** qu'un modèle ne les lise : la
**pseudonymisation** (aucun nom, aucune date de naissance, aucun IPP ne part
vers le modèle) et **Docling**, qui convertit les PDF en texte. La ligne
`Documents` passe de `🛟 REF` (ou `DOWN`) à `✅ UP`.

C'est le secret médical appliqué à la machine : le modèle reçoit le dossier,
pas l'identité du patient.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine ». Docling demande ~3 Go de RAM.
2. **Comprendre la pseudonymisation** — `./bin/farci test-unit -k deidentification` :
   tous les tests passent. Lisez-en un dans `tests/test_deidentification.py`.
3. **Pseudonymiser un document à la main** :

   ```bash
   PYTHONPATH=04-clinical-documents python3 -m deidentification.cli \
     datasets/raw/patient_1234567890123_cro.txt /tmp/cro-pseudo.txt
   ```

   Comparez les deux fichiers : `[NOM_0]`, `[DATE_0]`, `[IPP_0]`.
4. **Démarrer Docling** — `./bin/farci up 04-clinical-documents/docling`.
   Le premier démarrage prend **plusieurs minutes** : c'est normal.
5. **Tester Docling** — `04-clinical-documents/docling/smoke.sh`.
6. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set 4 <votre-ip>` sur le Pi).
7. **Regarder l'écran projeté** — la ligne `Documents` passe à `✅ UP`.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test-unit -k deidentification     # OK
04-clinical-documents/docling/smoke.sh          # Docling répond
```

Et sur l'écran de la salle : `Documents ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. Le parcours de l'étape 2 utilise les dossiers **texte** :
il ne dépend pas de Docling, rien n'attend votre équipe.

| Ce que vous voyez | À essayer |
|---|---|
| Docling ne répond pas après 5 min | `./bin/farci logs 04-clinical-documents/docling` : il charge encore ses modèles |
| `ModuleNotFoundError: deidentification` | relancer la commande depuis la racine du dépôt, avec `PYTHONPATH=04-clinical-documents` |
| `ModuleNotFoundError: pydantic` | `./bin/farci bootstrap` (environnement Python hors ligne) |
| un nom reste en clair | c'est une vraie trouvaille : ajoutez la règle dans `rules.py` et un test |

## Bonus

- Générer les PDF du jeu de données : `./bin/farci generate-dataset --pdf`,
  puis `./bin/farci test` (ligne `docling` : `PASS`).
- Comparer la sortie de Docling au texte d'origine d'un même dossier.
