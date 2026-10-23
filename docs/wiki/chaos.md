# Étape 3 — Chaos engineering (piloté par le formateur)

## Attendus pédagogiques

- Comprendre le chaos engineering et son intérêt
- Comprender la notion de résilience et de redondance
- Comprendre la différence entre un test de charge et un test de panne
- Comprendre l'importance des healthchecks
- Savoir interpréter les résultats d'un scénario de chaos

## Solution simple (scripts)

```bash
# 1. Lister les scénarios
./bin/farci chaos list

# 2. Appliquer un scénario (puis observer ./bin/farci status)
./bin/farci chaos scenario-01

# 3. Avec réparation automatique après 60 s
./bin/farci chaos scenario-01 --duration 60

# 4. Pannes actives, puis tout réparer
./bin/farci chaos status
./bin/farci chaos reset
```

## Solution from scratch

> Toutes les commandes se lancent depuis la racine du dépôt. Les adresses
> viennent de `config/network.env` : les charger d'abord avec
> `source scripts/dev-env.sh && farci_load_env` (ce qui définit
> `$CADDY_URL`, `$INFERENCE_A_URL`, `$DOCLING_URL`…).

### 1. Coupure manuelle d'un service

```bash
# Coupure d'Ollama
docker stop farci-ollama

# Vérifier que le gateway répond toujours
curl -X POST $FARCI_GATEWAY_URL/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-standard-xxx" \
  -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}]}'

# Restaurer
docker start farci-ollama
```

### 2. Test de rate limiting

```bash
# 12 requêtes rapides
for i in $(seq 1 12); do
  curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST $FARCI_GATEWAY_URL/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer sk-standard-xxx" \
    -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}'
done
# → certaines doivent retourner 429
```

### 3. Test de JSON invalide

```python
from common.schemas import ClinicalExtraction

# JSON valide
ClinicalExtraction(**{"patient_id": "123", "age": 67, ...})

# JSON invalide → ValidationError
try:
    ClinicalExtraction(**{"patient_id": "123"})  # champs manquants
except ValidationError as e:
    print(f"Validation échouée: {e}")
```

### 4. Interpréter les résultats

| Scénario | Attendu | Interprétation |
|---|---|---|
| 01 | gateway 200 + fallback | redondance active |
| 02 | pipeline 🔴 | dépendance critique |
| 03 | 429 + Retry-After | rate limiting actif |
| 04 | ValidationError | validation obligatoire |
| 05 | document 🔴, gateway 🟢 | dépendance partielle |
| 06 | bascule gateway | client inchangé |
| 07 | extraction OK, traces perdues | observabilité ≠ production |

## Vérifications

- [ ] Les 7 scénarios sont documentés
- [ ] Chaque scénario a un attendu vérifiable
- [ ] Le reset fonctionne
