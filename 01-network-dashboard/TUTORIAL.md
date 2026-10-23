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
Une brique est jointe par **l'IP de votre machine** et **le port publié** de
ce service (un port par service, identique sur toutes les machines) :

| Service | Adresse | Port publié |
|---|---|---|
| Caddy (votre accueil) | `CADDY_IP` | `CADDY_PORT` |
| health-aggregator | `HEALTH_AGGREGATOR_IP` | `HEALTH_AGGREGATOR_PORT` |
| Uptime Kuma (bonus) | `UPTIME_KUMA_IP` | `UPTIME_KUMA_PORT` |

`./bin/farci doctor` affiche l'IP de votre machine : donnez-la au formateur,
qui la déclare sur le Pi (`./bin/farci room set 1 <ip>`). L'accueil **de la
salle** (`REFERENCE_IP:ENTRY_PORT`) est le Caddy du Pi : il utilise **le
même Caddyfile que le vôtre**. Tant que vos briques ne sont pas montées, le
tableau affiche 🛟 : la référence du formateur rend le service.

## Installation

Images `caddy`, `python` et `uptime-kuma` préchargées
(`./bin/farci verify-images`).

## Configuration

- `01-network-dashboard/caddy/Caddyfile` : les routes. Il ne contient aucune
  adresse : Caddy lit `{$UP_PASSERELLE}`, `{$UP_INFERENCE}`… dans son
  environnement. `./bin/farci up` les construit depuis `config/network.env` :
  « brique de l'équipe, puis brique de la référence » (`./bin/farci
  services upstreams` les affiche). Si la première ne répond pas, Caddy passe
  à la suivante : c'est le **repli**.
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

Bonus Uptime Kuma : `./bin/farci up 01-network-dashboard uptime-kuma`, puis
créer les sondes depuis le registre avec `scripts/uptime-kuma-seed.sh`.

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
| `UP_PASSERELLE manquant` au démarrage | `docker compose up` lancé à la main | toujours démarrer avec `./bin/farci up 01-network-dashboard` |
| `config/network.env` absent | première installation | `cp config/network.env.example config/network.env` |
| `port is already allocated` | un autre service occupe `CADDY_PORT` sur la machine | `./bin/farci doctor` (section ports) ; arrêter l'autre service, ou demander au formateur un autre port |
| `/v1` renvoie 502 | ni la passerelle de l'équipe 3 ni celle de la référence ne répond | `./bin/farci status` ; si la référence est DOWN, prévenir le formateur |
