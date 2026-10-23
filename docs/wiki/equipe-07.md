# Équipe 7 — Applications

> Fiche débutant. La référence technique complète est
> `07-applications/TUTORIAL.md` (`./bin/farci read 7`).

## Votre objectif

Brancher **Open WebUI**, l'interface de discussion, sur la passerelle de la
salle : la ligne `Open WebUI` passe à `✅ UP`. C'est l'interface des
camarades qui n'ont pas de machine utilisable à l'étape 2.

## Les étapes

1. **Vérifier la machine** — `./bin/farci doctor` : notez « IP de cette
   machine » et « dépendances Python ».
2. **Démarrer** — `./bin/farci up 07-applications/open-webui`.
3. **Configurer** — `07-applications/open-webui/post-setup.sh`.
4. **Ouvrir l'interface** — dans un navigateur : `http://127.0.0.1:3080`.
   Le modèle `med-extraction` est proposé.
5. **Extraire un dossier à la main** — collez le prompt de
   `07-applications/open-webui/prompt.md`, puis le contenu d'un fichier de
   `datasets/raw/`. La réponse doit être un JSON.
6. **Vous déclarer** — donnez votre IP au formateur
   (`./bin/farci room set 7 <votre-ip>` sur le Pi).
7. **Le même dossier en Python** —
   `./bin/farci extract --subset quick --limit 1 --run equipe-7` : comparez
   avec la réponse d'Open WebUI.

## La sonde : comment savoir que c'est fini

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3080    # 200
```

Et sur l'écran de la salle : `Open WebUI ✅ UP`.

## Bloqué depuis 10 minutes ?

Levez la main. L'Open WebUI de la référence (🛟), sur le Pi, sert la salle
en attendant : `http://<REFERENCE_IP>:3080`.

| Ce que vous voyez | À essayer |
|---|---|
| aucun modèle proposé | `./bin/farci test` : `gateway-contract` doit être `PASS` |
| la page ne s'ouvre pas | `./bin/farci logs 07-applications/open-webui` ; le premier démarrage est long |
| `ModuleNotFoundError` en Python | `./bin/farci bootstrap` |
| beaucoup de `REJET` | le modèle ne respecte pas le schéma : essayez `--prompt v2` |

## Bonus

- Tout le jeu rapide en Python : `./bin/farci extract --subset quick --run equipe-7`,
  puis `./bin/farci evaluate --subset quick`.
- Exporter les extractions faites dans Open WebUI :
  `07-applications/open-webui/export-submissions.sh`.
