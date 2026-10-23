# Déroulé du workshop

Trois étapes, neuf dossiers d'équipe (`00-gitops/` à `08-arcane-agents/`). L'étape 3
(chaos) n'est pas une équipe : elle se joue ensemble. L'ordre compte : chaque
étape dépend de la précédente.

---

## Vue d'ensemble

```
ÉTAPE 1 — CONSTRUIRE ENSEMBLE L'INFRASTRUCTURE
  les équipes montent leur brique, le tableau se remplit
  🔴 🔴 🔴 🔴 🔴 🔴 🔴   →   🟢 🟢 🟢 🟢 🟢 🟢 🟢
  │
  │  quand « CLINICAL PIPELINE » passe à READY
  ▼
ÉTAPE 2 — UN MÊME PROBLÈME POUR TOUT LE MONDE
  extraire des variables structurées de documents médicaux
  trois parcours au choix, un seul résultat attendu
  │
  │  quand chaque équipe a ses extractions notées
  ▼
ÉTAPE 3 — PROVOQUER DES PANNES ET OBSERVER
  on casse, on regarde les traces, on vérifie le repli
```

---

## Les équipes

| Équipe | Dossier | Brique | Indispensable ? |
|---|---|---|---|
| 0 | `00-gitops/` | Gitea + runner + CI | non (bonus) |
| 1 | `01-network-dashboard/` | Caddy, agrégateur de santé (Uptime Kuma en bonus) | oui |
| 2 | `02-inference/` | Ollama (llama.cpp, oMLX en bonus) | oui (au moins un runtime) |
| 3 | `03-llm-gateway/` | LiteLLM (Bifrost en bonus) | oui |
| 4 | `04-clinical-documents/` | Docling, pseudonymisation | oui |
| 5 | `05-observability/` | Phoenix (Langfuse en bonus) | oui |
| 6 | `06-evaluation/` | métriques (MLflow en bonus) | non : l'évaluation se fait en ligne de commande |
| 7 | `07-applications/` | Python, Open WebUI, Flowise | à l'étape 2 |
| 8 | `08-arcane-agents/` | agents de supervision, webhook GitOps | non (bonus) |

`config/services.yaml` fait foi : la ligne `CLINICAL PIPELINE` ne dépend que
des services marqués `critical: true`.

Une équipe n'est **pas** terminée tant que sa sonde n'est pas verte sur le
tableau de bord. Le tableau est projeté en plein écran : c'est lui qui montre à
tous que le système se construit.

---

## Étape 1 — Construire l'infrastructure

Pour chaque équipe :

1. copier la configuration, vérifier la machine ;
2. créer une branche ;
3. déployer la brique ;
4. lancer son **test contractuel** ;
5. ouvrir une Pull Request, la faire relire et intégrer ;
6. vérifier que la sonde passe au vert.

En parallèle, l'animateur fait vivre le tableau de bord :

```bash
./bin/farci status --watch
```

Le passage de `CLINICAL PIPELINE: NOT READY` à `READY` est le **moment** de
l'étape 1. Avant, le pipeline n'est pas utilisable : il doit le devenir.

### Ordre de dépendances conseillé

```
  équipe 0 (GitOps)  ─┬─► équipe 1 (réseau + tableau)
                      │        │
                      │        ├─► équipe 2 (inférence)
                      │        │      └─► équipe 3 (gateway)
                      │        │             └─► équipe 7 (applications)
                      │        ├─► équipe 4 (documents)
                      │        └─► équipe 5 (observabilité)
                      │               └─► équipe 6 (évaluation)
```

L'équipe 1 est le point de convergence : rien ne peut être sondé ni exposé
avant elle.

---

## Étape 2 — Le même problème, trois interfaces

**Le problème** : à partir de documents médicaux synthétiques, extraire des
variables structurées de recherche clinique, et les comparer à une référence.

**Ce qui est commun à tous** : le jeu de données, le schéma, la passerelle, le
modèle logique `med-extraction`, le gold standard.

**Ce qui diffère** : l'interface.

| Parcours | Dossier | Pour qui |
|---|---|---|
| A — Python | `07-applications/python/` | recommandé : c'est là qu'on comprend le fonctionnement |
| B — Open WebUI | `07-applications/open-webui/` | moins technique : on expérimente les paramètres |
| C — Flowise | `07-applications/flowise/` | on visualise l'orchestration |

Les trois produisent `datasets/extracted/<équipe>/<patient>.json` avec **exactement
le même schéma**. C'est ce qui rend la comparaison finale possible.

### Le résultat qui compte

```bash
./bin/farci evaluate        # ou : make evaluate
```

Compare les extractions au gold standard et affiche : nombre de dossiers,
complétude, JSON valides, exactitude champ par champ, précision, rappel, F1,
latence moyenne.

Puis on regarde le même appel dans Phoenix ou Langfuse, et on comprend que la
trace et le score racontent la même histoire de deux façons.

---

## Étape 3 — Casser la plateforme

Sept scénarios, chacun **réversible**. Voir `CHAOS.md` pour le détail.

```bash
./bin/farci chaos list          # les scénarios disponibles
./bin/farci chaos scenario-01   # on casse
./bin/farci chaos status        # ce qui est encore cassé
./bin/farci chaos reset         # on répare
```

Le but n'est pas de tout casser : c'est de vérifier que **le pipeline continue
de fonctionner là où l'architecture le prévoit**, et qu'il s'explique clairement
là où elle ne le prévoit pas.

| Scénario | Ce qu'on casse | Ce qu'on doit observer |
|---|---|---|
| 01 | runtime primaire | repli sur le secondaire, client inchangé |
| 02 | runtime secondaire | le pipeline passe au rouge : on sait pourquoi |
| 03 | limite de débit | 429 + `Retry-After` sur la clé standard |
| 04 | sortie JSON invalide | validation qui refuse d'écrire |
| 05 | Docling | dépendance partielle : le reste tient |
| 06 | gateway A | bascule vers B, sans changer d'adresse |
| 07 | observabilité | l'extraction continue : la télémétrie n'est pas critique |

---

## Ce que chaque étudiant doit savoir expliquer à la fin

- la différence entre un LLM, un runtime, une passerelle, un proxy, une
  application, une observabilité, une évaluation, GitOps, DevOps et LLMOps ;
- pourquoi une extraction de données médicales pour la recherche clinique
  nécessite **toutes** ces couches, et pas seulement un modèle ;
- pourquoi on ne peut pas faire confiance à une sortie de LLM sans validation ;
- pourquoi une performance sans référence ne veut rien dire.

---

## Voir aussi

- `docs/INSTRUCTOR_GUIDE.md` — la logistique et les checklists
- `docs/ARCHITECTURE.md` — pourquoi cette architecture
- `docs/CONTRACTS.md` — les trois contrats
- `docs/CHAOS.md` — les scénarios détaillés
- `docs/AIRGAP.md` — le fonctionnement sans Internet
