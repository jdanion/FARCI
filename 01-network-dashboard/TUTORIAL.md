# TUTORIAL — Équipe 1 : Réseau et tableau de bord

## Mission

Donner à la plateforme **une adresse stable** (Caddy) et **un état visible**
(health-aggregator, tableau `./bin/farci status`).

- **Objectif minimal** : Caddy et l'agrégateur tournent, la ligne `Network`
  passe au vert.
- **Bonus** : Uptime Kuma affiche les mêmes sondes dans un navigateur.

## Ce que votre service apporte

Toutes les applications parlent à Caddy, jamais à un runtime ou à une
passerelle directement : `/v1` (passerelle LLM), `/docling` (documents),
`/status` (état du système). Sans vous, rien n'est exposé et personne ne sait
ce qui marche.

## Ce que vous devez comprendre

- **Reverse proxy = l'accueil de l'hôpital** : une adresse unique, le patient
  ne connaît pas les numéros de service. On peut changer un service derrière
  sans prévenir les patients.
- **Sonde de santé** : un chemin HTTP (`/healthz`) qui répond 200 si le
  service va bien. Le tableau ne fait qu'interroger ces sondes.
- **Service critique** : `CLINICAL PIPELINE READY` n'est vrai que si tous les
  services marqués `critical: true` dans `config/services.yaml` répondent.

## Vos dépendances

Aucune en amont : vous démarrez en premier. Toutes les autres équipes
dépendent de vous pour être exposées.

## Votre IP

| Service | Adresse | Port |
|---|---|---|
| Caddy | `CADDY_IP` | `CADDY_INTERNAL_PORT` (publié sur `CADDY_HTTP_PORT`) |
| health-aggregator | `HEALTH_AGGREGATOR_IP` | `HEALTH_AGGREGATOR_PORT` |
| Uptime Kuma (bonus) | `UPTIME_KUMA_IP` | `UPTIME_KUMA_PORT` |

Les valeurs sont dans `config/network.env` (`./bin/farci env`).

## Installation

Images `caddy`, `python` et `uptime-kuma` préchargées
(`./bin/farci verify-images`).

## Configuration

- `01-network-dashboard/caddy/Caddyfile` : les routes. Il ne contient aucune
  adresse : Caddy lit `{$GATEWAY_A_IP}`, `{$DOCLING_IP}`… dans son
  environnement, transmis par `01-network-dashboard/docker-compose.yml`.
- `config/services.yaml` : la liste des services, leurs sondes et le champ
  `critical`. C'est la source de vérité du tableau.

## Démarrage

```bash
./bin/farci up 01-network-dashboard
./bin/farci logs 01-network-dashboard     # Ctrl+C pour quitter
```

## Test local

```bash
./bin/farci status
```

La ligne `Network` doit être verte. Les autres sont rouges tant que les
équipes n'ont pas livré : c'est normal.

## Test contractuel

```bash
./bin/farci test
```

La ligne `network` doit être `PASS` (Caddy répond et relaie `/status`).

## Vérification sur le tableau de bord

```bash
./bin/farci status --watch      # sur l'écran projeté
```

Bonus Uptime Kuma : créer les sondes depuis le registre avec
`scripts/uptime-kuma-seed.sh`, puis ouvrir Uptime Kuma dans le navigateur.

## Commit

On versionne le `Caddyfile` et `config/services.yaml`. Jamais
`config/network.env` (il est propre à la salle).

## Pull Request

Branche `feat/equipe-1/<sujet>`. Dans la description : la sortie de
`./bin/farci status` et de `./bin/farci test`.

## Définition de DONE

```text
[ ] Caddy et health-aggregator démarrés
[ ] ligne Network verte sur ./bin/farci status
[ ] ./bin/farci test : network PASS
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `CADDY_IP manquant` au démarrage | `config/network.env` absent | `cp config/network.env.example config/network.env` |
| `port is already allocated` | un autre service occupe le port 80 de la machine | changer `CADDY_HTTP_PORT` dans `.env`, puis `./bin/farci up 01-network-dashboard` |
| `/v1` renvoie 502 | la passerelle (équipe 3) n'est pas encore là | normal tant que `LLM Gateway` est rouge |
