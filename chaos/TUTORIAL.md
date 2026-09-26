# TUTORIAL — Étape 3 : Chaos engineering

## Objectif

Tester la résilience du pipeline en injectant des pannes contrôlées.

## Principe

Chaque scénario a :
- `apply` : injecte la panne
- `revert` : restaure l'état normal
- **Idempotent** : appliquer deux fois ne casse pas tout

## Scénarios

| # | Scénario | Commande |
|---|---|---|
| 01 | Runtime primaire down | `./chaos/chaos.sh scenario-01` |
| 02 | Runtime secondaire down | `./chaos/chaos.sh scenario-02` |
| 03 | Rate limiting | `./chaos/chaos.sh scenario-03` |
| 04 | JSON invalide | `./chaos/chaos.sh scenario-04` |
| 05 | Docling down | `./chaos/chaos.sh scenario-05` |
| 06 | Gateway A down | `./chaos/chaos.sh scenario-06` |
| 07 | Observabilité down | `./chaos/chaos.sh scenario-07` |

## Auto-revert

```bash
./chaos/chaos.sh scenario-01 --duration 60
# Applique la panne, attend 60s, puis revert automatiquement
```

## Reset

```bash
./chaos/chaos.sh reset
# Restaure tous les services
```
