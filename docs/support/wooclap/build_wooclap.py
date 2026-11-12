#!/usr/bin/env python3
"""FARCI — les questionnaires Wooclap : une seule source, trois fichiers à importer.

    python3 docs/support/wooclap/build_wooclap.py

écrit, à partir des questions ci-dessous :

    docs/support/wooclap/pre-test.xlsx       à importer dans Wooclap
    docs/support/wooclap/post-test.xlsx
    docs/support/wooclap/satisfaction.xlsx
    docs/support/EVALUATION.md               la version lisible, pour relecture

FORMAT D'IMPORT. Wooclap importe un classeur Excel dont il fournit le modèle
(« Importer des questions » → « Depuis un fichier Excel » → télécharger le
modèle). Ce script suit la forme connue de ce modèle : une question par ligne,
colonnes Type, Title, Correct, puis une colonne par réponse ; « Correct » porte
le numéro de la ou des bonnes réponses. Seuls l'intitulé « MCQ » et ce principe
sont confirmés : si le modèle de votre compte nomme autrement une colonne ou un
type de question, corriger ENTETES et TYPES ci-dessous et relancer.
"""

from __future__ import annotations

from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font

ICI = Path(__file__).resolve().parent
EVALUATION = ICI.parent / "EVALUATION.md"

# --- À ajuster au modèle Excel de votre compte Wooclap ------------------------
ENTETES = {"type": "Type", "titre": "Title", "correct": "Correct", "choix": "Choice {n}"}
TYPES = {
    "qcm": "MCQ",              # une ou plusieurs bonnes réponses
    "sondage": "Poll",         # pas de bonne réponse
    "echelle": "Rating",       # les énoncés à noter vont dans les colonnes de réponse
    "ouverte": "OpenQuestion",
    "nuage": "WordCloud",
    "classement": "Sorting",   # les réponses sont écrites dans le bon ordre
}
SEPARATEUR_CORRECT = ","       # plusieurs bonnes réponses : « 1,2,4 »
# ------------------------------------------------------------------------------

LIBELLES = {"qcm": "QCM", "sondage": "Sondage", "echelle": "Échelle", "ouverte": "Question ouverte",
            "nuage": "Nuage de mots", "classement": "Classement"}

PARTIES = ["Git : cloner, sa branche, commit, Pull Request", "Construire la brique de son équipe (étape 1)",
           "Les modèles : tailles, familles, lesquels comparer", "L'extraction des dossiers (étape 2)",
           "Pydantic : valider la réponse du modèle", "Rappel, précision et lecture du classement",
           "Les pannes provoquées (étape 3)", "Le support de cours et le diaporama"]


def q(ident, kind, titre, choix=(), correct=(), notion="", moment="", plusieurs=False):
    return {"id": ident, "type": kind, "titre": titre, "choix": list(choix), "correct": list(correct),
            "notion": notion, "moment": moment, "plusieurs": plusieurs or len(correct) > 1}


PROFIL = [
    q("A1", "sondage", "Avez-vous déjà utilisé git ?",
      ["Jamais entendu parler", "J'en ai entendu parler", "Quelques commandes, en suivant un tutoriel", "Je m'en sers régulièrement"]),
    q("A2", "sondage", "Avez-vous déjà fait tourner un modèle de langage sur votre propre ordinateur ?",
      ["Non, et je ne savais pas que c'était possible", "Non, mais je sais que cela existe", "Oui, une fois", "Oui, régulièrement"]),
    q("A3", "sondage", "Vous utilisez un assistant d'IA (ChatGPT, Claude, Mistral…)",
      ["Jamais", "Quelques fois par mois", "Chaque semaine", "Chaque jour"]),
    q("A4", "sondage", "Qu'attendez-vous surtout de cette séance ? (plusieurs réponses possibles)",
      ["Comprendre comment fonctionne un modèle de langage", "Savoir si l'on peut s'y fier pour des données médicales",
       "Apprendre à me servir de git", "Faire tourner une IA sur ma propre machine",
       "Savoir évaluer un outil d'IA avant de l'adopter", "Je ne sais pas encore"], plusieurs=True),
    q("A5", "ouverte", "Une question à laquelle vous aimeriez avoir une réponse en sortant de la séance."),
    q("A6", "nuage", "En un mot : « IA en médecine », cela vous évoque…"),
]

AUTO = [
    q("B1", "echelle", "Je me sens capable d'expliquer à un collègue… (1 = pas du tout, 5 = tout à fait)",
      ["la différence entre un modèle et le logiciel qui l'exécute",
       "comment choisir un modèle selon la machine dont on dispose",
       "pourquoi la réponse d'une IA doit être vérifiée avant d'entrer dans une base de recherche",
       "ce que veut dire « un rappel de 0,80 »",
       "ce qu'est une branche git, et à quoi elle sert",
       "ce qui, dans une IA utilisée à l'hôpital, peut ou non passer par Internet"]),
]

CONNAISSANCES = [
    q("C1", "qcm", "Un modèle de langage répond à une question clinique. Que fait-il réellement ?",
      ["Il consulte une base de connaissances médicales validée", "Il produit, mot après mot, la suite la plus plausible",
       "Il cherche la réponse sur Internet", "Il applique des règles écrites par des médecins"], [2],
      "LLM probabiliste", "étape 2, premier JSON rejeté"),
    q("C2", "qcm", "Ollama et llama.cpp sont…",
      ["deux modèles de langage", "deux logiciels capables d'exécuter un même modèle",
       "deux jeux de données médicales", "deux fournisseurs d'IA en ligne"], [2],
      "modèle ≠ runtime", "étape 1, équipe 2"),
    q("C3", "qcm", "Dans le nom de fichier « Qwen3.5-4B-Q4_K_M.gguf », que désigne « Q4 » ?",
      ["La quatrième version du modèle", "4 milliards de paramètres",
       "La compression : 4 bits par paramètre, un fichier plus petit et un peu moins précis", "4 Go de mémoire nécessaires"], [3],
      "quantification", "diaporama « Lire le nom d'un modèle »"),
    q("C4", "qcm", "Par rapport à un modèle généraliste de même taille, MedGemma 4B est…",
      ["un dispositif médical certifié", "un modèle réentraîné sur des textes médicaux",
       "une base de données médicale interrogeable", "un modèle plus gros, donc plus lent"], [2],
      "types de modèles", "étape 2, comparaison des trois 4B"),
    q("C5", "qcm", "À quoi sert une passerelle LLM ? (plusieurs réponses)",
      ["Offrir un point d'entrée unique aux applications", "Basculer sur un autre serveur en cas de panne",
       "Améliorer la justesse médicale des réponses", "Distribuer des clés et limiter le débit"], [1, 2, 4],
      "passerelle", "étape 1, équipe 3 ; panne 01"),
    q("C6", "qcm", "On remplace le modèle servi derrière la passerelle. Que faut-il changer dans l'application ?",
      ["Rien", "L'adresse à laquelle elle se connecte", "La consigne (le prompt) envoyée au modèle",
       "Presque tout : il faut la réécrire"], [1],
      "contrat", "étape 2, changement de modèle ; panne 06"),
    q("C7", "qcm", "Dans la chaîne d'extraction, à quoi sert Pydantic ?",
      ["À vérifier que les valeurs extraites sont médicalement justes",
       "À vérifier que la réponse du modèle respecte le formulaire : types, bornes, valeurs permises",
       "À retirer les noms des patients avant le traitement", "À accélérer le modèle"], [2],
      "validation", "étape 2 ; diaporama « Pydantic »"),
    q("C8", "qcm", "Le modèle renvoie « âge : soixante ans » là où un nombre est attendu. Que doit faire la chaîne de traitement ?",
      ["Enregistrer la réponse : le sens est clair", "Rejeter la réponse et ne rien écrire dans la base",
       "Corriger la valeur sans le signaler", "Supprimer le dossier du patient"], [2],
      "validation", "étape 2 ; panne 04"),
    q("C9", "qcm", "Le modèle répond « âge : 76 » pour un patient de 67 ans. Qui repère l'erreur ?",
      ["Pydantic : il rejette la réponse", "La comparaison à la référence (gold standard) : Pydantic, lui, l'accepte",
       "La passerelle", "Personne : cette erreur est indétectable"], [2],
      "forme ≠ fond", "évaluation ; diaporama « Bien formé ne veut pas dire juste »"),
    q("C10", "qcm", "Pseudonymiser un compte rendu avant de le confier au modèle, c'est…",
      ["supprimer toutes les informations médicales", "chiffrer le fichier",
       "remplacer les identifiants par des jetons, en gardant le lien entre les documents d'un même patient",
       "rendre toute réidentification définitivement impossible"], [3],
      "pseudonymisation", "étape 2, équipe 4"),
    q("C11", "qcm", "Un article annonce : « notre système atteint un F1 de 0,84 ». Qu'en concluez-vous ?",
      ["Le système est fiable", "84 % des patients sont bien classés", "Le système invente 16 % de ses réponses",
       "Rien, tant qu'on ne sait pas à quelle référence il a été comparé"], [4],
      "référence", "évaluation : le classement projeté"),
    q("C12", "qcm", "Un système signale 10 complications ; 8 sont réelles. Il y en avait 16 à trouver.",
      ["Précision 50 %, rappel 80 %", "Précision 80 %, rappel 50 %", "Précision 80 %, rappel 80 %",
       "Précision 62 %, rappel 50 %"], [2],
      "précision et rappel", "évaluation"),
    q("C13", "qcm", "Le compte rendu indique une marge R0 ; le modèle répond « non précisé ». Quelle mesure baisse ?",
      ["Le rappel : une valeur à trouver a été manquée", "La précision : le modèle a inventé une valeur",
       "Les deux", "Aucune : « non précisé » est toujours une bonne réponse"], [1],
      "rappel", "évaluation ; diaporama « Quatre issues pour chaque champ »"),
    q("C14", "qcm", "L'outil qui enregistre les traces tombe en panne pendant une extraction. Dans une plateforme bien conçue…",
      ["l'extraction s'arrête, par sécurité", "les résultats deviennent faux",
       "l'extraction continue ; seules les traces manquent", "le traitement bascule sur un service en ligne"], [3],
      "résilience, observabilité", "panne 07"),
    q("C15", "qcm", "Dans une plateforme d'IA « locale », que peut-on laisser passer par Internet ? (plusieurs réponses)",
      ["Le code du projet", "Le fichier du modèle, quand on le télécharge", "Les comptes rendus des patients",
       "Les questions posées au modèle et ses réponses"], [1, 2],
      "local d'abord", "accueil, et tout au long"),
    q("C16", "qcm", "Dans git, une branche sert à…",
      ["sauvegarder le projet en ligne", "travailler sur sa version sans modifier celle des autres",
       "effacer l'historique", "copier le projet sur une clé USB"], [2],
      "git : branche", "accueil"),
    q("C17", "classement", "Remettez ces gestes dans l'ordre.",
      ["cloner le projet", "créer sa branche", "modifier un fichier", "enregistrer la modification (commit)",
       "la publier (push)", "demander une relecture (Pull Request)"], [],
      "git : parcours", "accueil, 0:20, 1:15"),
    q("C18", "qcm", "Que montre la commande « git diff » ?",
      ["La liste des branches du projet", "Les lignes ajoutées et retirées depuis le dernier commit",
       "Les différences entre GitHub et Gitea", "Les fichiers trop lourds pour git"], [2],
      "git : diff", "0:20, avant le premier commit"),
    q("C19", "qcm", "Une Pull Request sert à…",
      ["télécharger le projet", "faire relire sa branche avant qu'elle soit intégrée au travail commun",
       "supprimer une branche", "annuler son dernier commit"], [2],
      "git : Pull Request", "1:15"),
    q("C20", "qcm", "Gitea est…",
      ["un concurrent de git", "une sauvegarde automatique de GitHub",
       "une forge que l'on héberge soi-même, avec les mêmes commandes git", "un assistant d'IA pour écrire du code"], [3],
      "git : forge", "accueil"),
]

RESTITUTION = [
    q("D1", "nuage", "En un mot : « IA en médecine », cela vous évoque…"),
    q("D2", "ouverte", "Expliquez en une phrase, à un collègue non informaticien, la notion qui vous a le plus marqué."),
    q("D3", "sondage", "Qu'êtes-vous arrivé à faire pendant la séance ? (plusieurs réponses possibles)",
      ["Cloner le projet", "Créer ma branche", "Faire un commit", "Pousser ma branche", "Ouvrir une Pull Request",
       "Relire celle d'une autre équipe", "Faire passer la ligne de mon équipe au vert", "Lancer une extraction",
       "Comparer deux modèles", "Lire une trace"], plusieurs=True),
]

SATISFACTION = [
    q("E1", "echelle", "Votre avis sur la séance (1 = pas du tout d'accord, 5 = tout à fait d'accord)",
      ["Dans l'ensemble, cette séance m'a été utile", "Les objectifs étaient clairs dès le début",
       "J'ai pu participer activement, et pas seulement regarder", "Quand j'étais bloqué, j'ai obtenu de l'aide à temps",
       "Le support de cours m'a aidé à suivre"]),
    q("E2", "sondage", "La séance a-t-elle répondu à vos attentes ?",
      ["Oui, complètement", "En grande partie", "En partie seulement", "Non"]),
    q("E3", "ouverte", "Quelle attente n'a pas été satisfaite ? Qu'auriez-vous voulu voir en plus ?"),
    q("E4", "echelle", "Utilité de chaque partie pour vous (1 = inutile, 5 = très utile)", PARTIES),
    q("E5", "sondage", "La partie que vous avez préférée", PARTIES),
    q("E6", "sondage", "La partie la plus difficile à suivre", PARTIES + ["Aucune en particulier"]),
    q("E7", "sondage", "Le rythme était…", ["trop lent", "adapté", "trop rapide"]),
    q("E8", "sondage", "Le niveau technique était…",
      ["trop simple", "adapté", "trop difficile, mais j'ai suivi", "trop difficile, j'ai décroché"]),
    q("E9", "sondage", "Qu'allez-vous réutiliser ? (plusieurs réponses possibles)",
      ["git", "Faire tourner un modèle sur ma machine", "Valider la sortie d'une IA", "Mesurer avec une référence",
       "Comparer plusieurs modèles avant d'en choisir un", "Lire des traces", "Rien de particulier"], plusieurs=True),
    q("E10", "sondage", "Avant la séance, mon poste était prêt (projet cloné, brique téléchargée).",
      ["Oui", "En partie", "Non", "Je n'avais pas de machine utilisable"]),
    q("E11", "sondage", "Dans quelle équipe étiez-vous ?",
      ["0 Forge", "1 Réseau", "2 Inférence", "3 Passerelle", "4 Documents", "5 Observabilité", "6 Évaluation",
       "7 Applications", "8 Agents"]),
    q("E12", "ouverte", "Ce qui a le mieux fonctionné pour vous."),
    q("E13", "ouverte", "Ce qui vous a bloqué, ou ce qu'il faudrait changer."),
    q("E14", "ouverte", "Un sujet que vous aimeriez approfondir dans une prochaine séance."),
    q("E15", "echelle", "Recommanderiez-vous cet atelier à un autre étudiant ? (0 = certainement pas, 10 = certainement)",
      ["Ma recommandation"]),
]

QUESTIONNAIRES = {
    "pre-test": PROFIL + AUTO + CONNAISSANCES,
    "post-test": AUTO + CONNAISSANCES + RESTITUTION,
    "satisfaction": SATISFACTION,
}


def ecrire_classeur(nom: str, questions: list[dict]) -> Path:
    largeur = max(len(x["choix"]) for x in questions)
    wb = Workbook()
    ws = wb.active
    ws.title = "Questions"
    police = Font(name="Arial", size=10)
    ws.append([ENTETES["type"], ENTETES["titre"], ENTETES["correct"]]
              + [ENTETES["choix"].format(n=i) for i in range(1, largeur + 1)])
    for x in questions:
        correct = SEPARATEUR_CORRECT.join(str(n) for n in x["correct"])
        ws.append([TYPES[x["type"]], x["titre"], correct or None] + x["choix"])
    for row in ws.iter_rows():
        for cell in row:
            cell.font = police
            cell.alignment = Alignment(vertical="top", wrap_text=True)
    for cell in ws[1]:
        cell.font = Font(name="Arial", size=10, bold=True)
    ws.column_dimensions["A"].width = 14
    ws.column_dimensions["B"].width = 60
    ws.column_dimensions["C"].width = 9
    for i in range(largeur):
        ws.column_dimensions[ws.cell(row=1, column=4 + i).column_letter].width = 34
    ws.freeze_panes = "C2"
    chemin = ICI / f"{nom}.xlsx"
    wb.save(chemin)
    return chemin


def tableau(questions: list[dict], avec_notion: bool = False) -> str:
    tete = "| # | Type | Question | Réponses |" + (" Notion |" if avec_notion else "")
    lignes = [tete, "|---|---|---|---|" + ("---|" if avec_notion else "")]
    for x in questions:
        if x["type"] == "classement":
            choix = " · ".join(f"**{i}** {c}" for i, c in enumerate(x["choix"], 1))
        else:
            choix = " · ".join(f"**{c}**" if i in x["correct"] else c for i, c in enumerate(x["choix"], 1)) or "—"
        kind = LIBELLES[x["type"]] + (", plusieurs" if x["plusieurs"] else "")
        ligne = f"| {x['id']} | {kind} | {x['titre']} | {choix} |"
        lignes.append(ligne + (f" {x['notion']} |" if avec_notion else ""))
    return "\n".join(lignes)


def ecrire_evaluation() -> None:
    moments = "\n".join(f"| {x['id']} | {x['notion']} | {x['moment']} |" for x in CONNAISSANCES)
    EVALUATION.write_text(f"""# FARCI — pré-test, post-test et questionnaire de satisfaction (Wooclap)

> Fichier **généré** par `docs/support/wooclap/build_wooclap.py` : modifier les
> questions dans ce script, puis le relancer. Il écrit aussi les trois
> classeurs à importer dans Wooclap.

Le pré-test et le post-test posent **les mêmes questions de connaissance**,
dans le même ordre : c'est leur comparaison, question par question, qui mesure
ce que la séance a appris. Rien n'est noté ; tout est anonyme.

| Questionnaire | Fichier à importer | Quand | Durée | Contenu |
|---|---|---|---|---|
| **Pré-test** | `wooclap/pre-test.xlsx` | avant la séance, ou à l'arrivée | 9 min | profil et attentes (A), auto-évaluation (B), connaissances (C) |
| **Post-test** | `wooclap/post-test.xlsx` | à la clôture | 8 min | auto-évaluation (B), connaissances (C), restitution (D) |
| **Satisfaction** | `wooclap/satisfaction.xlsx` | juste après | 5 min | retour sur le contenu, les attentes, les parties utiles (E) |

Le pré-test est long pour un accueil de vingt minutes : l'envoyer **avant la
séance** (mode « au rythme du participant ») laisse l'accueil au clonage et à
la création de la branche.

## Importer dans Wooclap

Dans un événement : **Importer des questions → Depuis un fichier Excel**, puis
choisir le classeur. Créer trois événements, un par classeur.

Les classeurs suivent la forme du modèle Excel de Wooclap : une question par
ligne, colonnes `Type`, `Title`, `Correct`, puis une colonne par réponse ;
`Correct` porte le numéro de la ou des bonnes réponses. **Seuls l'intitulé
`MCQ` et ce principe sont confirmés.** Avant le premier import, télécharger le
modèle proposé par Wooclap dans cette même fenêtre et comparer ses en-têtes et
ses noms de types à ceux du script (`ENTETES`, `TYPES`) : s'ils diffèrent, les
corriger là et relancer le script.

Réglages conseillés : participation anonyme ; **bonnes réponses masquées au
pré-test** (sinon le post-test mesure la mémoire du corrigé), affichées au
post-test.

---

## A. Profil et attentes — pré-test seulement

{tableau(PROFIL)}

A6 est reposée au post-test (D1) : les deux nuages se projettent côte à côte.
A4 et A5 se relisent avec E2 et E3 : la séance a-t-elle répondu aux attentes ?

## B. Auto-évaluation — pré-test et post-test

{tableau(AUTO)}

## C. Connaissances — pré-test et post-test, à l'identique

La bonne réponse est en **gras**.

{tableau(CONNAISSANCES, avec_notion=True)}

### Où chaque question trouve sa réponse dans la séance

| Question | Notion | Moment |
|---|---|---|
{moments}

## D. Restitution — post-test seulement

{tableau(RESTITUTION)}

## E. Questionnaire de satisfaction

> Un questionnaire existe déjà sur le compte Wooclap du formateur : celui-ci
> est à fusionner avec lui. E4 à E6 portent sur le contenu propre à cet atelier.

{tableau(SATISFACTION)}

---

## Lire les résultats

- **Gain par question** : part de bonnes réponses au post-test moins part au
  pré-test (C1 à C20). Une question déjà réussie à plus de 80 % au pré-test
  désigne une notion connue : y passer moins de temps la prochaine fois.
- **Question sans gain** : la notion n'a pas été vue, ou la question est mal
  posée. Le tableau « Où chaque question trouve sa réponse » dit quel moment
  de la séance revoir.
- **Auto-évaluation contre connaissances** : B qui monte sans que C monte
  signale une confiance mal placée.
- **Attentes** : A4 (ce qu'ils attendaient) contre E2 et E3 (ce qu'ils ont
  eu). Une attente fréquente et non satisfaite est le premier sujet à ajouter.
- **Parties utiles** : E4 note chaque partie, E5 dit la préférée, E6 la plus
  difficile. Une partie jugée utile **et** difficile mérite plus de temps ;
  une partie jugée peu utile et facile peut être raccourcie.
- **Croiser avec le profil** : le gain sur C16 à C20 chez ceux qui ont répondu
  « jamais » à A1 est la mesure directe de l'objectif git.
- **Croiser avec E10 et E11** : un poste non préparé ou une équipe en
  difficulté explique souvent une mauvaise note de rythme.
""", encoding="utf-8")


def main() -> None:
    for nom, questions in QUESTIONNAIRES.items():
        chemin = ecrire_classeur(nom, questions)
        print(f"{chemin.relative_to(ICI.parents[2])} : {len(questions)} questions")
    ecrire_evaluation()
    print(f"{EVALUATION.relative_to(ICI.parents[2])} : régénéré")


if __name__ == "__main__":
    main()
