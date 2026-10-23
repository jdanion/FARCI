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

| Passerelle | Adresse | Port |
|---|---|---|
| LiteLLM (A) | `GATEWAY_A_IP` | `GATEWAY_PORT` |
| Bifrost (B, bonus) | `GATEWAY_B_IP` | `GATEWAY_PORT` |

## Installation

Image `litellm` préchargée (`./bin/farci verify-images`).

## Configuration

- `03-llm-gateway/litellm/config.yaml` : les alias. L'adresse du runtime n'y
  figure pas : `api_base: os.environ/INFERENCE_A_URL`, construite par le
  compose depuis `config/network.env`.
- `.env` : `LITELLM_MASTER_KEY`, `GATEWAY_KEY_STANDARD`, `GATEWAY_KEY_PRIORITY`.

## Démarrage

```bash
./bin/farci up 03-llm-gateway/litellm
03-llm-gateway/litellm/bootstrap-keys.sh     # clés virtuelles standard / prioritaire
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
| 401 | clé absente ou fausse | `03-llm-gateway/litellm/bootstrap-keys.sh` |
| 500 « connection refused » | runtime (équipe 2) pas encore vert | `./bin/farci status` |
| la passerelle ne démarre pas | erreur dans `config.yaml` | `./bin/farci logs 03-llm-gateway/litellm` |
