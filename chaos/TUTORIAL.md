# TUTORIAL — Étape 3 : Chaos engineering

## Mission

Casser la plateforme **volontairement**, une panne à la fois, et vérifier
qu'elle se comporte comme l'architecture le promet (`docs/CHAOS.md`).

- **Objectif minimal** : chaque scénario joué est réparé (`reset`) et le
  tableau revient au vert.
- **Bonus** : prédire le résultat avant de lancer la panne, puis l'expliquer.

## Ce que votre service apporte

La preuve que la redondance existe vraiment. Une architecture jamais testée en
mode dégradé n'est pas redondante, elle est théorique.

## Ce que vous devez comprendre

- **Chaque panne est réversible** et son résultat attendu est écrit avant.
- **Dépendance partielle** : ce qui tombe, ce qui tient, et pourquoi.
- **L'observabilité n'est pas sur le chemin de production** (scénario 07).

## Vos dépendances

La plateforme complète de l'étape 1, et Docker sur la machine qui pilote.

## Votre IP

Aucune : les scénarios utilisent les adresses de `config/network.env`.

## Installation

Rien de plus que l'étape 1.

## Configuration

`config/workshop.env` : `FARCI_CHAOS_MAX_DURATION` (durée maximale d'une
panne avant réparation automatique conseillée).

## Démarrage

```bash
./bin/farci chaos list
./bin/farci chaos scenario-01                  # applique la panne
./bin/farci chaos scenario-01 --duration 60    # applique, puis répare après 60 s
./bin/farci chaos status                       # pannes actives
./bin/farci chaos reset                        # répare tout
```

`./chaos/chaos.sh` accepte exactement les mêmes commandes.

## Test local

Après chaque scénario : `./bin/farci status` doit montrer la panne, puis
revenir au vert après `./bin/farci chaos reset`.

## Test contractuel

```bash
FARCI_TESTS_DESTRUCTIVE=1 ./bin/farci test
```

Exécute aussi `tests/test_failover.sh` (scénario 01 automatisé).

## Vérification sur le tableau de bord

| Scénario | Ce qui doit rester vert |
|---|---|
| 01 runtime primaire | `LLM Gateway`, `CLINICAL PIPELINE` (si un secondaire existe) |
| 04 JSON invalide | tout : seul le dossier est refusé |
| 05 Docling | `LLM Gateway`, `Inference Primary` |
| 07 observabilité | l'extraction, `CLINICAL PIPELINE` côté calcul |

## Commit

Un nouveau scénario = un fichier `chaos/scenarios/scenario-NN-<nom>.sh` avec
`SCENARIO_TITLE`, `chaos_scenario_apply` et `chaos_scenario_revert`.

## Pull Request

Décrire l'action, le résultat attendu, l'observation et la leçon.

## Définition de DONE

```text
[ ] scénarios joués et réparés
[ ] ./bin/farci chaos status : aucune panne active
[ ] ./bin/farci status : retour au vert
[ ] Pull Request ouverte et relue (nouveau scénario)
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `reset` signale une réparation échouée | conteneur supprimé au lieu d'être arrêté | `./bin/farci up <dossier de la brique>` |
| la panne reste listée après redémarrage de la machine | état conservé dans `.chaos/state.json` | `./bin/farci chaos reset` |
| un scénario ne fait rien | brique absente de cette machine | jouer le scénario sur la machine qui l'héberge |
