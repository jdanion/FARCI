# FARCI — les consignes d'extraction

Une consigne (« prompt ») est un fichier `extraction_<nom>.md`. Toutes portent
**le même schéma** ; seule la stratégie change. On en choisit une avec
`--prompt <nom>`, et l'on compare les runs sur le même gold.

```bash
./bin/farci extract --prompts          # la liste, avec la stratégie de chacune
```

## Cinq stratégies, cinq comportements attendus

| Consigne | Stratégie | Ce que l'on s'attend à voir | Parallèle médical |
|---|---|---|---|
| `naif` | une phrase, aucune règle | la ligne de base : bon sur les formulaires, hésitant ailleurs | l'interne à qui l'on n'a rien expliqué |
| `prudent` | « dans le doute, `null` / `false` » | **précision haute, rappel bas** : peu d'erreurs, des champs vides, des complications manquées | test très **spécifique** : VPP élevée, des faux négatifs |
| `exhaustif` | « tout renseigner, dans le doute `true` » | **rappel haut, précision basse** : scanner pris pour l'anapath, fuite biochimique comptée comme fistule | test très **sensible** : peu de faux négatifs, VPP faible |
| `clinique` | une définition par champ (ISGPS, 8e édition, grand axe sur la pièce…) | le meilleur compromis sur les dossiers à pièges | le protocole de recueil du registre |
| `exemples` | aucun texte, un dossier fictif et sa réponse (« few-shot ») | bon sur le style de l'exemple (abrégé), moins sûr ailleurs | le compagnonnage : « regarde comment je fais » |

`v1` et `v2` sont les consignes historiques, conservées parce que le mode
rejoué (`./bin/farci extract --replay`) a des réponses enregistrées pour elles.
**Le mode rejoué ne montre pas l'effet d'une consigne** : il faut un vrai modèle.

Ces attentes sont des **hypothèses**, pas des résultats. Elles n'ont pas été
mesurées sur les modèles de la salle : c'est l'objet de la séance. Un petit
modèle peut très bien ignorer une consigne — c'est aussi un résultat.

## L'expérience

Une seule variable change à la fois : la consigne **ou** le modèle.

```bash
# 1. Cinq runs, même modèle, cinq consignes (10 dossiers, les quatre styles)
./bin/farci extract --subset quick --run naif      --prompt naif
./bin/farci extract --subset quick --run prudent   --prompt prudent
./bin/farci extract --subset quick --run exhaustif --prompt exhaustif
./bin/farci extract --subset quick --run clinique  --prompt clinique
./bin/farci extract --subset quick --run exemples  --prompt exemples

# 2. Le classement, puis le détail par style de document
./bin/farci evaluate --subset quick
```

Le rapport donne le classement général, puis un tableau **par style de
document** (formulaire, narratif, télégraphique, pièges — voir
`datasets/README.md`). C'est ce second tableau qu'il faut lire :

- sur les **formulaires**, toutes les consignes se valent : un jeu trop facile
  ne mesure rien ;
- sur les dossiers **télégraphiques**, regarder `diagnosis` et `pT` : qui a
  développé « ADK », « T3 N1 », « 3N+/24 » ?
- sur les dossiers à **pièges**, regarder `tumor_size_mm`, `approach`,
  `pancreatic_fistula`, `hemorrhage`, `readmission` : `exhaustif` doit y perdre
  en précision, `prudent` en rappel.

## La grille à remplir

À recopier au tableau ; une ligne par run. Précision / rappel, lus dans le
rapport (`./bin/farci evaluate --subset quick`).

| Modèle | Consigne | JSON valides | Formulaire | Narratif | Télégraphique | Pièges | F1 global |
|---|---|---|---|---|---|---|---|
| | `naif` | /10 | / | / | / | / | |
| | `prudent` | /10 | / | / | / | / | |
| | `exhaustif` | /10 | / | / | / | / | |
| | `clinique` | /10 | / | / | / | / | |
| | `exemples` | /10 | / | / | / | / | |

Puis les trois questions de la restitution :

1. Quelle consigne donne le meilleur rappel ? la meilleure précision ? Est-ce
   la même ?
2. Pour un **registre de recherche**, laquelle choisir ? Et pour un **outil
   d'alerte** qui signale les complications à relire ?
3. Le changement de modèle a-t-il pesé plus ou moins que le changement de
   consigne ?

## Écrire sa propre consigne

Copier un fichier, changer le nom dans le titre, l'essayer :

```bash
cp 07-applications/common/prompts/extraction_clinique.md 07-applications/common/prompts/extraction_equipe3.md
./bin/farci extract --subset quick --run equipe3 --prompt equipe3
```

Le bloc `<!-- Stratégie : … -->` sert au lecteur : il n'est **pas** envoyé au
modèle. La consigne se versionne avec le reste : une consigne meilleure est une
contribution (`docs/GIT.md`).
