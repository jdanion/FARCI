# Local d'abord : ce qui passe par Internet, et ce qui n'y passe jamais

**Objectif** : la plateforme fonctionne **sans dépendre d'aucun service
distant**. Ni pour démarrer, ni pour répondre, ni pour traiter un dossier.

Ce n'est pas une contrainte de confort : c'est ce qui garantit qu'une extraction
de dossier patient ne peut pas fuiter. Internet existe dans la salle, et il a
deux usages, pas un de plus :

| Ce qui circule | Par où | Pourquoi c'est acceptable |
|---|---|---|
| **le code** | GitHub (`FARCI_GITHUB_URL`), ou la forge Gitea de la salle | public, sans donnée ; c'est l'objet de `docs/GIT.md` |
| **les fichiers volumineux** : modèles, images Docker, wheels | leur site d'origine (Hugging Face, registres, PyPI) ; en secours le miroir du formateur (`FARCI_FICHIERS_URL`), ou le Pi | publics, téléchargés une fois, figés par leurs empreintes |
| **les dossiers, les prompts, les réponses, les traces** | **rien ne sort de la salle** | inférence, passerelle, observabilité : tout tourne sur place |

Et si Internet tombe pendant la séance, rien ne s'arrête : la forge Gitea
remplace GitHub, le Pi remplace le serveur de fichiers. `./verify-airgap.sh`
prouve que la plateforme démarre et répond sans aucun réseau extérieur.

---

## Le modèle : deux phases distinctes

| Phase | Quand | Internet | Commande |
|---|---|---|---|
| **Préchargement** | J-7 à J0, y compris dans la salle | oui : GitHub et le serveur de fichiers | `git clone`, puis poste étudiant : `./preload.sh --equipe <N>` ; formateur : `./preload.sh --core` |
| **Atelier** | J0 | **pas pour traiter** ; seulement `git` et un fichier manquant | `./bin/farci up <brique>`, `./bin/farci status`, … |

### D'où viennent les fichiers volumineux

`./preload.sh` essaie dans cet ordre, sans rien demander :

1. **modèles** : le site d'origine (Hugging Face, `models/models.env`), puis
   le miroir (`FARCI_FICHIERS_URL/models/`) ;
2. **images Docker** : leur registre, puis l'archive du miroir
   (`offline-x86/images/` ou `offline-arm64/images/` selon la machine) ;
3. **wheels Python** : `offline/wheels/` (rempli depuis PyPI par
   `./preload.sh`), sinon le Pi (`FARCI_WHEELS_URL`), sinon le miroir (`wheels/`).

Le miroir n'est qu'un **secours** : il ne sert que si un site d'origine est
bloqué ou saturé. Le formateur l'alimente depuis une machine déjà préchargée :
`./bin/farci partage publier <destination rsync>`. Dans la salle, le Pi sert
la même arborescence sur `http://<REFERENCE_IP>/partage/`.

Ce qui est téléchargé pendant la phase 1 est **figé** : ni le jour J, ni le mois
suivant. Les empreintes SHA256 sont conservées pour le prouver.

### Un poste étudiant : sa brique, selon sa machine

`./preload.sh --equipe <N>` (ou `FARCI_EQUIPE` dans `config/workshop.env`)
ne télécharge que la brique de l'équipe, et seulement ce que la machine
pourra servir le jour J (`scripts/lib/machine.sh`). **Grosse configuration** :
GPU NVIDIA, ou au moins 32 Go de RAM (`FARCI_GROSSE_RAM_GO`) ; `FARCI_MACHINE`
force le profil.

| Équipe | Grosse configuration | Configuration légère |
|---|---|---|
| 0 GitOps | Gitea, runner, PostgreSQL, Redis | idem |
| 1 Réseau | Caddy, python, Uptime Kuma | idem |
| 2 Inférence | **Ollama + Ornith-1.5-9B** (+ 2B de secours) | **llama.cpp** (compilé ici) **+ Qwen3.5-2B** |
| 3 Passerelle | LiteLLM, Bifrost | idem |
| 4 Documents | Docling, EDS-NLP (compilé ici) | idem |
| 5 Observabilité | Phoenix, Langfuse | Phoenix |
| 6 Évaluation | MLflow | idem |
| 7 Applications | Open WebUI | idem |
| 8 Arcane | python | idem |

Toujours : les wheels Python et le manifeste. Vérification :
`./verify-airgap.sh --equipe <N>`. Deux stacks au plus par brique : oMLX et
Qwen3.8-27B sont hors atelier (`--only models_qwen38` reste possible),
Flowise est une démonstration du formateur (`--all`).

---

## Ce qui est préchargé, et où

Le dépôt Git reste léger : les artefacts lourds vivent dans
`$FARCI_DATA_DIR/offline/`, atteint par un lien symbolique.

| Catégorie | Emplacement | Poids typique |
|---|---|---|
| Images Docker | `offline/images/` | 20–30 Go |
| Poids des modèles (GGUF) | `offline/models/` | 6,5 Go (9B) à 17,5 Go (27B) |
| Wheels Python | `offline/wheels/` | ~0,5 Go |
| Binaires optionnels (Mac) | `offline/bin/` | ~50 Mo |
| Empreintes | `offline/MANIFEST.sha256` | — |

Total selon le périmètre :

| Groupe preload | Contenu | Taille |
|---|---|---|
| `--core` | gitops + dashboard + inference + gateway + observabilité + documents + évaluation + clients + wheels + modèle 9B + modèle de secours 2B | ~28 Go |
| `--only models_qwen38` | le modèle 27B | +17,5 Go |
| `--models-ci` | le modèle de secours seul (Qwen3.5-2B) | ~1,2 Go |
| `--reference` | pile de référence (accueil, runtime rejoué, LiteLLM, Phoenix, Open WebUI, EDS-NLP construit sur place, Ollama, Docling) + modèle de secours + wheels — **à lancer sur le Pi** | ~9 Go |
| `--all` | tout | ~57 Go |

Chaque image est téléchargée **puis** sauvegardée en `.tar` dans
`offline/images/` (liste unique : `scripts/lib/images.sh`). Sur un poste sans
Internet, depuis une copie de `offline/` :

```bash
for f in offline/images/*.tar; do docker load -i "$f"; done
./bin/farci verify-images
```

> `--core` suffit pour obtenir `CLINICAL PIPELINE READY`. Le modèle 27 Go est
> réservé aux postes qui le justifient.

> **Architecture** : `docker pull` tire l'image de l'architecture de la machine
> qui la lance. Les `.tar` préparés sur un portable x86 (amd64) ne
> fonctionnent pas sur le Raspberry Pi (arm64), et inversement : préparer le
> Pi avec `./preload.sh --reference` **sur le Pi**, et ne pas mélanger les
> deux répertoires `offline/images/` (`reference/README.md`).

---

## Vérifier que rien ne dépend d'Internet

```bash
./verify-airgap.sh            # contrôles de complétude
./verify-airgap.sh --strict   # rejoue un démarrage SANS réseau
```

Le contrôle `--strict` utilise `unshare -rn` pour créer un espace de réseau vide.
Si le système le permet, c'est la preuve la plus fidèle du mode air-gap.

Ce que la vérification contrôle :

1. les images requises sont présentes **localement** (jamais de `docker pull`) ;
2. `versions.env` ne contient aucun tag flottant, et les empreintes sont figées ;
3. aucun `docker-compose.yml` ne force de téléchargement ;
4. les wheels permettent une installation `--no-index` ;
5. les poids sont présents et leurs empreintes correspondent ;
6. le manifeste passe `sha256sum -c` ;
7. aucune ressource distante (CDN, police, script) dans les applications ;
8. en mode strict : un cycle arrêt → démarrage complet, sans réseau.

---

## La règle qui n'est pas négociable

> **Aucun téléchargement implicite.**

Concrètement, cela interdit :

- `docker compose up` qui irait chercher une image manquante (`--pull never`) ;
- un modèle téléchargé au premier appel (les poids sont là avant) ;
- un CDN, une police distante ou un script distant dans une application ;
- un point d'entrée cloud obligatoire dans une chaîne locale.

Télécharger est un geste **explicite** (`git clone`, `./preload.sh`), jamais un
effet de bord d'un démarrage. C'est le rôle de `./bin/farci lint-offline`,
exécuté à chaque Pull Request, et de `verify-airgap.sh` avant la séance.

---

## Pièges rencontrés, et Parade

| Piège | Pourquoi c'est arrivé | Parade appliquée |
|---|---|---|
| L'image llama.cpp officielle n'a pas de tag semver | les images sont publiées par numéro de build ; certains builds n'ont jamais eu d'image | le dépôt **compile** l'image pendant le préchargement, pour la machine qui la servira |
| L'image llama.cpp officielle n'existe pas en `linux/arm64` | la documentation le mentionne, l'image n'existe pas | idem : l'image est compilée sur la machine elle-même (amd64 ou arm64) |
| EDS-NLP n'a pas de paquet précompilé pour ARM (Pi, Mac Apple Silicon) | `pip install edsnlp` compile, il faut un compilateur | l'image `farci/eds-nlp` est construite au préchargement, avec le compilateur seulement si nécessaire ; celle du Pi sert aux Mac |
| `make` absent sur certains postes | la machine de référence est minimale | la `Makefile` ne fait qu'appeler `bin/farci` ; les deux marchent |
| `jq` absent | idem | les tests utilisent un parseur JSON maison sur la stdlib Python |
| Un modèle « léger » demande 8 Go de RAM | le cahier des charges visait 1–4 Go, indisponibles dans les familles retenues | un modèle de 2 Go est prévu pour la CI et le développement, **exclu du score** |
| `preload.sh --core` télécharge trop pour un poste étudiant | ~26 Go, dont des stacks que le poste ne pourra pas servir | par défaut, `./preload.sh` ne prend que la brique de l'équipe du poste, selon la machine (voir ci-dessous) ; deux stacks au plus par brique |
| Deux images figées n'existaient pas (`ds4sd/docling-serve:0.5.1`, `mlflow/mlflow:3.16.1`) | noms recopiés sans vérification dans le registre | images corrigées (`docling-serve-cpu`, `ghcr.io/mlflow/mlflow`), tags vérifiés dans les registres le 2026-10-23 |

---

## Si quelque chose tente de sortir

Symptôme typique : un service qui démarre puis échoue sur une connexion, ou une
page qui s'affiche sans mise en forme.

```bash
# 1. voir ce qui est réellement joignable
./bin/farci status

# 2. rejouer la vérification stricte
./verify-airgap.sh --strict

# 3. repérer une URL distante dans le code
./bin/farci lint --only offline
```

La cause la plus fréquente n'est pas un téléchargement : c'est une **ressource
distante dans une page web** (police, script, feuille de style). Le contrôle 7
la détecte.

---

## Voir aussi

- `docs/GIT.md` — le code : GitHub, la forge Gitea, votre branche
- `docs/INSTRUCTOR_GUIDE.md` — les checklists J-7, J-1, J0
- `preload.sh` — le préchargement (phase 1)
- `verify-airgap.sh` — la vérification
- `offline/README.md` — pourquoi ces fichiers sont hors du dépôt
