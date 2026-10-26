# Équipe 5 — Observabilité

> Fiche débutant. La référence technique complète est
> `05-observability/TUTORIAL.md` (`./bin/farci read 5`).

## Votre objectif

Rendre **visible** chaque appel au modèle : qui, quand, combien de temps,
combien de mots, quelle erreur. Phoenix reçoit ces **traces** ; la ligne
`Observability` passe de `🛟 REF` à `✅ UP`.

C'est le dossier de soins de la machine : on ne se souvient pas de ce qui
s'est passé, on le lit.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine ».
2. **Démarrer Phoenix** — `./bin/farci up 05-observability/phoenix`.
3. **Ouvrir Phoenix** — dans un navigateur : `http://127.0.0.1:6006`.
4. **Tester chez vous** — `./bin/farci test` : la ligne `observability` doit
   être `PASS`.
5. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set 5 <votre-ip>` sur le Pi). Les traces de toute la
   salle arrivent maintenant chez vous.
6. **Produire des traces** — `./bin/farci extract --subset quick --limit 2 --run equipe-5`.
7. **Lire une trace** — dans Phoenix, ouvrez un span `chat.completion` :
   modèle, latence, nombre de tokens.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # observability   PASS
```

Dans Phoenix : des spans `chat.completion`. Sur l'écran : `Observability ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. Si Phoenix tombe, **l'extraction continue** (c'est même le
scénario 07) : rien n'attend votre équipe.

| Ce que vous voyez | À essayer |
|---|---|
| aucune trace | `./bin/farci doctor` : « dépendances Python » ; sinon `./bin/farci bootstrap` |
| aucune trace (bis) | `FARCI_TRACE=off` dans `config/workshop.env` ? le retirer |
| Phoenix ne démarre pas | `./bin/farci logs 05-observability/phoenix` ; port 6006 déjà pris ? |
| traces chez vous, pas celles de la salle | votre IP n'est pas déclarée : `./bin/farci room` sur le Pi |

## Bonus

- Langfuse, l'autre stack au choix (grosse configuration), ou en second backend sur le **même** flux OpenTelemetry :
  `./bin/farci up 05-observability/langfuse` puis `05-observability/langfuse/bootstrap.sh`.
- Collecteur OpenTelemetry en éventail : `./bin/farci up 05-observability/collector`.
