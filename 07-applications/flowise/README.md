# FARCI — parcours Flowise (démonstration du formateur)

Flowise montre l'orchestration sous forme de graphe : document → Docling →
prompt → LLM → validation. Pendant l'atelier, c'est une **démonstration**
du formateur, pas un parcours noté.

## Démarrage (depuis la racine du dépôt)

```bash
./bin/farci up 07-applications/flowise
```

L'adresse est `FLOWISE_IP:FLOWISE_PORT` (`config/network.env`), ou
`/flowise` derrière Caddy.

## Le flow

`07-applications/flowise/flowise.json` est un **schéma illustratif** du
graphe, pas un export importable tel quel : les nœuds sont à recréer dans
l'éditeur (Document → requête HTTP Docling sur `FARCI_DOCLING_URL` → prompt
`07-applications/common/prompts/extraction_v1.md` → modèle `med-extraction`
via `FARCI_GATEWAY_URL`). À valider sur la machine du formateur avant la
séance.

## Export

Copier chaque JSON de sortie dans `datasets/extracted/flowise/patient_<IPP>.json`,
puis `./bin/farci evaluate`.
