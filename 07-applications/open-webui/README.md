# FARCI — parcours Open WebUI

Interface de chat branchée sur la passerelle via Caddy (`/v1`) : l'étudiant
expérimente le prompt et les paramètres sans écrire de code. C'est aussi la
porte d'entrée des étudiants sans machine utilisable (Open WebUI de la pile
du formateur).

## Démarrage (depuis la racine du dépôt)

```bash
./bin/farci up 07-applications/open-webui
07-applications/open-webui/post-setup.sh
```

L'adresse est `OPEN_WEBUI_IP:OPEN_WEBUI_PORT` (`config/network.env`), ou
`/webui` derrière Caddy.

## Utilisation

1. Se connecter (compte créé par `post-setup.sh`).
2. Choisir le modèle `med-extraction`.
3. Coller le prompt `07-applications/open-webui/prompt.md`, puis le contenu
   d'un dossier patient (`datasets/raw/patient_<IPP>_*.txt`).

## Export vers l'évaluation

```bash
07-applications/open-webui/export-submissions.sh
```

Les réponses JSON valides sont écrites dans `datasets/extracted/webui/` et
évaluées comme les autres parcours (`./bin/farci evaluate`).
