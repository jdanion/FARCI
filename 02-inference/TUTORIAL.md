# TUTORIAL — Équipe 2 : Inférence

## Mission

Faire tourner le modèle et l'exposer derrière le contrat d'inférence
(`02-inference/CONTRACT.md`).

- **Objectif minimal** : Ollama sert le modèle, la ligne `Inference Primary`
  passe au vert.
- **Bonus** : llama.cpp sert **le même fichier de poids** (ligne
  `Inference Secondary`), benchmark comparé ; oMLX sur un Mac.

## Ce que votre service apporte

Le calcul. La passerelle (équipe 3) vous envoie des requêtes au format OpenAI ;
vous rendez du texte. Sans runtime, aucune extraction.

## Ce que vous devez comprendre

- **Le modèle n'est pas le runtime** : le modèle est un fichier de poids (les
  connaissances), le runtime est le logiciel qui l'exécute (le laboratoire).
  Le même fichier tourne dans Ollama et dans llama.cpp, avec des performances
  différentes.
- **Comparer deux runtimes n'a de sens qu'à poids constants** : c'est pour
  cela qu'un seul fichier GGUF sert aux deux.
- **Modèle de raisonnement** : le raisonnement doit sortir dans
  `reasoning_content`, jamais dans `content` (sinon le JSON est refusé).

## Vos dépendances

Le réseau (équipe 1). La passerelle (équipe 3) dépend de vous.

## Votre IP

| Runtime | Adresse | Port |
|---|---|---|
| Ollama (primaire) | `INFERENCE_A_IP` | `INFERENCE_PORT` |
| llama.cpp (secondaire, bonus) | `INFERENCE_B_IP` | `INFERENCE_PORT` |
| oMLX (Mac, bonus) | `INFERENCE_C_IP` | `INFERENCE_PORT` |

## Installation

- Poids dans `$FARCI_DATA_DIR/offline/models/` : `./bin/farci verify-models`.
  Machine de moins de 16 Go de RAM : le modèle de secours Qwen3.5-2B suffit
  (`./preload.sh --models-ci` avant l'atelier).
- Images préchargées : `./bin/farci verify-images`.

## Configuration

- `02-inference/ollama/Modelfile` : paramètres du modèle (température 0).
- `02-inference/llamacpp/params.json` et `grammar/clinical.gbnf` : sortie
  contrainte au schéma (bonus).

## Démarrage

```bash
./bin/farci up 02-inference/ollama
02-inference/ollama/create-model.sh       # importe les GGUF présents dans Ollama
```

Bonus :

```bash
./bin/farci up 02-inference/llamacpp
```

oMLX (Mac uniquement) : suivre `02-inference/omlx/README.md`
(`02-inference/omlx/install-mlx.sh`).

## Test local

```bash
./bin/farci status
```

## Test contractuel

```bash
./bin/farci test
```

La ligne `inference-contract` doit être `PASS` (`/v1/models` renvoie une liste).
Pour tester llama.cpp : `BASE_URL=<URL du runtime B>/v1 tests/test_inference_contract.sh`.

## Vérification sur le tableau de bord

Ligne `Inference Primary` verte (bonus : `Inference Secondary`).

## Commit

Les `Modelfile`, paramètres et compose. Jamais de fichier `.gguf` : les poids
restent dans `$FARCI_DATA_DIR`.

## Pull Request

Joindre la sortie de `02-inference/bench/bench.sh` : latence et débit, même
modèle, runtime différent.

## Définition de DONE

```text
[ ] Ollama démarré, modèle importé
[ ] ligne Inference Primary verte
[ ] ./bin/farci test : inference-contract PASS
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| le conteneur s'arrête, `out of memory` | RAM insuffisante pour le 9B | utiliser le modèle de secours Qwen3.5-2B (`med-extraction-lite`) |
| `create-model.sh` : GGUF manquant | poids non copiés | `./bin/farci verify-models` |
| réponses très lentes (> 60 s) | CPU seul, gros modèle | modèle de secours, ou demander au formateur de basculer sur la pile de référence |
