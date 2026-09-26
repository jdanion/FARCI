# Architecture

Ce document explique **pourquoi** l'architecture est ce qu'elle est. Pour le
« comment on démarre tout ça », voir les TUTORIAL de chaque équipe ; pour les
détails d'interface, voir `CONTRACTS.md`.

---

## 1. Le principe : une architecture par contrats

Le dépôt ne couple jamais une application à une technologie. Chaque couche est
remplaçable parce qu'elle est décrite par un **contrat** d'interface.

```
        APPLICATION  (Python / Open WebUI / Flowise)
             │
             │  contrat : API compatible OpenAI
             ▼
        ┌─────────────────────────────┐
        │  LLM GATEWAY                │
        │  LiteLLM   ou   Bifrost     │
        └──────────────┬──────────────┘
                       │  contrat : /v1/models, /v1/chat/completions
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      Ollama      llama.cpp       oMLX
          └────────────┼────────────┘
                       ▼
                  modèle local
```

Le client ne doit pas savoir quelle implémentation est utilisée. C'est vérifiable :
le même test contractuel passe avec LiteLLM **et** avec Bifrost, avec Ollama
**et** avec llama.cpp **et** avec oMLX.

Le même principe s'applique à l'observabilité :

```
   instrumenté une seule fois  ──OTLP──►  Phoenix
                                        └─►  Langfuse
```

Ce qui est enseigné n'est pas « Phoenix » ni « Langfuse », mais **OpenTelemetry**.

---

## 2. Le chemin complet d'un dossier patient

```
  PDF médical synthétique
        │  (datasets/raw/)
        ▼
     Docling                 mise en page, titres, tableaux
        │  texte structuré
        ▼
  Pseudonymisation          [PATIENT_001], [DATE_001]…
        │
        ▼
  LLM Gateway               alias med-extraction, clés virtuelles, quota
        │
        ▼
  Runtime d'inférence       modèle local, aucun appel sortant
        │
        ▼
  Structured output         JSON conforme au schéma
        │
        ▼
     Pydantic               validation stricte
        │
        ▼
  JSON / CSV                datasets/extracted/<équipe>/
        │
        ▼
  Gold standard             datasets/gold/
        │
        ▼
    Métriques               précision, rappel, F1, latence
        │
        ▼
      MLflow                 une expérience par configuration
```

Chaque flèche est un **contrat** testé. Si une flèche casse, un test le dit.

---

## 3. L'adresse stable : pourquoi Caddy

Les clients ne connaissent jamais les adresses physiques. Ils connaissent une
seule entrée :

```
http://192.168.50.15/v1        → la gateway
http://192.168.50.15/docling   → la chaîne documentaire
http://192.168.50.15/status    → l'état de tout le système
```

Conséquence directe : un client qui pointe vers Caddy fonctionne avec n'importe
quelle implémentation de gateway, de runtime ou d'observabilité. C'est ce qui rend
l'étape 3 possible sans toucher une ligne de code métier.

**Choix pédagogique assumé** : Caddy ne fait pas de répartition de charge entre
les deux gateways. La bascule se fait en rechargeant sa configuration, ce qui rend
la permutation visible en direct pendant l'atelier.

---

## 4. Qui possède quoi

| Couche | Question à laquelle elle répond | Implémentations |
|---|---|---|
| Runtime d'inférence | « qui calcule ? » | Ollama, llama.cpp, oMLX |
| Passerelle LLM | « qui décide, qui réessaie, qui mesure ? » | LiteLLM, Bifrost |
| Reverse proxy | « par où on entre ? » | Caddy |
| Chaîne documentaire | « comment lire un PDF ? » | Docling |
| Observabilité | « qu'est-ce qui s'est passé ? » | Phoenix, Langfuse |
| Évaluation | « est-ce que c'est bon ? » | MLflow + métriques |
| Registre | « quels services existe-t-il ? » | `config/services.yaml` |

---

## 5. Le registre des services

`config/services.yaml` est la **source de vérité**. Il décrit chaque service :
son équipe, son groupe de tableau de bord, la **variable** qui porte son adresse,
son port, ses chemins de santé, et s'il est indispensable au pipeline.

Deux règles en découlent :

1. **Le registre ne contient aucune adresse IP**, seulement des noms de variables.
   Les adresses sont dans `config/network.env`. Changer de sous-réseau ne demande
   donc qu'une édition de fichier unique — c'est ce qu'exige le cahier des charges.
2. **Plusieurs chemins de santé sont acceptés** par service, essayés dans l'ordre.
   Le même contrat s'appelle `/v1/models` chez llama.cpp et `/api/tags` chez
   Ollama : le client n'a pas à le savoir.

`./bin/farci services` lit ce registre ; `./bin/farci network-check` vérifie sa
cohérence avec les adresses.

---

## 6. Les deux modèles, un seul modèle logique

| | |
|---|---|
| **Modèle logique** | `med-extraction` — le seul nom que l'application voit |
| **Modèle physique** | Ornith-1.5-9B (par défaut) ou Qwen3.8-27B |
| **Runtime** | interchangeable : Ollama, llama.cpp, oMLX |

Trois notions distinctes à ne pas confondre :

- le **modèle** est un fichier de poids ;
- le **runtime** est le logiciel qui l'exécute ;
- la **passerelle** décide quel runtime sert quelle requête, avec quelles clés
  et quel quota.

Un même fichier de poids est monté par llama.cpp **et** importé par Ollama. Ce
n'est pas une économie de disque seulement : c'est ce qui rend valide la
comparaison des runtimes, puisque la seule variable qui change est le runtime.

---

## 7. Ce que l'observabilité ne doit jamais faire

Une perte de télémétrie ne doit pas arrêter l'extraction. L'observabilité est sur
le **chemin d'observation**, jamais sur le **chemin de production** :

- délais d'export courts (1 s) ;
- échec d'export silencieux et journalisé ;
- scénario de chaos n° 7 qui vérifie que le pipeline survit à la coupure.

C'est une distinction que l'on n'apprend pas dans un cours de théorie : on
l'apprend le jour où l'outil de supervision tombe pendant la production.

---

## 8. Ce qui n'est pas dans ce dépôt

| Absent | Pourquoi |
|---|---|
| Kubernetes | Le cahier des charges l'exclut, et à bon droit : les étudiants doivent **voir** les composants, pas les abstractions d'un contrôleur. |
| Base de données vectorielle | Le problème est de l'extraction structurée, pas de la recherche sémantique. L'ajouter brouillerait le message. |
| Un second moteur d'IA | L'objectif est de comparer des **architectures**, pas des modèles. |

---

## 9. Voir aussi

- `CONTRACTS.md` — les trois contrats, côte à côte
- `AIRGAP.md` — ce qui est préchargé et comment le vérifier
- `CHAOS.md` — les sept scénarios et leur résultat attendu
- `WORKSHOP_FLOW.md` — le déroulé des trois étapes
- `PLAN.md` — le plan d'implémentation complet, phase par phase
