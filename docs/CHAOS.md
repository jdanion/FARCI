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

`./chaos/chaos.sh` accepte exactement les mêmes commandes. On les lance **sur
le Pi**, qui porte l'accueil de la salle.

## Comment une panne est provoquée : à l'accueil, pas dans les briques

Un scénario n'arrête aucun conteneur d'étudiant. Il agit sur **l'accueil de
la salle** (le Caddy du Pi), là où passe tout le trafic :

| Action | Fichier d'état | Effet |
|---|---|---|
| `exclude <route>` | `.chaos/routes.env` (`FARCI_CHAOS_EXCLUDE`) | l'accueil saute la brique de l'équipe : la référence répond (🛟) |
| `block <route>` | `.chaos/routes.env` (`FARCI_CHAOS_BLOCK`) | plus personne ne répond sur cette route (ni équipe, ni référence) |

Routes : `inference`, `passerelle`, `documents`, `observabilite`. L'accueil
se recharge en quelques secondes ; `revert` (ou `chaos reset`) efface la
ligne et le recharge à nouveau. Pourquoi à l'accueil ? Parce que la panne
est alors **identique pour toute la salle**, réversible en une commande, et
qu'elle ne dépend pas de l'état de la machine d'une équipe.

**Variante vivante** (si l'équipe concernée est prête) : c'est elle qui
arrête sa brique (`./bin/farci down 02-inference/ollama`). L'accueil passe
alors à la référence tout seul ; le scénario sert à **vérifier**.

Chaque scénario annonce son **attendu** avant d'agir, applique la panne, puis
**vérifie** cet attendu par une vraie requête (`ATTENDU` ou `INATTENDU`) : le
code de sortie de `./bin/farci chaos scenario-0X` le reflète.

## Pendant la séance de 4 h : 4 scénarios, 35 minutes

| Ordre | Scénario | Tableau attendu |
|---|---|---|
| 1 | 01 — runtime principal | `Inference` **🛟 REF**, service rendu **READY** : l'extraction répond toujours |
| 2 | 04 — JSON invalide | rien ne bouge au tableau ; les dossiers sont refusés, rien n'est écrit |
| 3 | 06 — passerelle de l'équipe (**ou 05**) | 06 : `LLM Gateway` **🛟 REF**, le client ne change pas d'adresse ; 05 : `Documents` **DOWN**, l'extraction texte continue |
| 4 | 07 — observabilité | `Observability` **DOWN**, l'extraction réussit, service rendu **READY** |

Sous le cadre, la ligne **PANNE EN COURS** rappelle ce qui est coupé tant
que le scénario n'est pas réparé.

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

**Action** : l'accueil saute le runtime de l'équipe 2 (`exclude inference`).
Variante vivante : l'équipe 2 arrête Ollama.

**Assertion** : une requête `med-extraction` répond **200**, par la même
adresse.

```
Client       → ne change pas d'adresse
Tableau      → Inference 🛟 REF   LLM Gateway ✅   service rendu READY
```

**Leçon** : la redondance n'est utile que si elle est **exercée**. Une
architecture qui n'a jamais été testée dans son mode dégradé n'est pas
redondante, elle est théorique.

---

### Scénario 02 — Panne du runtime de secours

**Action** : plus **aucun** runtime, ni équipe ni référence (`block inference`).

**Assertion** : la passerelle renvoie une **erreur** (pas 200), et le
pipeline n'écrit rien. Le tableau passe `Inference` à `DOWN` et liste ce qui
manque.

**Leçon** : la résilience a une profondeur. Enchaîner deux pannes montre où
s'arrête la protection — et l'étudiant doit être capable de l'expliquer.

---

### Scénario 03 — Limitation de débit

**Bonus** : exige les clés virtuelles LiteLLM, donc une base PostgreSQL
(`03-llm-gateway/TUTORIAL.md`). Sans elles, le scénario est sauté.

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

Le modèle `med-chaos` n'existe que sur le runtime rejoué de la référence ;
la passerelle l'y envoie directement, quel que soit le runtime de l'équipe.

**Assertion** : 3 dossiers extraits avec `med-chaos` → **3 rejetés** par la
validation, **aucun fichier** écrit dans `datasets/extracted/`.

**Leçon** : une donnée produite par un LLM ne devient une donnée de recherche
que si elle a été validée. Le point critique n'est pas l'appel réseau, c'est
l'écriture.

---

### Scénario 05 — Docling indisponible

**Action** : l'accueil coupe la route documents (`block documents`).

**Assertion** : `/docling` ne répond plus **et** un dossier texte est
extrait et écrit : le parcours texte de l'étape 2 ne passe pas par Docling.
Tableau : `Documents` **DOWN**, service rendu **DEGRADED**.

**Leçon** : les dépendances sont **partielles**. Savoir que le reste tient est
aussi important que savoir que la partie cassée est tombée.

---

### Scénario 06 — Passerelle A indisponible

**Action** : l'accueil saute la passerelle de l'équipe 3 (`exclude
passerelle`). Variante vivante : l'équipe 3 arrête LiteLLM.

**Assertion** : une requête répond **200** : Bifrost si l'équipe l'a monté,
sinon la passerelle de la référence — **sans que le client change
d'adresse**. Tableau : `LLM Gateway` **🛟 REF**.

**Leçon** : le client ne connaît qu'un **point d'entrée logique**. C'est toute la
valeur du contrat d'API.

---

### Scénario 07 — Observabilité indisponible

**Action** : l'accueil ne reçoit plus aucune trace (`block observabilite`).

**Assertion** : 2 dossiers extraits et écrits ; seules les traces sont
perdues (l'échec d'export est journalisé, sans effet sur l'extraction).
Service rendu **READY** : Phoenix n'en fait pas partie.

**Leçon** : **l'observabilité n'est pas sur le chemin de production**. Si la
coupure d'un outil de supervision arrête le soin, l'architecture est mal conçue.
Ce scénario doit rester **vert**, c'est un test bloquant.

---

## Après le chaos

Toujours réparer :

```bash
./bin/farci reset-all           # chaos réparé, bascules levées, tableau affiché
```

Si `reset` ne remet pas tout au vert, le remplacement a échoué : c'est un défaut
à corriger avant la fin de l'atelier, pas après.

---

## Voir aussi

- `docs/CONTRACTS.md` — ce que garantit la passerelle (repli, quota)
- `docs/ARCHITECTURE.md` § 7 — pourquoi l'observabilité est hors du chemin critique
- `tests/test_failover.sh` — l'assertion du scénario 01, exécutable en CI
