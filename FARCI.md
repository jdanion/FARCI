# PROMPT D’INSTRUCTIONS POUR AGENT CODEUR
# Projet FARCI

> **FARCI** — **F**orge & **A**gents en **R**éseau pour le **C**alcul d’**I**nférence

---

# 0. RÔLE DE L’AGENT

Tu es un **ingénieur senior DevOps / GitOps / LLMOps spécialisé dans les architectures d’IA locales, reproductibles et observables**.

Ta mission est de générer **l’intégralité d’un dépôt Git fonctionnel** permettant d’animer un workshop destiné principalement à des **étudiants en médecine**.

Le workshop doit leur permettre de comprendre progressivement :

1. ce qu’est un modèle de langage ;
2. la différence entre un **modèle**, un **runtime d’inférence**, une **LLM Gateway**, une **application cliente** et une **plateforme d’observabilité** ;
3. pourquoi une application d’IA ne se résume pas à appeler un LLM ;
4. pourquoi une utilisation scientifique nécessite :
   - versioning ;
   - validation ;
   - évaluation ;
   - observabilité ;
   - reproductibilité ;
   - gouvernance des données ;
5. comment plusieurs outils peuvent remplir la même fonction dans une architecture ;
6. comment construire un pipeline de recherche clinique capable d’extraire des variables structurées à partir de documents médicaux ;
7. comment vérifier la résilience d’une telle infrastructure en provoquant volontairement des pannes.

Le dépôt doit privilégier :

- la **lisibilité pédagogique** ;
- la **modularité** ;
- les standards ouverts ;
- les API compatibles OpenAI ;
- OpenTelemetry pour la télémétrie ;
- Docker Compose pour le déploiement ;
- une utilisation **entièrement locale après préchargement**.

---

# 1. OBJECTIF PÉDAGOGIQUE GLOBAL

Le workshop suit obligatoirement **trois étapes successives**.

---

# ÉTAPE 1 — CONSTRUIRE ENSEMBLE L’INFRASTRUCTURE IA

Tous les étudiants participent à la construction de l’infrastructure.

Ils sont répartis en équipes responsables d’une **fonction architecturale**.

Chaque équipe :

1. clone le dépôt depuis Gitea ;
2. crée une branche Git ;
3. configure ou déploie sa brique ;
4. exécute les tests contractuels ;
5. ouvre une Pull Request ;
6. fait intégrer sa contribution ;
7. vérifie que son service apparaît **UP** sur le dashboard central.

Le dashboard doit progressivement passer de :

```text
🔴 🔴 🔴 🔴 🔴 🔴 🔴
```

à :

```text
🟢 🟢 🟢 🟢 🟢 🟢 🟢
```

L’infrastructure complète ne doit être utilisable que lorsque les composants indispensables sont disponibles.

---

# ÉTAPE 2 — CONSTRUIRE UNE APPLICATION DE RECHERCHE CLINIQUE

Une fois l’infrastructure collective fonctionnelle, chaque étudiant choisit **une interface de développement**.

Trois parcours doivent être disponibles :

```text
Python
Open WebUI
Flowise
```

Tous les étudiants doivent résoudre **le même problème clinique** :

> Extraire automatiquement des variables structurées de recherche clinique à partir d’un ensemble de documents médicaux synthétiques.

Le moteur, la gateway et l’observabilité utilisés sont ceux construits collectivement pendant l’étape 1.

---

# ÉTAPE 3 — CHAOS ENGINEERING ET RÉSILIENCE

Une fois les applications fonctionnelles :

1. des services sont arrêtés volontairement ;
2. des limites de débit sont introduites ;
3. des sorties LLM invalides sont provoquées ;
4. certains moteurs d’inférence deviennent indisponibles ;
5. les étudiants doivent observer :
   - les erreurs ;
   - les traces ;
   - les fallbacks ;
   - les métriques ;
   - la récupération du système.

Le pipeline clinique doit continuer à fonctionner chaque fois que l’architecture prévoit une solution de secours.

---

# 2. PRINCIPE FONDAMENTAL : ARCHITECTURE PAR CONTRATS

Ne jamais coupler directement une application à une technologie particulière lorsque plusieurs implémentations sont prévues.

L’architecture doit être construite autour de **contrats d’interface**.

Exemple :

```text
                     APPLICATION
                          │
                          ▼
                 contrat OpenAI API
                          │
              ┌───────────┴───────────┐
              │                       │
          LiteLLM                  Bifrost
```

Le client ne doit pas avoir à savoir quelle implémentation est utilisée.

Même principe pour l’inférence :

```text
                  contrat inference
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Ollama        llama.cpp         oMLX
```

Et pour l’observabilité :

```text
                OpenTelemetry / OTLP
                         │
                  ┌──────┴──────┐
                  ▼             ▼
               Phoenix       Langfuse
```

---

# 3. ARCHITECTURE LOGIQUE À PRODUIRE

```text
                         UTILISATEUR
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
       Python            Open WebUI            Flowise
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                              ▼
                            Caddy
                         Reverse Proxy
                              │
                              ▼
                  ┌──────────────────────┐
                  │     LLM GATEWAY      │
                  │                      │
                  │ LiteLLM  OU Bifrost  │
                  └──────────┬───────────┘
                             │
             ┌───────────────┼───────────────┐
             │               │               │
             ▼               ▼               ▼
          Ollama         llama.cpp          oMLX
                                            Mac
             │               │               │
             └───────────────┼───────────────┘
                             │
                             ▼
                         modèle local
```

Pipeline de recherche clinique :

```text
documents médicaux
        │
        ▼
      Docling
        │
        ▼
texte structuré
        │
        ▼
pseudonymisation
        │
        ▼
 LLM Gateway
        │
        ▼
structured output
        │
        ▼
    Pydantic
        │
        ▼
 JSON / CSV
        │
        ▼
Gold Standard
        │
        ▼
évaluation
        │
        ▼
     MLflow
```

Observabilité :

```text
Application
    │
    ▼
OpenTelemetry
    │
    ├──────────► Phoenix
    │
    └──────────► Langfuse
```

GitOps :

```text
modification
    │
    ▼
git commit
    │
    ▼
Pull Request
    │
    ▼
Gitea Actions
    │
    ├── tests
    ├── contrats API
    ├── évaluation
    └── validation
```

---

# 4. TOPOLOGIE RÉSEAU

Sous-réseau pédagogique :

```text
192.168.50.0/24
```

Adresses conventionnelles :

| Fonction | IP conventionnelle |
|---|---|
| Gitea / GitOps | `192.168.50.10` |
| Caddy | `192.168.50.15` |
| Inference A | `192.168.50.20` |
| Inference B | `192.168.50.21` |
| Inference C / Mac | `192.168.50.22` |
| LLM Gateway A | `192.168.50.30` |
| LLM Gateway B | `192.168.50.31` |
| Observability A | `192.168.50.40` |
| Observability B | `192.168.50.41` |
| Docling | `192.168.50.46` |
| MLflow | `192.168.50.47` |
| Uptime Kuma | `192.168.50.50` |

Les IP doivent être facilement modifiables dans :

```text
.env
```

ou :

```text
config/network.env
```

Aucune IP ne doit être répétée inutilement dans le code source.

---

# 5. ARBORESCENCE ATTENDUE

Créer :

```text
farci/
│
├── README.md
├── Makefile
├── bootstrap.sh
├── preload.sh
├── verify-airgap.sh
├── versions.env
├── .env.example
│
├── config/
│   ├── network.env.example
│   ├── workshop.env.example
│   └── services.yaml
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── WORKSHOP_FLOW.md
│   ├── AIRGAP.md
│   ├── CONTRACTS.md
│   ├── CHAOS.md
│   └── INSTRUCTOR_GUIDE.md
│
├── 00-gitops/
│   ├── gitea/
│   ├── runner/
│   ├── docker-compose.yml
│   └── TUTORIAL.md
│
├── 01-network-dashboard/
│   ├── caddy/
│   ├── uptime-kuma/
│   ├── docker-compose.yml
│   ├── monitors/
│   └── TUTORIAL.md
│
├── 02-inference/
│   ├── CONTRACT.md
│   ├── ollama/
│   ├── llamacpp/
│   ├── omlx/
│   └── TUTORIAL.md
│
├── 03-llm-gateway/
│   ├── CONTRACT.md
│   ├── litellm/
│   ├── bifrost/
│   └── TUTORIAL.md
│
├── 04-clinical-documents/
│   ├── docling/
│   ├── deidentification/
│   ├── schemas/
│   └── TUTORIAL.md
│
├── 05-observability/
│   ├── CONTRACT.md
│   ├── phoenix/
│   ├── langfuse/
│   └── TUTORIAL.md
│
├── 06-evaluation/
│   ├── mlflow/
│   ├── metrics/
│   ├── gold-standard/
│   └── TUTORIAL.md
│
├── 07-applications/
│   ├── common/
│   ├── python/
│   ├── open-webui/
│   ├── flowise/
│   └── TUTORIAL.md
│
├── datasets/
│   ├── raw/
│   ├── pseudonymized/
│   ├── gold/
│   └── extracted/
│
├── chaos/
│   ├── chaos.sh
│   ├── scenarios/
│   └── TUTORIAL.md
│
├── tests/
│   ├── test_gitops.sh
│   ├── test_network.sh
│   ├── test_inference_contract.sh
│   ├── test_gateway_contract.sh
│   ├── test_docling.sh
│   ├── test_observability.sh
│   ├── test_structured_output.py
│   ├── test_failover.sh
│   └── test_airgap.sh
│
└── .gitea/
    └── workflows/
        ├── tests.yml
        ├── evaluate.yml
        └── integration.yml
```

---

# 6. VERSIONING DES DÉPENDANCES

Ne jamais utiliser `latest` dans le dépôt final.

Créer :

```text
versions.env
```

contenant toutes les versions utilisées.

Exemple conceptuel :

```bash
GITEA_VERSION=...
CADDY_VERSION=...
LITELLM_VERSION=...
BIFROST_VERSION=...
OLLAMA_VERSION=...
PHOENIX_VERSION=...
LANGFUSE_VERSION=...
DOCLING_VERSION=...
UPTIME_KUMA_VERSION=...
MLFLOW_VERSION=...
FLOWISE_VERSION=...
OPEN_WEBUI_VERSION=...
```

Lorsque possible :

- utiliser un tag fixe ;
- enregistrer également le digest SHA256 Docker ;
- fournir un script permettant de vérifier les images.

---

# 7. MODE ONLINE ET MODE AIR-GAPPED

Le système possède deux phases techniques distinctes.

---

## 7.1. Mode PRELOAD ONLINE

Cette phase est réalisée **avant le workshop** avec accès Internet.

Commande :

```bash
./preload.sh --all
```

Elle doit télécharger tout ce qui sera nécessaire.

---

## 7.2. Mode AIR-GAPPED

Pendant le workshop :

```text
AUCUN accès Internet public ne doit être requis.
```

La plateforme doit continuer à fonctionner si :

```bash
curl https://example.com
```

échoue.

Créer :

```bash
./verify-airgap.sh
```

qui vérifie que tous les artefacts nécessaires sont disponibles localement.

---

# 8. ARTEFACTS À PRÉCHARGER AVANT LE WORKSHOP

Le script :

```text
preload.sh
```

doit pouvoir précharger sélectivement les composants.

Options minimales :

```text
--all
--core
--gitops
--dashboard
--inference-ollama
--inference-llamacpp
--gateway-litellm
--gateway-bifrost
--observability-phoenix
--observability-langfuse
--documents
--evaluation
--client-python
--client-webui
--client-flowise
```

---

## 8.1. Images Docker indispensables

Précharger au minimum les images nécessaires à :

```text
Gitea
Gitea Runner
Caddy
Uptime Kuma
LiteLLM
Bifrost
Ollama
llama.cpp
Docling Serve
Phoenix
Langfuse
MLflow
Open WebUI
Flowise
Redis si requis
PostgreSQL si requis
```

Les implémentations optionnelles ne sont téléchargées que si demandées.

---

# 9. MODÈLES IA À PRÉCHARGER

Choisir au moins un modèle principal commun à l’ensemble du workshop.

Critères :

- open-weight ;
- taille raisonnable ;
- français acceptable ;
- structured output correct ;
- compatible CPU ou petits GPU ;
- licence compatible avec l’usage pédagogique.

Prévoir idéalement deux tailles.

Exemple conceptuel :

```text
small:
~1–2B paramètres

medium:
~3–4B paramètres
```

Fournir selon les runtimes :

```text
Ollama format
GGUF pour llama.cpp
MLX pour oMLX
```

Le README doit expliquer explicitement :

```text
modèle ≠ runtime
```

Un même modèle logique peut être servi par plusieurs runtimes.

---

# 10. PAQUETS PYTHON À PRÉCHARGER

Créer :

```text
offline/wheels/
```

Le script online doit exécuter un équivalent de :

```bash
pip download -r requirements.txt -d offline/wheels/
```

Pendant le workshop :

```bash
pip install \
  --no-index \
  --find-links=offline/wheels \
  -r requirements.txt
```

Paquets minimaux :

```text
openai
pydantic
requests
pandas
scikit-learn
opentelemetry-api
opentelemetry-sdk
pytest
```

Ajouter uniquement les bibliothèques réellement nécessaires.

---

# 11. ÉQUIPE 0 — GITOPS / GOUVERNANCE

Responsabilité :

```text
Forge Git + CI
```

Outils :

```text
Gitea
Gitea Actions / Runner
```

Livrables :

```text
00-gitops/
```

L’équipe doit :

1. démarrer Gitea ;
2. créer l’organisation :

```text
FARCI
```

3. créer le dépôt ;
4. protéger la branche :

```text
main
```

5. interdire les pushs directs ;
6. imposer les Pull Requests ;
7. activer Gitea Actions ;
8. connecter un runner ;
9. exécuter un workflow simple.

Les étudiants doivent comprendre :

```text
Git = versioning
Pull Request = revue
Actions = automatisation
GitOps = infrastructure pilotée par le dépôt
```

---

# 12. ÉQUIPE 1 — RÉSEAU ET DASHBOARD

Responsabilité :

```text
accès réseau + visualisation de la construction
```

Outils :

```text
Caddy
Uptime Kuma
```

## Caddy

Expose une interface stable :

```text
http://ai.local/
```

Routes :

```text
/v1/*
/docling/*
/observability/*
/mlflow/*
/healthz
```

L’objectif est que les clients ne connaissent pas les IP physiques.

---

# 13. DASHBOARD UPTIME KUMA

Le dashboard joue un rôle pédagogique majeur.

Il doit être projetable en plein écran dans l’amphithéâtre.

Créer des groupes :

```text
CORE INFRASTRUCTURE
AI RUNTIMES
LLM GATEWAYS
DOCUMENT PIPELINE
OBSERVABILITY
RESEARCH PIPELINE
CLIENT APPLICATIONS
```

Sondes minimales :

```text
Gitea
Caddy
Inference A
Inference B
Inference C
Gateway A
Gateway B
Docling
Observability A
Observability B
MLflow
Open WebUI
Flowise
```

Chaque moniteur doit afficher :

```text
DOWN
PENDING
UP
```

selon son état.

Au début de l’étape 1 :

```text
Gitea       🟢
Caddy       🔴
Inference   🔴
Gateway     🔴
Docling     🔴
Tracing     🔴
MLflow      🔴
```

Puis progressivement :

```text
Gitea       🟢
Caddy       🟢
Inference   🟢
Gateway     🟢
Docling     🟢
Tracing     🟢
MLflow      🟢
```

Quand tous les composants obligatoires sont disponibles, afficher un moniteur synthétique :

```text
CLINICAL AI PIPELINE
```

en :

```text
🟢 READY
```

---

# 14. MONITEUR SYNTHÉTIQUE

Créer un service :

```text
health-aggregator
```

ou un script HTTP minimal :

```text
/status
```

qui vérifie :

```text
Caddy
Gateway
au moins 1 runtime
Docling
Observability
```

et retourne :

```json
{
  "status": "ready"
}
```

uniquement si la chaîne minimale est fonctionnelle.

Uptime Kuma doit surveiller ce endpoint.

---

# 15. ÉQUIPE 2 — MODEL SERVING / INFERENCE

Responsabilité :

```text
exécuter le modèle
```

Trois implémentations possibles.

---

## OPTION 2A — OLLAMA

Adapté aux étudiants débutants.

Responsabilités :

- démarrer Ollama ;
- précharger le modèle ;
- exposer le service ;
- vérifier l’inférence ;
- documenter CPU/GPU.

---

## OPTION 2B — LLAMA.CPP

Objectif pédagogique supplémentaire :

- GGUF ;
- quantification ;
- contexte ;
- CPU/GPU ;
- mémoire.

Utiliser :

```text
llama-server
```

avec API compatible OpenAI.

---

## OPTION 2C — oMLX

Réservé aux machines :

```text
Apple Silicon
```

Permet de montrer :

```text
MLX
unified memory
Apple GPU
```

Ne doit pas être obligatoire pour le fonctionnement global.

---

# 16. CONTRAT INFERENCE

Créer :

```text
02-inference/CONTRACT.md
```

Toute implémentation doit fournir au minimum :

```http
GET /v1/models
POST /v1/chat/completions
```

Créer :

```bash
tests/test_inference_contract.sh
```

Le test reçoit :

```text
BASE_URL
```

et doit fonctionner indépendamment du runtime.

Exemple :

```bash
BASE_URL=http://192.168.50.20:8080/v1 \
./tests/test_inference_contract.sh
```

---

# 17. ÉQUIPE 3 — LLM GATEWAY

Responsabilité :

```text
abstraction + sécurité + routage + fallback
```

Deux implémentations possibles.

---

## OPTION 3A — LITELLM

Fonctions à montrer :

```text
OpenAI-compatible API
model alias
virtual keys
rate limiting
routing
retry
fallback
logging
```

Créer un modèle logique :

```text
med-extraction
```

L’application ne doit jamais connaître le vrai modèle.

---

## OPTION 3B — BIFROST

Doit fournir le même rôle fonctionnel :

```text
OpenAI-compatible gateway
routing
fallback
virtualisation des providers
rate limiting
observabilité
```

---

# 18. CONTRAT LLM GATEWAY

Créer :

```text
03-llm-gateway/CONTRACT.md
```

Interface minimale :

```http
GET /v1/models
POST /v1/chat/completions
```

Authentification :

```http
Authorization: Bearer <virtual-key>
```

Le modèle visible par les applications doit être :

```text
med-extraction
```

Créer :

```bash
test_gateway_contract.sh
```

Le test doit fonctionner aussi bien avec :

```text
LiteLLM
```

qu’avec :

```text
Bifrost
```

---

# 19. FALLBACK OBLIGATOIRE

Configurer :

```text
primary runtime
        │
        X panne
        │
        ▼
secondary runtime
```

Exemple :

```text
Ollama
   ↓ failure
llama.cpp
```

Le client ne doit pas changer son URL.

---

# 20. ÉQUIPE 4 — DOCUMENTS CLINIQUES

Responsabilité :

```text
documents → information exploitable
```

Outil principal :

```text
Docling
```

Fournir :

```text
POST /v1/convert/file
```

Le pipeline doit convertir :

```text
PDF
    ↓
Markdown / texte structuré
```

Les étudiants doivent pouvoir inspecter :

- paragraphes ;
- titres ;
- tableaux ;
- texte extrait.

---

# 21. PSEUDONYMISATION

Créer un module :

```text
deidentification/
```

remplaçant dans les données synthétiques :

```text
nom
prénom
date de naissance
IPP
NIR
adresse
téléphone
email
```

par des tokens :

```text
[PATIENT_001]
[DATE_001]
[IPP_001]
```

Le pipeline devient :

```text
PDF
 ↓
Docling
 ↓
texte
 ↓
pseudonymisation
 ↓
LLM
```

---

# 22. ÉQUIPE 5 — OBSERVABILITÉ LLM

Responsabilité :

```text
voir ce qui se passe dans le système
```

Deux solutions interchangeables.

---

## OPTION 5A — PHOENIX

Observer :

```text
trace
span
prompt
réponse
modèle
latence
tokens
erreur
```

---

## OPTION 5B — LANGFUSE

Observer les mêmes informations essentielles.

---

# 23. CONTRAT OBSERVABILITÉ

Le concept à enseigner n’est pas :

```text
Phoenix
```

ou :

```text
Langfuse
```

mais :

```text
OpenTelemetry
```

Le pipeline doit produire des traces OpenTelemetry exportables via OTLP.

Créer :

```text
05-observability/CONTRACT.md
```

Une trace minimale doit contenir :

```text
trace_id
service
operation
model
latency
status
error
```

Si disponible :

```text
input_tokens
output_tokens
```

---

# 24. ÉQUIPE 6 — ÉVALUATION SCIENTIFIQUE

Responsabilité :

```text
mesurer les performances
```

Outil :

```text
MLflow
```

Créer une expérience :

```text
clinical-document-extraction
```

Pour chaque run enregistrer :

```text
model
runtime
gateway
prompt_version
temperature
dataset_version
latency
valid_json_rate
precision
recall
F1
```

---

# 25. DATASET DE RECHERCHE CLINIQUE

Créer uniquement des données **synthétiques**.

Sujet recommandé :

> Patients opérés pour cancer du pancréas.

Documents possibles :

```text
compte rendu opératoire
compte rendu anatomopathologique
compte rendu scanner
lettre de sortie
```

Créer au minimum :

```text
10 cas pour tests rapides
20 cas pour workshop standard
```

---

# 26. VARIABLES À EXTRAIRE

Exemple de schéma :

```text
patient_id
âge
sexe
diagnostic
type_intervention
voie_abord
résection_veineuse
taille_tumeur_mm
histologie
pT
pN
nombre_ganglions
nombre_ganglions_envahis
marge_R
fistule_pancreatique
DGE
hémorragie
durée_sejour
réadmission
```

---

# 27. GOLD STANDARD

Pour chaque dossier :

```text
datasets/raw/patient_001.pdf
```

créer :

```text
datasets/gold/patient_001.json
```

Le gold standard doit être entièrement déterministe.

Aucune donnée du gold standard ne doit être générée dynamiquement par le LLM.

---

# 28. STRUCTURED OUTPUT

Créer :

```python
class ClinicalExtraction(BaseModel):
    ...
```

Le LLM doit produire une structure JSON correspondant au schéma.

Règle fondamentale :

```text
information absente
→ null
```

et non :

```text
information absente
→ invention probable
```

Le prompt doit explicitement interdire l’inférence d’informations non présentes.

---

# 29. ÉTAPE 2 — TROIS PARCOURS APPLICATION

Tous les étudiants utilisent :

```text
le même dataset
le même schéma
la même Gateway
le même modèle logique
```

mais choisissent leur interface.

---

# 30. PARCOURS A — PYTHON

Répertoire :

```text
07-applications/python/
```

Technologies :

```text
OpenAI Python SDK
Pydantic
requests
pandas
```

Pipeline :

```text
PDF
 ↓
Docling
 ↓
texte
 ↓
Gateway
 ↓
Pydantic
 ↓
JSON
 ↓
CSV
```

C’est le parcours recommandé pour comprendre réellement le fonctionnement.

---

# 31. PARCOURS B — OPEN WEBUI

Objectif :

permettre aux étudiants moins techniques d’expérimenter :

```text
prompt
temperature
modèle
structured output
```

Open WebUI doit parler à :

```text
Caddy
 ↓
LLM Gateway
```

et non directement au runtime.

Prévoir un tutoriel permettant :

1. connexion ;
2. choix du modèle `med-extraction` ;
3. utilisation du prompt fourni ;
4. comparaison des résultats avec le gold standard.

---

# 32. PARCOURS C — FLOWISE

Objectif :

visualiser graphiquement l’orchestration.

Construire :

```text
Document
  ↓
Docling
  ↓
Prompt
  ↓
LLM Gateway
  ↓
Structured output
  ↓
Validation
```

Fournir un template importable.

---

# 33. MÊME CONTRAT POUR LES TROIS APPLICATIONS

Chaque solution doit produire :

```text
datasets/extracted/<student>/<patient>.json
```

respectant exactement le même schéma.

Il doit donc être possible de comparer :

```text
Python
Open WebUI
Flowise
```

sur le même gold standard.

---

# 34. SCORE FINAL

Créer :

```bash
make evaluate
```

qui calcule :

```text
nombre de dossiers
complétude
JSON valides
exactitude champ par champ
precision
recall
F1
latence moyenne
```

Afficher un résumé lisible.

---

# 35. ÉTAPE 3 — CHAOS ENGINEERING

Créer :

```text
chaos/
```

avec scénarios numérotés.

---

# 36. CHAOS 01 — PANNE DU PRIMARY MODEL SERVER

Action :

```text
stop Ollama
```

Résultat attendu :

```text
Gateway
 ↓
fallback
 ↓
llama.cpp
```

Le client :

```text
ne change pas d’URL
```

Le dashboard doit montrer :

```text
Ollama       🔴
Gateway      🟢
Clinical AI  🟢
```

---

# 37. CHAOS 02 — PANNE DU RUNTIME DE SECOURS

Couper ensuite le runtime secondaire.

Résultat :

```text
Clinical AI Pipeline 🔴
```

L’étudiant doit identifier pourquoi.

---

# 38. CHAOS 03 — RATE LIMIT

Créer deux clés :

```text
research-standard
research-priority
```

Exemple :

```text
standard = 10 RPM
priority = 120 RPM
```

Envoyer 12 requêtes rapidement.

Résultat attendu :

```text
HTTP 429
```

pour la clé standard.

---

# 39. CHAOS 04 — SORTIE JSON INVALIDE

Provoquer volontairement une réponse incompatible avec :

```text
ClinicalExtraction
```

Résultat attendu :

```text
Pydantic validation error
```

Le système doit :

```text
détecter
journaliser
ne pas écrire de données invalides
```

---

# 40. CHAOS 05 — DOCLING INDISPONIBLE

Arrêter Docling.

Résultat attendu :

```text
document pipeline DOWN
```

mais :

```text
LLM Gateway UP
Inference UP
```

Les étudiants doivent comprendre la notion de dépendance partielle.

---

# 41. CHAOS 06 — GATEWAY A INDISPONIBLE

Si les deux gateways sont déployées :

```text
LiteLLM
Bifrost
```

permettre de basculer manuellement ou automatiquement vers la seconde.

Le client doit uniquement changer :

```text
un endpoint logique
```

ou idéalement continuer via Caddy.

---

# 42. CHAOS 07 — OBSERVABILITÉ INDISPONIBLE

Couper :

```text
Phoenix
```

ou :

```text
Langfuse
```

Le pipeline clinique doit continuer à fonctionner.

Le test enseigne :

```text
observability ≠ production path
```

La perte de télémétrie ne doit pas empêcher l’inférence.

---

# 43. SCRIPT CHAOS

Créer :

```bash
./chaos/chaos.sh scenario-01
```

et :

```bash
./chaos/chaos.sh reset
```

Chaque scénario doit être réversible.

---

# 44. README PRINCIPAL

Le README doit commencer par une représentation pédagogique simple :

```text
ÉTAPE 1
Construire la plateforme

        ↓

ÉTAPE 2
Utiliser la plateforme
pour une extraction clinique

        ↓

ÉTAPE 3
Casser la plateforme
et observer sa résilience
```

Puis expliquer :

```text
model
runtime
gateway
application
observability
evaluation
GitOps
```

en langage accessible à un étudiant en médecine.

---

# 45. TUTORIEL DE CHAQUE ÉQUIPE

Chaque :

```text
TUTORIAL.md
```

doit suivre exactement cette structure :

```markdown
# Mission

# Ce que votre service apporte

# Ce que vous devez comprendre

# Vos dépendances

# Votre IP

# Installation

# Configuration

# Démarrage

# Test local

# Test contractuel

# Vérification dans Uptime Kuma

# Commit

# Pull Request

# Définition de DONE
```

---

# 46. DÉFINITION DE DONE D’UNE ÉQUIPE

Une équipe n’a terminé que si :

```text
[ ] service démarré
[ ] healthcheck vert
[ ] test contractuel réussi
[ ] documentation complétée
[ ] Pull Request ouverte
[ ] Pull Request intégrée
[ ] service visible UP dans Uptime Kuma
```

---

# 47. SCRIPTS MAKE

Créer au minimum :

```bash
make help

make preload
make verify-airgap

make core-up
make core-down

make dashboard-up

make inference-ollama
make inference-llamacpp
make inference-omlx

make gateway-litellm
make gateway-bifrost

make observability-phoenix
make observability-langfuse

make docling-up
make mlflow-up

make health
make test
make evaluate

make chaos-primary
make chaos-gateway
make chaos-docling
make chaos-reset
```

---

# 48. HEALTHCHECKS

Tous les services doivent posséder un healthcheck.

Éviter les healthchecks qui vérifient uniquement :

```text
process alive
```

Préférer lorsque possible :

```text
HTTP endpoint réellement fonctionnel
```

Pour les modèles :

```text
GET /v1/models
```

peut servir de premier contrôle.

---

# 49. DASHBOARD DE PROGRESSION DU WORKSHOP

Créer un script :

```text
scripts/workshop-status.sh
```

affichant :

```text
╔══════════════════════════════════════╗
║       FARCI WORKSHOP         ║
╠══════════════════════════════════════╣
║ GitOps                 UP            ║
║ Network                UP            ║
║ Inference Primary      UP            ║
║ Inference Secondary    UP            ║
║ LLM Gateway            UP            ║
║ Docling                UP            ║
║ Observability          UP            ║
║ Evaluation             UP            ║
╠══════════════════════════════════════╣
║ CLINICAL PIPELINE      READY         ║
╚══════════════════════════════════════╝
```

Uptime Kuma constitue la version graphique de ce statut.

---

# 50. PRÉPARATION INSTRUCTEUR AVANT LE JOUR J

Créer :

```text
docs/INSTRUCTOR_GUIDE.md
```

avec checklist.

## Avec Internet

```text
[ ] cloner dépôt
[ ] choisir versions
[ ] docker pull
[ ] télécharger modèles
[ ] télécharger wheels Python
[ ] télécharger éventuels binaires Mac
[ ] vérifier checksums
[ ] lancer tous les services
[ ] exécuter tous les tests
```

## Puis couper Internet

```text
[ ] désactiver Internet
[ ] conserver réseau local
[ ] relancer toutes les machines
[ ] vérifier bootstrap offline
[ ] vérifier modèles
[ ] vérifier Python offline
[ ] vérifier dashboard
[ ] vérifier dataset
[ ] exécuter chaos
```

---

# 51. MANIFESTE AIR-GAP

Créer :

```text
offline/MANIFEST.sha256
```

contenant les SHA256 des :

```text
archives
modèles
wheels
binaires
configurations exportées
```

Créer :

```bash
make verify-manifest
```

---

# 52. AUCUN TÉLÉCHARGEMENT IMPLICITE

C’est une contrainte stricte.

En mode workshop :

```text
docker compose up
```

ne doit pas déclencher volontairement de téléchargement externe.

Les modèles ne doivent pas être téléchargés automatiquement au premier appel.

Les applications ne doivent contenir :

```text
aucun CDN
aucune police distante
aucun JS distant nécessaire
aucun endpoint cloud obligatoire
```

---

# 53. SÉCURITÉ ET DONNÉES

Le workshop utilise exclusivement :

```text
données synthétiques
```

Ne jamais fournir de vrais dossiers patients.

Prévoir :

```text
.env
```

dans :

```text
.gitignore
```

Les clés générées ne doivent pas être poussées dans Git.

Fournir :

```text
.env.example
```

---

# 54. TESTS AUTOMATIQUES

Créer des tests pour :

```text
air-gap
réseau
healthchecks
OpenAI contract
gateway
fallback
Docling
structured output
observability
rate limiting
evaluation
```

Le test principal :

```bash
make test
```

doit produire un résumé.

---

# 55. GITEA ACTIONS

Workflow minimum sur Pull Request :

```text
lint
 ↓
tests
 ↓
contract tests
 ↓
evaluation sur mini dataset
```

Exemple d’affichage attendu :

```text
JSON validity       100 %
Extraction F1       0.84
Regression          none
```

---

# 56. VERSIONING DES PROMPTS

Créer :

```text
07-applications/common/prompts/
```

avec :

```text
extraction_v1.md
extraction_v2.md
```

Chaque expérience MLflow doit enregistrer :

```text
prompt_version
```

Message pédagogique :

> Un changement de prompt est une modification de la méthode expérimentale.

---

# 57. CONDITIONS DE SUCCÈS FINALES

Le workshop est considéré fonctionnel si les étudiants peuvent effectuer la chaîne suivante sans Internet :

```text
PDF médical synthétique
          │
          ▼
       Docling
          │
          ▼
  pseudonymisation
          │
          ▼
      LLM Gateway
          │
          ▼
runtime d’inférence
          │
          ▼
 structured output
          │
          ▼
       Pydantic
          │
          ▼
         JSON
          │
          ▼
     Gold Standard
          │
          ▼
       Metrics
          │
          ▼
        MLflow
```

tout en observant l’appel dans :

```text
Phoenix
```

ou :

```text
Langfuse
```

---

# 58. EXPÉRIENCE FINALE À DÉMONTRER

Configuration initiale :

```text
Python
   ↓
Caddy
   ↓
LiteLLM
   ↓
Ollama
   ↓
Phoenix
```

Puis permuter :

```text
Python
   ↓
Caddy
   ↓
Bifrost
   ↓
llama.cpp
   ↓
Langfuse
```

Sans modifier la logique métier de l’application.

Sur Mac :

```text
Python
   ↓
Caddy
   ↓
Bifrost
   ↓
oMLX
```

Le fonctionnement doit rester équivalent grâce aux contrats.

---

# 59. MESSAGES PÉDAGOGIQUES À FAIRE APPARAÎTRE DANS LA DOCUMENTATION

Le workshop doit explicitement transmettre les messages suivants.

### Message 1

> Un LLM est un composant probabiliste, pas une base de données.

### Message 2

> Le modèle et le logiciel qui exécute le modèle sont deux choses différentes.

### Message 3

> Une application ne devrait pas dépendre directement d’un moteur ou d’un fournisseur.

### Message 4

> Une API standard permet de remplacer une implémentation sans réécrire l’application.

### Message 5

> Une donnée générée par un LLM doit être validée avant d’entrer dans une base de recherche.

### Message 6

> Une performance n’a de sens que comparée à une référence.

### Message 7

> Le prompt, le modèle, les paramètres, les données et le code font partie de la méthode expérimentale.

### Message 8

> Une IA destinée à la recherche clinique nécessite GitOps, DevOps, LLMOps, gouvernance des données et évaluation.

### Message 9

> Une infrastructure correctement conçue doit continuer à fonctionner malgré certaines pannes.

### Message 10

> L’observabilité permet de comprendre pourquoi un système fonctionne ou échoue.

---

# 60. LIVRABLE FINAL ATTENDU DE L’AGENT

Ne pas produire uniquement des exemples ou des fragments.

Générer **l’intégralité du dépôt fonctionnel**.

Tous les fichiers mentionnés doivent exister.

Chaque fichier doit contenir une implémentation exploitable.

Le dépôt doit fonctionner selon cette séquence :

```bash
git clone ...
cd farci

./preload.sh --all
./verify-airgap.sh

make core-up
make dashboard-up
```

Puis après déconnexion d’Internet :

```bash
make health
```

Les équipes doivent ensuite pouvoir démarrer leurs services indépendamment.

À la fin de l’étape 1 :

```bash
make health
```

doit indiquer :

```text
CLINICAL PIPELINE READY
```

À l’étape 2 :

```bash
make evaluate
```

doit évaluer les extractions.

À l’étape 3 :

```bash
./chaos/chaos.sh scenario-01
```

doit provoquer une panne reproductible et observable.

---

# 61. PRIORITÉS DE CONCEPTION

Si un arbitrage est nécessaire, appliquer dans cet ordre :

```text
1. Fonctionnement air-gapped
2. Simplicité pédagogique
3. Interchangeabilité des briques
4. Reproductibilité
5. Observabilité
6. Sécurité
7. Performance
8. Sophistication technique
```

Ne pas introduire Kubernetes.

Ne pas introduire de technologies distribuées complexes qui ne sont pas nécessaires à la compréhension des objectifs.

Docker Compose est volontairement privilégié afin que les étudiants puissent observer directement les composants.

---

# 62. RÉSULTAT PÉDAGOGIQUE ATTENDU

À la fin du workshop, un étudiant en médecine doit être capable d’expliquer avec ses propres mots la différence entre :

```text
LLM
runtime d’inférence
LLM Gateway
reverse proxy
application
structured output
observabilité
évaluation
GitOps
DevOps
LLMOps
```

et comprendre pourquoi un projet d’extraction de données médicales destiné à la recherche clinique nécessite l’ensemble de ces couches.

Le dépôt généré doit être conçu avant tout pour atteindre cet objectif.