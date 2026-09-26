# FARCI — jeu de données synthétique

**Toutes les données de ce dépôt sont synthétiques et inventées.** Aucun dossier
patient réel, aucune donnée personnelle réelle, à aucun moment (cahier des
charges §53).

---

## Les quatre répertoires

| Répertoire | Contenu | Versionné ? |
|---|---|---|
| `raw/` | les documents médicaux (PDF) | **oui** — c'est la source de la méthode |
| `pseudonymized/` | les mêmes documents, pseudonymisés | non — dérivé, reproductible |
| `gold/` | la référence : les variables attendues, dossier par dossier | **oui** — c'est la mesure de toute chose |
| `extracted/` | ce que les équipes ont extrait | non — résultats d'expérience |

Règle : `raw/` et `gold/` sont **déterministes**. Même graine, mêmes fichiers.
C'est la condition pour que deux équipes obtiennent des scores comparables, et
pour qu'une amélioration soit mesurable plutôt que supposée.

---

## Comment le jeu de données est produit

Le générateur part d'un **registre structuré** de cas fictifs — des valeurs
cohérentes entre elles : un `pT3` avec des ganglions envahis, une taille de
tumeur cohérente avec l'aspect scanographique, une durée de séjour cohérente avec
une fistule. Ce n'est pas du bruit aléatoire, c'est de la **simulation**.

Puis :

```
registre des cas
      │
      ├─► 4 documents par cas (PDF)      ──►  raw/
      │     compte rendu opératoire
      │     compte rendu anatomopathologique
      │     compte rendu scanner
      │     lettre de sortie
      │
      └─► gold standard                 ──►  gold/
            écrit DEPUIS LE REGISTRE
```

**Règle absolue** : le gold standard n'est **jamais** produit par un LLM. Il vient
du registre, directement. Un gold généré par le modèle qu'on évalue mesurerait le
modle contre lui-même.

---

## Les variables extraites

```
patient_id            âge            sexe           diagnostic
type_intervention     voie_abord     résection_veineuse
taille_tumeur_mm      histologie     pT             pN
nombre_ganglions      nombre_ganglions_envahis
marge_R               fistule_pancreatique
DGE                   hémorragie
durée_sejour          réadmission
```

Deux conventions essential pour que les scores ayent un sens :

1. **Information absente → `null`.** Jamais une invention, jamais un `0` par
   défaut. `0` est une **valeur** : « aucun ganglion envahi » n'est pas la même
   chose que « non précisé ».
2. **Unités imposées** : millimètres pour les tailles, jours pour les durées.
   Une valeur sans unité dans le document est convertie, pas devinée.

Le détail des règles de codage est dans `gold_schema.md` (à produire avec la
phase 10). C'est le document que les étudiants doivent lire avant de se
plaintre d'un score.

---

## Utilisation prévue

| Contexte | Contenu |
|---|---|
| tests rapides pendant l'atelier | 10 cas |
| évaluation finale | 20 cas |
| CI (pull requests) | 3 cas, pour un contrôle rapide |

Le sous-ensemble rapide est **inclus** dans l'ensemble standard : les 10 premiers
cas. Il n'y a donc jamais deux jeux de données à maintenir.

---

## Voir aussi

- `docs/CONTRACTS.md` — le schéma est un contrat
- `06-evaluation/` — comment on note une extraction
- `docs/CHAOS.md` — le scénario 04 invalide des sorties à dessein
