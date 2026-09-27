# Mode air-gap

**Objectif** : une fois l'atelier commencé, plus aucune connexion Internet ne doit
être nécessaire. Ni pour démarrer, ni pour répondre, ni pour installer quoi que
ce soit.

Ce n'est pas une contrainte de confort : c'est ce qui garantit qu'une extraction
de dossier patient ne peut pas fuiter, et que l'atelier fonctionne dans une salle
sans réseau.

---

## Le modèle : deux phases distinctes

| Phase | Quand | Internet | Commande |
|---|---|---|---|
| **Préparation** | Maintenant | oui | `./preload.sh --core` |
| **Préchargement** | J-7 à J-1 | oui | `./preload.sh --core` |
| **Atelier** | J0 | **non** | `make core-up`, `make health`, … |

## État de la CI/CD

**Les runners Gitea Actions sont désactivés pendant la phase de préparation.**

La CI/CD avec les agents Arcane sera activée uniquement pendant l'atelier offline,
avec un Gitea local. Les workflows resteront en attendant un runner disponible.

| État | Quand | Raison |
|---|---|---|
| **Désactivé** | Phase de préparation | Le projet est en cours de construction |
| **Activé** | Atelier offline | Gitea local + runners disponibles |

Ce qui est téléchargé pendant la phase 1 est **figé** : ni le jour J, ni le mois
suivant. Les empreintes SHA256 sont conservées pour le prouver.

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
| `--core` | gitops + dashboard + inference + gateway + observabilité + documents + évaluation + clients + wheels + modèle 9B | ~26 Go |
| `--models-qwen38` | le modèle 27 Go | +17,5 Go |
| `--all` | tout | ~57 Go |

> `--core` suffit pour obtenir `CLINICAL PIPELINE READY`. Le modèle 27 Go est
> réservé aux postes qui le justifient.

---

## Vérifier avant de couper Internet

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

C'est le rôle de `scripts/cmd/lint.sh --only offline`, exécuté à chaque Pull
Request, et de `verify-airgap.sh` avant le coupure.

---

## Pièges rencontrés, et Parade

| Piège | Pourquoi c'est arrivé | Parade appliquée |
|---|---|---|
| L'image llama.cpp officielle n'a pas de tag semver | les images sont publiées par numéro de build ; certains builds n'ont jamais eu d'image | le dépôt **compile** l'image en multi-architecture pendant le préchargement, depuis les sources vérifiées |
| L'image llama.cpp officielle n'existe pas en `linux/arm64` | la documentation le mentionne, l'image n'existe pas | idem : notre image est construite pour `linux/amd64` **et** `linux/arm64` |
| `make` absent sur certains postes | la machine de référence est minimale | la `Makefile` ne fait qu'appeler `bin/farci` ; les deux marchent |
| `jq` absent | idem | les tests utilisent un parseur JSON maison sur la stdlib Python |
| Un modèle « léger » demande 8 Go de RAM | le cahier des charges visait 1–4 Go, indisponibles dans les familles retenues | un modèle de 2 Go est prévu pour la CI et le développement, **exclu du score** |
| `preload.sh --all` dépasse l'espace disque | ~57 Go | `--core` par défaut, et l'espace disponible est vérifié par `./bin/farci doctor` |

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
la detecte.

---

## Voir aussi

- `docs/INSTRUCTOR_GUIDE.md` — les checklists J-7, J-1, J0
- `preload.sh` — le préchargement (phase 1)
- `verify-airgap.sh` — la vérification
- `offline/README.md` — pourquoi ces fichiers sont hors du dépôt
