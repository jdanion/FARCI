# Équipe 6 — Évaluation

> Fiche débutant. La référence technique complète est
> `06-evaluation/TUTORIAL.md` (`./bin/farci read 6`).

## Votre objectif

**Mesurer** les extractions contre le **gold standard** (la vérité terrain,
écrite à la main, jamais par un modèle) et **classer** les essais de la
salle. Pas de ligne à faire passer au vert : votre résultat est le
classement projeté pendant l'évaluation.

C'est la revue de littérature : un chiffre seul ne veut rien dire, il se
compare à une référence connue.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` (« dépendances Python » ok).
2. **Contrôler le gold** — `python3 06-evaluation/gold-standard/validate_gold.py`.
3. **Contrôle de l'outil** — `./bin/farci evaluate --extracted-dir datasets/gold` :
   le gold comparé à lui-même donne **1.00** partout. Si ce n'est pas le
   cas, l'outil est faux, pas le modèle.
4. **Une première extraction** — `./bin/farci extract --replay --subset quick --run essai`
   (réponses enregistrées, sans réseau).
5. **L'évaluer** — `./bin/farci evaluate --subset quick` : lisez complétude,
   précision, rappel, F1, et les champs les moins bien extraits.
6. **Expliquer un écart** — ouvrez un `patient_*.json` de
   `datasets/extracted/essai/` et le gold du même patient : quel champ
   diffère, et pourquoi ?
7. **Préparer le classement** — après l'étape 2 :
   `./bin/farci evaluate --subset quick --report-dir datasets/reports`.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test-unit -k evaluation      # OK (dont « gold contre gold = 1.00 »)
./bin/farci evaluate --subset quick       # un tableau de classement
```

## Bloqué depuis 10 minutes ?

Levez la main.

| Ce que vous voyez | À essayer |
|---|---|
| « aucune extraction trouvée » | aucune run encore : étape 4 ci-dessus |
| un dossier « invalide » | le JSON ne respecte pas le schéma : lisez la colonne d'erreur |
| F1 bas mais exactitude haute | beaucoup de `null` bien reconnus : lisez précision et rappel séparément |
| `ModuleNotFoundError` | `./bin/farci bootstrap` |

## Bonus

- MLflow, une expérience par configuration (modèle, prompt, runtime) :
  `./bin/farci up 06-evaluation/mlflow` (ligne `MLflow`, `./bin/farci status --all`).
- Comparer le prompt v1 et le prompt v2 :
  `./bin/farci extract --replay --subset quick --prompt v2 --run essai-v2`, puis
  `./bin/farci evaluate --subset quick`.
