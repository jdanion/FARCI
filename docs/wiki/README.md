# FARCI — Wiki des équipes

Une **fiche débutant** par équipe : de quoi réussir son objectif minimal sans
connaître Docker ni le réseau. Le `TUTORIAL.md` de chaque dossier
(`./bin/farci read <équipe>`) reste la référence technique complète.

## La structure de chaque fiche

1. **Votre objectif** — en une phrase, et la ligne du tableau qui le prouve
2. **Les étapes** — 5 à 8, une commande chacune
3. **La sonde** — la commande qui dit « c'est fini »
4. **Bloqué depuis 10 minutes ?** — les causes fréquentes, et la règle :
   on lève la main, la référence du formateur (🛟) sert à votre place, la
   salle n'attend jamais
5. **Bonus** — pour ceux qui ont fini

## Le tableau projeté, en trois symboles

| Symbole | Sens |
|---|---|
| `✅ UP` | votre brique répond **et** la salle l'utilise |
| `🛟 REF` | la référence du formateur rend le service à votre place |
| `DOWN` | personne ne rend ce service |

Votre brique passe de `🛟` à `✅` quand elle répond **et** que le formateur
a déclaré l'IP de votre machine (`./bin/farci doctor` vous la donne).

## Équipes

| Équipe | Sujet | Ligne du tableau | Fiche |
|---|---|---|---|
| 0 | GitOps : Gitea et CI (bonus) | GitOps (`--all`) | [equipe-00](equipe-00.md) |
| 1 | Réseau et tableau de bord | Network | [equipe-01](equipe-01.md) |
| 2 | Inférence | Inference | [equipe-02](equipe-02.md) |
| 3 | Passerelle LLM | LLM Gateway | [equipe-03](equipe-03.md) |
| 4 | Documents cliniques, EDS-NLP | Documents, EDS-NLP | [equipe-04](equipe-04.md) |
| 5 | Observabilité | Observability | [equipe-05](equipe-05.md) |
| 6 | Évaluation | (classement) | [equipe-06](equipe-06.md) |
| 7 | Applications | Open WebUI | [equipe-07](equipe-07.md) |
| 8 | Agents Arcane (bonus) | — | [equipe-08](equipe-08.md) |
| — | Étape 3 : chaos (toute la salle) | PANNE EN COURS | [chaos](chaos.md) |
