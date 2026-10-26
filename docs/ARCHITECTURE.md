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
  Dossier médical synthétique         datasets/raw/patient_<IPP>_{cro,crap,crscan,lettre}.txt
        │  (4 documents texte par patient, versionnés)
        ▼
  Concaténation                     un dossier = les 4 documents, dans l'ordre clinique
        │
        ▼
  Pseudonymisation                  [IPP_0], [NOM_0], [DATE_0]…  (04-clinical-documents)
        │
        ▼
  LLM Gateway (via l'accueil /v1)   alias med-extraction, repli, (bonus) clés et quota
        │
        ▼
  Runtime d'inférence               modèle local, aucun appel sortant
        │
        ▼
  Structured output                 JSON dans `content` (le raisonnement reste dans reasoning_content)
        │
        ▼
     Pydantic                       validation stricte — échec : RIEN n'est écrit
        │
        ▼
  JSON                              datasets/extracted/<run>/patient_<IPP>.json (+ _meta)
        │
        ▼
  Gold standard                     datasets/gold/  (écrit depuis le registre, jamais par un LLM)
        │
        ▼
    Métriques                       ./bin/farci evaluate : complétude, précision, rappel, F1, latence
        │
        ▼
      MLflow (bonus)                une expérience par configuration
```

**Pourquoi du texte et pas des PDF ?** Le dataset versionné est en `.txt` :
c'est le parcours assumé de l'atelier. Il est déterministe, léger, lisible
par tous, et ne dépend d'aucune brique lourde. Docling reste la brique de
l'équipe 4 : il convertit les **PDF** produits à la demande par
`./bin/farci generate-dataset --pdf` (dans `datasets/pdf/`, hors Git), ce
qui permet de montrer la conversion d'un document mis en page et de jouer le
scénario 05 (Docling tombe, le parcours texte continue).

Chaque flèche est un **contrat** testé. Si une flèche casse, un test le dit
(`./bin/farci test-unit`, `./bin/farci test`).

---

## 3. L'adresse stable : l'accueil de la salle

Les clients ne connaissent jamais les adresses physiques. Ils connaissent une
seule entrée, **l'accueil de la salle** : le Caddy du Raspberry Pi du
formateur, qui crée aussi le Wi-Fi.

```
http://<REFERENCE_IP>/v1              → la passerelle LLM
http://<REFERENCE_IP>/runtime/v1      → les runtimes (pour la passerelle, jamais les applications)
http://<REFERENCE_IP>/docling         → la chaîne documentaire
http://<REFERENCE_IP>/eds             → EDS-NLP : pseudonymiser, extraire des entités
http://<REFERENCE_IP>/observability   → les traces OTLP
http://<REFERENCE_IP>/status          → l'état de la salle
http://<REFERENCE_IP>/                → le tableau de la salle (écran projeté)
```

`REFERENCE_IP` et `ENTRY_PORT` viennent de `config/network.env` ;
`scripts/dev-env.sh` en dérive `FARCI_GATEWAY_URL`, `FARCI_RUNTIME_URL`,
`FARCI_DOCLING_URL`, `FARCI_EDS_URL`, `OTEL_EXPORTER_OTLP_ENDPOINT` et `FARCI_STATUS_URL`.
Aucun autre fichier ne compose d'adresse.

### Une IP de machine + un port par service

```
            portables des équipes (Wi-Fi du Pi, 192.168.50.0/24)
   ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
   │ équipe 2           │  │ équipe 3           │  │ équipe 4           │
   │ Ollama :11434      │  │ LiteLLM :4000      │  │ Docling :5001      │
   └─────────▲──────────┘  └─────────▲──────────┘  └─────────▲──────────┘
             │ 1er choix             │ 1er choix             │ 1er choix
   ┌─────────┴───────────────────────┴───────────────────────┴──────────┐
   │ Raspberry Pi 5 — REFERENCE_IP                                      │
   │  accueil Caddy :80 ── 2e choix ──► pile de référence (🛟)          │
   │                                    runtime rejoué, LiteLLM,        │
   │                                    Phoenix, Open WebUI             │
   └────────────────────────────────────────────────────────────────────┘
```

Une brique d'équipe est jointe par l'IP de la **machine** qui l'héberge et
le **port publié** du service ; chaque service a son propre port, donc
plusieurs briques peuvent cohabiter sur une machine. Le formateur déclare
les machines sur le Pi (`./bin/farci room set <équipe> <ip>`) ; les postes
étudiants ne connaissent que `REFERENCE_IP`.

### Le repli : équipe d'abord, référence ensuite

Pour chaque route, l'accueil essaie la brique de l'équipe, puis celle de la
référence (`lb_policy first` : l'ordre est une décision, pas une
répartition de charge). Une brique qui ne répond pas est écartée 20
secondes. Le tableau dit qui rend le service : `✅` l'équipe, `🛟` la
référence. Le formateur peut aussi **forcer** la référence
(`./bin/farci rescue <brique>`) quand une brique répond mal ; le chaos
utilise le même mécanisme (`docs/CHAOS.md`).

Conséquence directe : un client qui pointe vers l'accueil fonctionne avec
n'importe quelle implémentation de passerelle, de runtime ou
d'observabilité — et même quand une équipe n'a rien livré. C'est ce qui
rend l'étape 3 possible sans toucher une ligne de code métier.

**Plan C, sans aucun réseau** : `./bin/farci extract --replay` démarre un
runtime rejoué dans le processus même ; `./bin/farci replay` en lance un
sur le poste. Mêmes réponses, même contrat.

---

## 4. Qui possède quoi

| Couche | Question à laquelle elle répond | Implémentations |
|---|---|---|
| Runtime d'inférence | « qui calcule ? » | Ollama, llama.cpp, oMLX |
| Passerelle LLM | « qui décide, qui réessaie, qui mesure ? » | LiteLLM, Bifrost |
| Reverse proxy | « par où on entre, et qui répond ? » | Caddy (accueil de la salle et de l'équipe 1) |
| Chaîne documentaire | « comment lire un document, et que cacher au modèle ? » | Docling, pseudonymisation |
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
- `CHAOS.md` — les scénarios de panne et leur résultat attendu
- `WORKSHOP_FLOW.md` — le déroulé des trois étapes
- `PLAN.md` — le plan d'implémentation complet, phase par phase
