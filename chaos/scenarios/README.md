# FARCI — Scénarios de chaos engineering

| # | Action | Assertion automatique | Leçon |
|---|---|---|---|
| 01 | stop runtime primaire | gateway 200, en-tête fallback, client inchangé | redondance active |
| 02 | stop runtime secondaire | Kuma `CLINICAL AI PIPELINE` 🔴, gateway 503 documenté | le pipeline n'est résilient que si *tous* les niveaux le sont |
| 03 | 12 requêtes en 2 s avec `sk-standard` | ≥1 × **429** + `Retry-After` ; `sk-priority` 200 | le débit est une propriété du gateway, pas du modèle |
| 04 | modèle renvoie un JSON hors schéma | Pydantic `ValidationError` journalisée, **aucun** fichier écrit | validation obligatoire |
| 05 | stop Docling | pipeline document 🔴, gateway 🟢, inference 🟢 | dépendance partielle |
| 06 | stop gateway A | bascule vers B via Caddy, toujours `http://192.168.50.15/v1` | le client ne change qu'un endpoint logique |
| 07 | stop Phoenix/Langfuse | extraction **réussie**, traces perdues uniquement | observabilité ≠ chemin de production |

## Utilisation

```bash
./chaos/chaos.sh scenario-01           # appliquer
./chaos/chaos.sh scenario-01 --duration 60  # auto-revert après 60s
./chaos/chaos.sh status                # état actuel
./chaos/chaos.sh reset                 # tout restaurer
```
