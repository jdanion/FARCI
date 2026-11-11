# FARCI — pré-test, post-test et questionnaire de satisfaction (Wooclap)

> Brouillon. Trois questionnaires à créer dans Wooclap. Le pré-test et le
> post-test posent **les mêmes questions de connaissance**, dans le même
> ordre : c'est leur comparaison, question par question, qui mesure ce que la
> séance a appris. Rien n'est noté ; tout est anonyme.

| Questionnaire | Quand | Durée | Contenu |
|---|---|---|---|
| **Pré-test** | 0:00, à l'arrivée | 6 min | profil (A), auto-évaluation (B), connaissances (C) |
| **Post-test** | 3:50, à la clôture | 6 min | auto-évaluation (B), connaissances (C), restitution (D) |
| **Satisfaction** | juste après | 3 min | retour sur la séance (E) |

Réglages Wooclap conseillés : participation anonyme, **bonnes réponses
masquées au pré-test** (sinon le post-test mesure la mémoire du corrigé),
affichées au post-test ; rythme « au rythme du participant » pour les deux
tests.

---

## A. Profil — pré-test seulement

| # | Type Wooclap | Question | Réponses |
|---|---|---|---|
| A1 | Sondage | Avez-vous déjà utilisé git ? | Jamais entendu parler · J'en ai entendu parler · Quelques commandes, en suivant un tutoriel · Je m'en sers régulièrement |
| A2 | Sondage | Avez-vous déjà fait tourner un modèle de langage sur votre propre ordinateur ? | Non, et je ne savais pas que c'était possible · Non, mais je sais que cela existe · Oui, une fois · Oui, régulièrement |
| A3 | Sondage | Vous utilisez un assistant d'IA (ChatGPT, Claude, Mistral…) | Jamais · Quelques fois par mois · Chaque semaine · Chaque jour |
| A4 | Nuage de mots | En un mot : « IA en médecine », cela vous évoque… | — |

A4 est reposée au post-test (D1) : les deux nuages se projettent côte à côte.

---

## B. Auto-évaluation — pré-test et post-test

Type Wooclap : **Échelle**, de 1 (pas du tout) à 5 (tout à fait).
« Je me sens capable d'expliquer à un collègue… »

| # | Énoncé |
|---|---|
| B1 | … la différence entre un modèle et le logiciel qui l'exécute |
| B2 | … pourquoi la réponse d'une IA doit être vérifiée avant d'entrer dans une base de recherche |
| B3 | … ce que veut dire « un F1 de 0,84 » |
| B4 | … ce qu'est une branche git, et à quoi elle sert |
| B5 | … ce qui, dans une IA utilisée à l'hôpital, peut ou non passer par Internet |

---

## C. Connaissances — pré-test et post-test, à l'identique

La bonne réponse est en **gras**. « QCM » : une seule bonne réponse, sauf
mention « plusieurs ».

| # | Type | Question | Réponses | Notion |
|---|---|---|---|---|
| C1 | QCM | Un modèle de langage répond à une question clinique. Que fait-il réellement ? | Il consulte une base de connaissances médicales validée · **Il produit, mot après mot, la suite la plus plausible** · Il cherche la réponse sur Internet · Il applique des règles écrites par des médecins | 1 |
| C2 | QCM | Ollama et llama.cpp sont… | deux modèles de langage · **deux logiciels capables d'exécuter un même modèle** · deux jeux de données médicales · deux fournisseurs d'IA en ligne | 2 |
| C3 | QCM, plusieurs | À quoi sert une passerelle LLM ? | **Offrir un point d'entrée unique aux applications** · **Basculer sur un autre serveur en cas de panne** · Améliorer la justesse médicale des réponses · **Distribuer des clés et limiter le débit** | 3 |
| C4 | QCM | On remplace le logiciel qui exécute le modèle, derrière la passerelle. Que faut-il changer dans l'application ? | **Rien** · L'adresse à laquelle elle se connecte · La consigne (le prompt) envoyée au modèle · Presque tout : il faut la réécrire | 4 |
| C5 | QCM | Le modèle renvoie « âge : soixante ans » là où un nombre est attendu. Que doit faire la chaîne de traitement ? | Enregistrer la réponse : le sens est clair · **Rejeter la réponse et ne rien écrire dans la base** · Corriger la valeur sans le signaler · Supprimer le dossier du patient | 5 |
| C6 | QCM | Pseudonymiser un compte rendu avant de le confier au modèle, c'est… | supprimer toutes les informations médicales · chiffrer le fichier · **remplacer les identifiants par des jetons, en gardant le lien entre les documents d'un même patient** · rendre toute réidentification définitivement impossible | 5 |
| C7 | QCM | Un article annonce : « notre système atteint un F1 de 0,84 ». Qu'en concluez-vous ? | Le système est fiable · 84 % des patients sont bien classés · Le système invente 16 % de ses réponses · **Rien, tant qu'on ne sait pas à quelle référence il a été comparé** | 6 |
| C8 | QCM | Un système signale 10 complications ; 8 sont réelles. Il y en avait 16 à trouver. | Précision 50 %, rappel 80 % · **Précision 80 %, rappel 50 %** · Précision 80 %, rappel 80 % · Précision 62 %, rappel 50 % | 6 |
| C9 | QCM | L'outil qui enregistre les traces tombe en panne pendant une extraction. Dans une plateforme bien conçue… | l'extraction s'arrête, par sécurité · les résultats deviennent faux · **l'extraction continue ; seules les traces manquent** · le traitement bascule sur un service en ligne | 8, 9 |
| C10 | QCM, plusieurs | Dans une plateforme d'IA « locale », que peut-on laisser passer par Internet ? | **Le code du projet** · **Le fichier du modèle, quand on le télécharge** · Les comptes rendus des patients · Les questions posées au modèle et ses réponses | 10 |
| C11 | QCM | Dans git, une branche sert à… | sauvegarder le projet en ligne · **travailler sur sa version sans modifier celle des autres** · effacer l'historique · copier le projet sur une clé USB | git |
| C12 | Classement | Remettez ces gestes dans l'ordre. | **1** cloner le projet · **2** créer sa branche · **3** modifier un fichier · **4** enregistrer la modification (commit) · **5** la publier (push) · **6** demander une relecture (Pull Request) | git |
| C13 | QCM | Gitea est… | un concurrent de git · une sauvegarde automatique de GitHub · **une forge que l'on héberge soi-même, avec les mêmes commandes git** · un assistant d'IA pour écrire du code | git |

La colonne « Notion » renvoie aux dix notions du support (`COURS.md`, § 2).

### Où chaque question trouve sa réponse dans la séance

| Question | Moment |
|---|---|
| C1 | étape 2, premier JSON rejeté |
| C2, C4 | étape 1, équipe 2 : le même nom `med-extraction` servi par deux runtimes ; panne 06 |
| C3 | étape 1, équipe 3 ; panne 01 |
| C5 | étape 2 ; panne 04 |
| C6 | étape 2, équipe 4 |
| C7, C8 | évaluation : le classement projeté |
| C9 | panne 07 |
| C10 | accueil, et tout au long : rien ne sort de la salle |
| C11, C12, C13 | accueil, 0:20 (premier commit), 1:15 (push et Pull Request) |

---

## D. Restitution — post-test seulement

| # | Type | Question |
|---|---|---|
| D1 | Nuage de mots | En un mot : « IA en médecine », cela vous évoque… |
| D2 | Question ouverte | Expliquez en une phrase, à un collègue non informaticien, la notion qui vous a le plus marqué. |
| D3 | Sondage, plusieurs | Qu'êtes-vous arrivé à faire pendant la séance ? — Cloner le projet · Créer ma branche · Faire un commit · Pousser ma branche · Ouvrir une Pull Request · Relire celle d'une autre équipe · Faire passer la ligne de mon équipe au vert · Lancer une extraction · Lire une trace |

---

## E. Questionnaire de satisfaction

> Un questionnaire existe déjà sur le compte Wooclap du formateur : cette
> section est une proposition, à fusionner avec lui. Les questions E7 à E9
> sont propres à cet atelier.

| # | Type | Question | Réponses |
|---|---|---|---|
| E1 | Échelle 1–5 | Dans l'ensemble, cette séance m'a été utile. | pas du tout → tout à fait |
| E2 | Échelle 1–5 | Les objectifs étaient clairs dès le début. | |
| E3 | Sondage | Le rythme était… | trop lent · adapté · trop rapide |
| E4 | Sondage | Le niveau technique était… | trop simple · adapté · trop difficile, mais j'ai suivi · trop difficile, j'ai décroché |
| E5 | Échelle 1–5 | J'ai pu participer activement, et pas seulement regarder. | |
| E6 | Échelle 1–5 | Quand j'étais bloqué, j'ai obtenu de l'aide à temps. | |
| E7 | Sondage, plusieurs | Qu'allez-vous réutiliser ? | git · faire tourner un modèle sur ma machine · valider la sortie d'une IA · mesurer avec une référence · lire des traces · rien de particulier |
| E8 | Sondage | Avant la séance, mon poste était prêt (projet cloné, brique téléchargée). | Oui · En partie · Non · Je n'avais pas de machine utilisable |
| E9 | Sondage | Dans quelle équipe étiez-vous ? | 0 Forge · 1 Réseau · 2 Inférence · 3 Passerelle · 4 Documents · 5 Observabilité · 6 Évaluation · 7 Applications · 8 Agents |
| E10 | Question ouverte | Ce qui a le mieux fonctionné pour vous. | |
| E11 | Question ouverte | Ce qui vous a bloqué, ou ce qu'il faudrait changer. | |
| E12 | Échelle 0–10 | Recommanderiez-vous cet atelier à un autre étudiant ? | |

---

## Lire les résultats

- **Gain par question** : part de bonnes réponses au post-test moins part au
  pré-test (C1 à C13). Une question déjà réussie à plus de 80 % au pré-test
  désigne une notion connue : y passer moins de temps la prochaine fois.
- **Question sans gain** : la notion n'a pas été vue, ou la question est mal
  posée. Le tableau « Où chaque question trouve sa réponse » dit quel moment
  de la séance revoir.
- **Auto-évaluation contre connaissances** : B1 à B5 qui montent sans que C
  monte signalent une confiance mal placée.
- **Croiser avec le profil** : le gain sur C11 à C13 chez ceux qui ont répondu
  « jamais » à A1 est la mesure directe de l'objectif git.
- **Croiser avec E8 et E9** : un poste non préparé ou une équipe en difficulté
  explique souvent une mauvaise note de rythme.
