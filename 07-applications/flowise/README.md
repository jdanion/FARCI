# FARCI — parcours Flowise

## Démarrage

```bash
cd 07-applications/flowise
docker compose up -d
```

## Import du flow

1. Ouvrir http://192.168.50.61:3000
2. Se connecter avec `admin` / `farci-admin`
3. Importer `flowise.json`

## Utilisation

1. Téléverser un PDF
2. Le pipeline : Docling → Prompt → LLM → Validation
3. Le JSON validé est affiché

## Export

Copier le JSON de sortie vers `datasets/extracted/flowise/`.
