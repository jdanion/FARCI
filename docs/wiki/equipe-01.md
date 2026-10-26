# Équipe 1 — Réseau et tableau de bord

> Fiche débutant. La référence technique complète est
> `01-network-dashboard/TUTORIAL.md` (`./bin/farci read 1`).

## Votre objectif

Monter **votre accueil** (Caddy) et **l'agrégateur de santé** : la ligne
`Network` du tableau passe de `🛟 REF` à `✅ UP`.

Votre Caddy utilise **le même fichier** que l'accueil de la salle, sur le
Raspberry Pi du formateur : vous construisez la porte d'entrée de l'hôpital.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor`. Notez la ligne
   « IP de cette machine ».
2. **Lire le plan des routes** — ouvrez `01-network-dashboard/caddy/Caddyfile` :
   `/v1` (passerelle), `/runtime` (modèles), `/docling`, `/observability`.
   Pour chaque route : « l'équipe d'abord, la référence ensuite ».
3. **Démarrer** — `./bin/farci up 01-network-dashboard`.
4. **Suivre le démarrage** — `./bin/farci logs 01-network-dashboard`
   (Ctrl+C pour quitter) : aucune ligne `error`.
5. **Tester chez vous** — `./bin/farci test` : la ligne `network` doit être
   `PASS`.
6. **Vous déclarer** — donnez votre IP au formateur. Il lance sur le Pi
   `./bin/farci room set 1 <votre-ip>`.
7. **Regarder l'écran projeté** — la ligne `Network` passe à `✅ UP`.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # network   PASS
```

Et sur l'écran de la salle : `Network ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. Rien n'est cassé pour la salle : la référence (🛟) sert à
votre place pendant que vous cherchez.

| Ce que vous voyez | À essayer |
|---|---|
| `port is already allocated` | `./bin/farci doctor`, section ports : un autre logiciel occupe `CADDY_PORT` |
| `UP_PASSERELLE manquant` | vous avez lancé `docker compose` à la main : utilisez `./bin/farci up 01-network-dashboard` |
| `./bin/farci test` : `SKIP service absent` | Caddy n'a pas démarré : `./bin/farci logs 01-network-dashboard` |
| tout est vert chez vous, `🛟` à l'écran | le formateur n'a pas (encore) déclaré votre IP : `./bin/farci room` sur le Pi |

## Bonus

- Uptime Kuma : `./bin/farci up 01-network-dashboard uptime-kuma`, puis
  `scripts/uptime-kuma-seed.sh` pour créer les sondes depuis le registre.
- Expliquer à la salle **pourquoi** la ligne `Network` reste verte quand une
  autre équipe tombe : le repli est dans votre fichier.
