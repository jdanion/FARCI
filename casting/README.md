# FARCI — Casting des équipes

Système de répartition des équipes en fonction du matériel des étudiants.

## Principe

1. **Rôles critiques d'abord** : les choix n°1 de chaque brique sont garantis
2. **Redondances ensuite** : les stacks alternatives sont assignées
3. **Stratification** : les étudiants les plus puissants sont assignés aux rôles les plus exigeants

## Utilisation

```bash
# Avec un fichier JSON d'étudiants
python casting/casting.py --students students.json --seed 42

# Exemple par défaut
python casting/casting.py

# Sans les rôles optionnels
python casting/casting.py --no-optional
```

## Format du fichier étudiants

```json
[
  {"name": "Alice", "ram_gb": 32, "has_mac": true, "is_mac_studio": true},
  {"name": "Bob", "ram_gb": 16, "has_gpu": true, "vram_gb": 24},
  {"name": "Charlie", "ram_gb": 8}
]
```

## Rôles et options

| Rôle | Options (n°1 → n°2 → n°3) |
|---|---|
| GitOps | Gitea → GitLab |
| Réseau | Caddy → Nginx → Traefik |
| Inférence | Ollama → llama.cpp → oMLX (Mac) |
| Gateway | LiteLLM → Bifrost |
| Documents | Docling → PyMuPDF |
| Observabilité | Phoenix → Langfuse |
| Évaluation | MLflow → W&B |
| Applications | Python → Open WebUI → Flowise |
| Agents Arcane | Arcane → Portainer |
| Chaos | Chaos |

## Ajouter une option

Pour ajouter une option à un rôle, modifier `casting/roles.py` :

```python
Role(
    name="inference",
    label="Inférence",
    options=[
        Option("ollama", "Ollama", min_ram_gb=8),
        Option("llamacpp", "llama.cpp", min_ram_gb=4),
        Option("omlx", "oMLX", requires_mac=True, min_ram_gb=16),
        Option("vllm", "vLLM", requires_gpu=True, min_vram_gb=8),  # ← nouvelle option
    ],
    ...
)
```

Le système est **agnostique** : il s'adapte automatiquement au nombre d'étudiants
et aux options disponibles.
