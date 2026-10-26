# Équipe 3 — Passerelle LLM

> Fiche débutant. La référence technique complète est
> `03-llm-gateway/TUTORIAL.md` (`./bin/farci read 3`).

## Votre objectif

Monter **la passerelle** (LiteLLM) : le seul point par lequel les
applications parlent aux modèles. La ligne `LLM Gateway` passe de `🛟 REF`
à `✅ UP`.

Une application ne doit jamais connaître le modèle qui lui répond : comme
un standard téléphonique, la passerelle oriente l'appel, réessaie, et
bascule sur un autre poste si le premier ne décroche pas.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine ».
2. **Lire la configuration** — `03-llm-gateway/litellm/config.yaml` : un nom
   logique, `med-extraction`, et son repli `med-extraction-lite`. Aucune
   adresse : le runtime est joint par l'accueil de la salle.
3. **Démarrer** — `./bin/farci up 03-llm-gateway/litellm`.
4. **Suivre le démarrage** — `./bin/farci logs 03-llm-gateway/litellm` jusqu'à
   `Uvicorn running` (Ctrl+C pour quitter).
5. **Tester votre passerelle** — `curl -s http://127.0.0.1:4000/v1/models` :
   la liste contient `med-extraction`.
6. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set 3 <votre-ip>` sur le Pi).
7. **Tester par l'accueil** — `./bin/farci test` : `gateway-contract PASS`.
   L'écran affiche `LLM Gateway ✅ UP`.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # gateway-contract   PASS   med-extraction
```

Et sur l'écran de la salle : `LLM Gateway ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. Les applications de la salle passent par la passerelle de
la référence (🛟) en attendant.

| Ce que vous voyez | À essayer |
|---|---|
| la passerelle ne démarre pas | `./bin/farci logs 03-llm-gateway/litellm` : souvent une erreur d'indentation dans `config.yaml` |
| `FARCI_RUNTIME_URL manquante` | `config/network.env` : `REFERENCE_IP` doit être l'adresse du Pi |
| 500 « connection refused » | aucun runtime ne répond : `./bin/farci status`, prévenir le formateur |
| `curl` fonctionne, l'écran reste `🛟` | votre IP n'est pas déclarée : `./bin/farci room` sur le Pi |

## Bonus

- Démonstration du repli : `03-llm-gateway/failover/demo-failover.sh`.
- Bifrost, seconde passerelle : `./bin/farci up 03-llm-gateway/bifrost`.
- Clés virtuelles et quotas (scénario 03) : demandent une base PostgreSQL,
  voir le TUTORIAL.
