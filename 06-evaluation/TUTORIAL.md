# TUTORIAL — Équipe 6 : Évaluation (MLflow en bonus)

## Mission

Mesurer les extractions contre le **gold standard** et les classer.
L'évaluation se fait en ligne de commande, pour tout le monde ; MLflow (suivi
des expériences) est une brique **bonus**.

- **Objectif minimal** : `./bin/farci evaluate --extracted-dir datasets/gold`
  donne un score parfait (contrôle), puis le classement des runs de l'étape 2.
- **Bonus** : MLflow démarré (ligne `Evaluation` verte), une expérience par
  configuration (modèle, prompt, runtime).

## Ce que votre service apporte

Un chiffre comparable. Sans référence, « F1 = 0,84 » ne veut rien dire ; avec
le même gold, le même schéma et le même alias de modèle pour tous, les
parcours deviennent comparables.

## Ce que vous devez comprendre

- **Évaluation = la revue de littérature** : on compare une méthode à une
  référence connue.
- **Le gold n'est jamais produit par un LLM** : il vient du registre des cas
  (`datasets/tools/cases.py`).
- **Règles de calcul** : un dossier absent ou non conforme au schéma compte
  comme « tout manqué » ; `null` attendu et `null` prédit est une bonne
  réponse ; `patient_id` n'est pas noté (clé pseudonymisée).

## Vos dépendances

Les extractions de l'étape 2 (`datasets/extracted/<run>/`).

## Votre IP

MLflow (bonus) : `MLFLOW_IP`, port `MLFLOW_PORT`.

## Installation

Rien pour l'évaluation (Python standard). MLflow : image préchargée
(`./bin/farci verify-images --all`).

## Configuration

- `06-evaluation/metrics/normalize.py` : casse, accents, unités, booléens.
- `datasets/schemas/clinical_extraction.schema.json` : le contrat.

## Démarrage

```bash
./bin/farci evaluate --extracted-dir datasets/gold      # contrôle : 1.00 partout
./bin/farci evaluate                                    # toutes les runs de l'étape 2
./bin/farci evaluate --subset quick --report-dir datasets/reports
```

Bonus :

```bash
./bin/farci up 06-evaluation/mlflow
```

## Test local

```bash
python3 06-evaluation/gold-standard/validate_gold.py
```

## Test contractuel

```bash
./bin/farci test-unit -k evaluation
```

Dont le test « gold contre gold = score parfait ».

## Vérification sur le tableau de bord

Ligne `MLflow` verte si MLflow tourne (bonus, `./bin/farci status --all`). Le classement des runs est
projeté pendant la séance d'évaluation.

## Commit

Le code de métriques et ses tests. Jamais `datasets/extracted/` ni
`datasets/reports/` : ce sont des résultats d'expérience.

## Pull Request

Joindre le tableau de classement produit par `./bin/farci evaluate`.

## Définition de DONE

```text
[ ] gold contre gold : F1 = 1.00
[ ] classement des runs de l'étape 2 projeté
[ ] tests d'évaluation verts
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| « aucune extraction trouvée » | aucun `patient_*.json` sous `datasets/extracted/` | lancer l'étape 2 (`./bin/farci extract`) |
| un dossier « invalide » | champ manquant ou hors énumération | lire la colonne d'erreur du rapport |
| F1 bas mais exactitude haute | beaucoup de `null` bien reconnus | c'est normal : lire précision et rappel |
