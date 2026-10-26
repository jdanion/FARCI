# Étape 3 — Chaos engineering (toute la salle)

> Fiche débutant. La référence complète est `docs/CHAOS.md`. Les commandes
> se lancent **sur le Pi**, par le formateur ; la salle observe et parie.

## L'objectif

Casser le système **exprès**, une panne à la fois, et vérifier qu'il tient
la promesse écrite **avant** la panne. Chaque scénario annonce son
résultat attendu, provoque la panne, puis **vérifie** : `ATTENDU` ou
`INATTENDU`.

C'est la simulation de crise : on ne découvre pas le plan blanc le jour de
la catastrophe.

## Le déroulé de chaque scénario (5 à 8 minutes)

1. **Annoncer** — le formateur lit le titre : « le runtime principal tombe ».
2. **Parier** — chacun note : *survivra* ou *ne survivra pas* ? Pourquoi ?
3. **Provoquer** — `./bin/farci chaos scenario-01` : la ligne `attendu` s'affiche.
4. **Observer** — l'écran projeté (`./bin/farci status --watch`) : quelle
   ligne change ? `✅` → `🛟` (la référence prend le relais) ou `DOWN`
   (personne ne répond) ? La ligne `PANNE EN COURS` dit ce qui est coupé.
5. **Vérifier** — le scénario affiche `ATTENDU` (la promesse est tenue) ou
   `INATTENDU` (une vraie découverte : on en parle).
6. **Réparer** — `./bin/farci chaos reset` : tout revient.
7. **Retenir** — une phrase, la leçon du scénario (`docs/CHAOS.md`).

## Les quatre scénarios de la séance

| Scénario | La panne | Ce qu'on doit voir |
|---|---|---|
| 01 | le runtime de l'équipe 2 ne répond plus | l'extraction répond toujours ; `Inference 🛟 REF` |
| 04 | le modèle renvoie un JSON hors schéma | 3 dossiers refusés, **aucun** fichier écrit |
| 06 (ou 05) | la passerelle de l'équipe 3 tombe (ou Docling) | le client ne change pas d'adresse (ou : le texte continue sans Docling) |
| 07 | plus aucune trace n'arrive | l'extraction réussit quand même : l'observabilité n'est pas le soin |

## La sonde : comment savoir que c'est fini

```bash
./bin/farci reset-all     # pannes réparées, bascules levées, tableau affiché
```

Plus de ligne `PANNE EN COURS` sous le tableau.

## Bloqué depuis 10 minutes ?

| Ce que vous voyez | À faire |
|---|---|
| `INATTENDU` | ce n'est pas un échec de la séance : c'est la découverte du jour, on l'explique |
| la panne ne se répare pas | `./bin/farci reset-all` |
| on a pris du retard | garder 01, 04 et 07 (voir `docs/INSTRUCTOR_GUIDE.md`) |

## Bonus

- Variante vivante : c'est l'équipe 2 qui arrête **vraiment** son runtime
  (`./bin/farci down 02-inference/ollama`) ; le scénario 01 sert à vérifier.
- Scénario 02 : plus **aucun** runtime. Où s'arrête la protection ?
