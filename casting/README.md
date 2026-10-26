# FARCI — Casting des équipes

Système de répartition des équipes en fonction du matériel des étudiants.

## Principe

1. **Rôles critiques d'abord** : les choix n°1 de chaque brique sont garantis
2. **Redondances ensuite** : les stacks alternatives sont assignées
3. **Stratification** : les étudiants les plus puissants sont assignés aux rôles les plus exigeants

## Utilisation

```bash
# Avec un fichier JSON d'étudiants
./bin/farci casting --students students.json --seed 42

# Exemple par défaut
./bin/farci casting

# Sans les rôles optionnels
./bin/farci casting --no-optional
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

Seules les options **fournies par le dépôt** (compose, configuration,
TUTORIAL) sont proposées.

| Rôle | Options (n°1 → n°2 → n°3) |
|---|---|
| GitOps | Gitea |
| Réseau | Caddy |
| Inférence | Ollama (GPU ou 32 Go) → llama.cpp (tout poste) |
| Gateway | LiteLLM → Bifrost |
| Documents | Docling (+ pseudonymisation) |
| Observabilité | Phoenix → Langfuse |
| Évaluation | MLflow |
| Applications | Python → Open WebUI |
| Agents Arcane | Arcane |
| Chaos (étape 3) | Chaos |

Alternatives **non fournies** (souvent citées, volontairement absentes) :
GitLab, Nginx, Traefik, PyMuPDF, Weights & Biases (service cloud, incompatible
avec l'air-gap), Portainer. Les ajouter demande un compose, une image
préchargée et un TUTORIAL : voir ci-dessous.

## Ajouter une option

Une option n'entre dans `casting/roles.py` qu'une fois livrée : compose dans
le dossier de l'équipe, image dans `scripts/lib/images.sh` et `versions.env`,
section dans le TUTORIAL. Ensuite :

```python
Role(
    name="inference",
    label="Inférence",
    options=[
        Option("ollama", "Ollama", min_ram_gb=8),
        Option("llamacpp", "llama.cpp", min_ram_gb=4),
        Option("llamacpp", "llama.cpp", min_ram_gb=4),
        Option("vllm", "vLLM", requires_gpu=True, min_vram_gb=8),  # ← nouvelle option
    ],
    ...
)
```

Le système est **agnostique** : il s'adapte automatiquement au nombre d'étudiants
et aux options disponibles.
