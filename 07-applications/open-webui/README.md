# FARCI — parcours Open WebUI

## Démarrage

```bash
cd 07-applications/open-webui
docker compose up -d
./post-setup.sh
```

## Utilisation

1. Ouvrir http://192.168.50.60:8080
2. Se connecter avec `admin@farci.local` / `admin`
3. Sélectionner le modèle `med-extraction`
4. Coller le contenu d'un PDF et soumettre

## Export

```bash
./export-submissions.sh
```
