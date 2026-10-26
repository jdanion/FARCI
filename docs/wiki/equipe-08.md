# Équipe 8 — Agents Arcane (bonus)

> Fiche débutant. La référence technique complète est
> `08-arcane-agents/TUTORIAL.md` (`./bin/farci read 8`).

## Votre objectif

Placer un **petit agent de surveillance** à côté des briques, et
**redéployer automatiquement** une brique quand une Pull Request est
fusionnée dans la forge. Brique **bonus** : démonstration du formateur si
personne ne la prend.

C'est l'infirmier de garde : il passe toutes les 30 secondes et note l'état
de chaque patient.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor`.
2. **Préparer le secret** — `WEBHOOK_SECRET` dans `.env`.
3. **Démarrer** — `./bin/farci up 08-arcane-agents`.
4. **Lire les rondes** — `./bin/farci logs 08-arcane-agents` : chaque agent
   écrit l'état de sa brique toutes les 30 s.
5. **Comparer au tableau** — `./bin/farci status` : les agents et le tableau
   disent-ils la même chose ?
6. **Brancher la forge** (si l'équipe 0 l'a montée) — un webhook Gitea vers
   le récepteur ; fusionner une PR sur la branche `seance`.
7. **Observer le redéploiement** — `webhook-handler.sh`, puis `gitops.sh`,
   apparaissent dans les journaux.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci logs 08-arcane-agents     # une ronde toutes les 30 s
```

## Bloqué depuis 10 minutes ?

Levez la main : rien dans la séance n'attend cette brique.

| Ce que vous voyez | À essayer |
|---|---|
| `WEBHOOK_SECRET requis` | l'ajouter dans `.env` |
| un agent signale « down » en boucle | la brique surveillée n'est pas démarrée : `./bin/farci status` |
| la construction échoue | image `python` absente : `./bin/farci verify-images` |

## Bonus

- Expliquer la différence entre « surveiller » (agents, tableau) et
  « réparer » (repli de l'accueil, `rescue`) : qui décide, et quand ?
