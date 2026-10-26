# TUTORIAL — Équipe 3 : Passerelle LLM

## Mission

Exposer **un seul nom de modèle** (`med-extraction`) au format OpenAI, quel que
soit le runtime derrière, avec clés, quotas et repli (`03-llm-gateway/CONTRACT.md`).

- **Objectif minimal** : LiteLLM répond, la ligne `LLM Gateway` passe au vert.
- **Bonus** : clés virtuelles et quotas (scénario 03), repli vers le runtime
  secondaire, Bifrost en seconde implémentation.

## Ce que votre service apporte

Les applications ne connaissent ni Ollama ni llama.cpp : elles appellent
`med-extraction`. Vous décidez qui calcule, vous réessayez, vous basculez en
cas de panne, vous comptez.

## Ce que vous devez comprendre

- **Passerelle = le standard téléphonique de l'hôpital** : un numéro unique,
  qui transfère, met en attente, et rappelle un autre service si le premier
  ne répond pas.
- **Alias** : `med-extraction` est un nom logique. Changer de modèle ne
  modifie pas une ligne du code de l'application.
- **Quota** : le débit est une propriété de la passerelle, pas du modèle.

## Vos dépendances

Le runtime (équipe 2) en amont, Caddy (équipe 1) devant vous. Toutes les
applications dépendent de vous.

## Votre IP

Une brique est jointe par **l'IP de votre machine** et **le port publié** de
ce service :

| Passerelle | Adresse | Port publié |
|---|---|---|
| LiteLLM (A) | `GATEWAY_A_IP` | `GATEWAY_A_PORT` |
| Bifrost (B, bonus) | `GATEWAY_B_IP` | `GATEWAY_B_PORT` |

`./bin/farci doctor` affiche l'IP de votre machine ; le formateur la déclare
sur le Pi (`./bin/farci room set 3 <ip>`). Les applications appellent
l'accueil de la salle (`REFERENCE_IP:ENTRY_PORT/v1`) : il vous sert dès que
vous répondez, et sert la passerelle de la référence (🛟) sinon.

## Installation

Image `litellm` préchargée (`./bin/farci verify-images`).

## Configuration

- `03-llm-gateway/litellm/config.yaml` : les alias. L'adresse du runtime n'y
  figure pas : `api_base: os.environ/FARCI_RUNTIME_URL`, c'est-à-dire
  l'accueil de la salle (`/runtime/v1`), qui choisit le runtime de
  l'équipe 2 ou celui de la référence. Vous ne changez rien quand l'équipe 2
  arrive : c'est tout l'intérêt.
- Clés virtuelles et quotas (bonus, scénario 03) : LiteLLM exige alors une
  base PostgreSQL ; sans elle, la passerelle fonctionne sans clé.

## Démarrage

```bash
./bin/farci up 03-llm-gateway/litellm
```

Bonus (configuration à valider sur le matériel avant l'atelier) :

```bash
./bin/farci up 03-llm-gateway/bifrost
```

## Test local

```bash
./bin/farci status
```

## Test contractuel

```bash
./bin/farci test
```

La ligne `gateway-contract` doit être `PASS` : une requête à
`med-extraction` passe par Caddy (`/v1`) et revient en 200.

## Vérification sur le tableau de bord

Ligne `LLM Gateway` verte. Démonstration du repli :
`03-llm-gateway/failover/demo-failover.sh`.

## Commit

`config.yaml` et compose. Jamais de clé : elles sont dans `.env`.

## Pull Request

Montrer que le même appel répond avec Ollama puis avec llama.cpp, sans
changer le client.

## Définition de DONE

```text
[ ] LiteLLM démarré, alias med-extraction servi
[ ] ligne LLM Gateway verte
[ ] ./bin/farci test : gateway-contract PASS
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| 500 « connection refused » | ni le runtime de l'équipe 2 ni celui de la référence ne répond | `./bin/farci status` ; prévenir le formateur |
| 401 (bonus clés) | clé absente ou fausse | `03-llm-gateway/litellm/bootstrap-keys.sh` |
| la passerelle ne démarre pas | erreur dans `config.yaml` | `./bin/farci logs 03-llm-gateway/litellm` |
