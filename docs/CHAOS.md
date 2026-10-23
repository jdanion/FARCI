# Chaos engineering

Casser un système pour vérifier qu'il résiste, c'est un travail d'ingénierie —
pas du sabotage. Chaque scénario est **réversible**, **documenté**, et son résultat
**attendu est écrit avant de l'exécuter**.

> On ne prouve pas qu'un système est robuste en le regardant. On le prouve en lui
> donnant des coups et en observant ce qu'il fait.

---

## Utilisation

```bash
./bin/farci chaos list                 # les scénarios disponibles
./bin/farci chaos scenario-01          # appliquer
./bin/farci chaos scenario-01 --duration 90   # appliquer, puis réparer tout seul
./bin/farci chaos status               # ce qui est encore cassé
./bin/farci chaos reset                # tout réparer
```

`./chaos/chaos.sh` accepte exactement les mêmes commandes.

## Pendant la séance de 4 h : 4 scénarios, 35 minutes

| Ordre | Scénario | Tableau attendu |
|---|---|---|
| 1 | 01 — runtime principal | `Inference` rouge, `CLINICAL PIPELINE` **READY** (un runtime suffit) |
| 2 | 04 — JSON invalide | tout reste vert ; le dossier est refusé, rien n'est écrit |
| 3 | 06 si Bifrost tourne, **sinon 05** | 06 : rien ne bouge côté client ; 05 : `Documents` rouge, pipeline **DEGRADED**, l'extraction texte continue |
| 4 | 07 — observabilité | `Observability` rouge, `CLINICAL PIPELINE` **READY** |

Les scénarios 02 et 03 restent disponibles pour une séance plus longue.
La règle de `CLINICAL PIPELINE` est unique (`scripts/services.py`) et ces cas
sont vérifiés par `tests/test_pipeline_rule.py`.

Chaque scénario expose la même interface : `apply` et `revert`. L'état est
conservé dans `.chaos/state.json`, ce qui permet de savoir ce qui est actif même
après un redémarrage de machine.

---

## Le principe de chaque scénario

| Élément | Rôle |
|---|---|
| **action** | ce que le script fait, en une phrase |
| **assertion** | ce qui **doit** être vrai ensuite, vérifié automatiquement |
| **observabilité** | où l'on voit le symptôme (tableau de bord, traces, journaux) |
| **leçon** | ce qu'on doit retenir, en une phrase |

Un scénario sans assertion automatique n'est pas un scénario : c'est une
impression. Si l'assertion échoue, c'est que l'architecture ne tient pas la
promesse qu'elle fait dans sa documentation — et c'est **aussi** une
découverte.

---

## Les sept scénarios

### Scénario 01 — Panne du runtime principal

**Action** : arrêter le runtime primaire (Ollama).

**Attendu** :

```
Gateway      → 200, service rendu par le secondaire
Client       → ne change pas d'adresse
Tableau      → Inference 🔴   LLM Gateway 🟢   CLINICAL PIPELINE READY
En-tête      → le repli est indiqué
```

Pré-requis : un runtime secondaire tourne (llama.cpp, brique bonus, ou celui
de la machine de référence).

**Leçon** : la redondance n'est utile que si elle est **exercée**. Une
architecture qui n'a jamais été testée dans son mode dégradé n'est pas
redondante, elle est théorique.

---

### Scénario 02 — Panne du runtime de secours

**Action** : arrêter **aussi** le runtime secondaire.

**Attendu** : `CLINICAL PIPELINE` passe à `DEGRADED` et le tableau affiche
« Il manque : 1 runtime » ; la gateway renvoie une erreur **documentée** (503),
et les journaux disent quelle cause.

**Leçon** : la résilience a une profondeur. Enchaîner deux pannes montre où
s'arrête la protection — et l'étudiant doit être capable de l'expliquer.

---

### Scénario 03 — Limitation de débit

**Action** : envoyer 12 requêtes en quelques secondes avec la clé **standard**
(10 RPM), puis avec la clé **prioritaire** (120 RPM).

**Attendu** :

```
clé standard   → au moins un HTTP 429, avec un en-tête Retry-After
clé prioritaire → toutes les requêtes passent
```

**Leçon** : le débit est une propriété de la **passerelle**, pas du modèle. Deux
services qui partagent une ressource partagent un quota — c'est une question de
gouvernance, pas de performance.

---

### Scénario 04 — Sortie JSON invalide

**Action** : provoquer une réponse qui ne respecte **pas** le schéma
`ClinicalExtraction`, via un mécanisme réel (modèle de test déclaré non conforme
auprès de la gateway — pas une fausse URL).

**Attendu** : erreur de validation journalisée, **aucun fichier** écrit dans
`datasets/extracted/`.

**Leçon** : une donnée produite par un LLM ne devient une donnée de recherche
que si elle a été validée. Le point critique n'est pas l'appel réseau, c'est
l'écriture.

---

### Scénario 05 — Docling indisponible

**Action** : arrêter Docling.

**Attendu** : ligne `Documents` au rouge, `CLINICAL PIPELINE` en `DEGRADED`,
passerelle et inférence toujours vertes. Le parcours texte de l'étape 2
(`./bin/farci extract`) continue de fonctionner : il ne passe pas par Docling.

**Leçon** : les dépendances sont **partielles**. Savoir que le reste tient est
aussi important que savoir que la partie cassée est tombée.

---

### Scénario 06 — Passerelle A indisponible

**Action** : arrêter la gateway A (LiteLLM).

**Attendu** : la gateway B prend le relais, **sans que le client change d'adresse**,
toujours via Caddy.

Pré-requis : Bifrost (brique bonus) tourne et Caddy sait basculer vers lui.
Sinon, jouer le scénario 05 à la place.

**Leçon** : le client ne connaît qu'un **point d'entrée logique**. C'est toute la
valeur du contrat d'API.

---

### Scénario 07 — Observabilité indisponible

**Action** : arrêter Phoenix (ou Langfuse).

**Attendu** : l'extraction **réussit toujours**, seules les traces sont perdues ;
`CLINICAL PIPELINE` reste **READY** (Phoenix n'en fait pas partie).

**Leçon** : **l'observabilité n'est pas sur le chemin de production**. Si la
coupure d'un outil de supervision arrête le soin, l'architecture est mal conçue.
Ce scénario doit rester **vert**, c'est un test bloquant.

---

## Après le chaos

Toujours réparer :

```bash
./bin/farci chaos reset
./bin/farci status --strict     # doit repasser à READY
```

Si `reset` ne remet pas tout au vert, le remplacement a échoué : c'est un défaut
à corriger avant la fin de l'atelier, pas après.

---

## Voir aussi

- `docs/CONTRACTS.md` — ce que garantit la passerelle (repli, quota)
- `docs/ARCHITECTURE.md` § 7 — pourquoi l'observabilité est hors du chemin critique
- `tests/test_failover.sh` — l'assertion du scénario 01, exécutable en CI
