# Équipe 2 — Inférence

> Fiche débutant. La référence technique complète est
> `02-inference/TUTORIAL.md` (`./bin/farci read 2`).

## Votre objectif

Faire tourner **un modèle de langage sur votre machine** (Ollama) et le
servir sous le nom `med-extraction` : la ligne `Inference` passe de
`🛟 REF` à `✅ UP`.

Le modèle est le fichier de connaissances, le runtime est le logiciel qui
le lit : comme un livre et la personne qui le lit à voix haute.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez la RAM et la ligne
   « IP de cette machine ».
2. **Vérifier les poids** — `./bin/farci verify-models` : au minimum le
   modèle de secours `Qwen3.5-2B` doit être présent.
3. **Démarrer le runtime** — `./bin/farci up 02-inference/ollama`.
4. **Importer le modèle** — `02-inference/ollama/create-model.sh`. Il choisit
   seul : le modèle principal (9B) si la machine a 16 Go de RAM ou plus,
   sinon le modèle de secours (2B). Le nom servi est **toujours**
   `med-extraction`.
5. **Tester chez vous** — `./bin/farci test` : la ligne `inference-contract`
   doit être `PASS`.
6. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set 2 <votre-ip>` sur le Pi).
7. **Regarder l'écran projeté** — la ligne `Inference` passe à `✅ UP` : la
   salle utilise maintenant **votre** modèle.

## La sonde : comment savoir que c'est fini

```bash
./bin/farci test        # inference-contract   PASS   http://127.0.0.1:11434/v1
```

Et sur l'écran de la salle : `Inference ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. La salle ne vous attend pas : le runtime de la référence
(🛟) répond à votre place.

| Ce que vous voyez | À essayer |
|---|---|
| le conteneur s'arrête, `out of memory` | `02-inference/ollama/create-model.sh secours` (même nom, modèle plus petit) |
| `create-model.sh` : GGUF manquant | `./bin/farci verify-models` ; demander la clé USB au formateur |
| une réponse prend plus d'une minute | normal sur un petit processeur : le formateur peut lancer `./bin/farci rescue inference`, vous continuez à comprendre |
| Docker absent ou cassé | travaillez en binôme sur la machine d'une autre équipe |

## Bonus

- llama.cpp sur le **même** fichier GGUF : `./bin/farci up 02-inference/llamacpp`.
- Mesurer : `02-inference/bench/bench.sh` (même modèle, runtime différent).
- Mac Apple Silicon : oMLX, `02-inference/omlx/README.md`.
