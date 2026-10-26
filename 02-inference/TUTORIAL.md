# TUTORIAL — Équipe 2 : Inférence

## Mission

Faire tourner le modèle et l'exposer derrière le contrat d'inférence
(`02-inference/CONTRACT.md`).

- **Objectif minimal** : Ollama sert le modèle, la ligne `Inference Primary`
  passe au vert.
- **Bonus** : llama.cpp sert **le même fichier de poids** (ligne
  `Inference Secondary`), benchmark comparé ; selon le poste.

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

Une brique est jointe par **l'IP de votre machine** et **le port publié** de
ce service :

| Runtime | Adresse | Port publié |
|---|---|---|
| Ollama (primaire) | `INFERENCE_A_IP` | `INFERENCE_A_PORT` |
| llama.cpp (secondaire, bonus) | `INFERENCE_B_IP` | `INFERENCE_B_PORT` |

`./bin/farci doctor` affiche l'IP de votre machine ; le formateur la déclare
sur le Pi (`./bin/farci room set 2 <ip>`). Tous les runtimes servent le
**même nom logique**, `med-extraction` : la passerelle ne sait pas lequel
répond. Tant que le vôtre n'est pas monté, la ligne affiche 🛟 : le runtime
rejoué de la référence répond à votre place.

## Installation

- Deux stacks, selon le poste (`./preload.sh --equipe 2` choisit seul) :
  **grosse configuration** (GPU NVIDIA ou 32 Go de RAM) → Ollama + Ornith-1.5-9B ;
  **sinon** → llama.cpp (compilé pour la machine) + Qwen3.5-2B. Les deux servent
  `med-extraction` : la ligne Inference du tableau passe au vert avec l'une ou l'autre.
- Poids dans `$FARCI_DATA_DIR/offline/models/` : `./bin/farci verify-models`.
- Images préchargées : `./bin/farci verify-images`.

## Configuration

- `02-inference/ollama/Modelfile` : paramètres du modèle (température 0).
- `02-inference/llamacpp/params.json` et `grammar/clinical.gbnf` : sortie
  contrainte au schéma (bonus).

## Démarrage

```bash
./bin/farci up 02-inference/ollama
02-inference/ollama/create-model.sh       # auto : principal (9B) si ≥ 16 Go de RAM, sinon secours (2B)
02-inference/ollama/create-model.sh secours   # forcer le modèle de secours (machine faible, réponses lentes)
```

Bonus :

```bash
./bin/farci up 02-inference/llamacpp
```


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
| réponses très lentes (> 60 s) | CPU seul, gros modèle | `02-inference/ollama/create-model.sh secours` (même nom `med-extraction`, rien d'autre à changer) |
| toujours trop lent, ou Docker inutilisable | machine trop faible | le formateur lance `./bin/farci rescue inference` : la référence sert, vous continuez la suite du parcours |
