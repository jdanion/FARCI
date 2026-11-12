# FARCI — pré-test, post-test et questionnaire de satisfaction (Wooclap)

> Fichier **généré** par `docs/support/wooclap/build_wooclap.py` : modifier les
> questions dans ce script, puis le relancer. Il écrit aussi les trois
> classeurs à importer dans Wooclap.

Le pré-test et le post-test posent **les mêmes questions de connaissance**,
dans le même ordre : c'est leur comparaison, question par question, qui mesure
ce que la séance a appris. Rien n'est noté ; tout est anonyme.

| Questionnaire | Fichier à importer | Quand | Durée | Contenu |
|---|---|---|---|---|
| **Pré-test** | `wooclap/pre-test.xlsx` | avant la séance, ou à l'arrivée | 10 min | profil et attentes (A), auto-évaluation (B), connaissances (C) |
| **Post-test** | `wooclap/post-test.xlsx` | à la clôture | 8 min | auto-évaluation (B), connaissances (C), restitution (D) |
| **Satisfaction** | `wooclap/satisfaction.xlsx` | juste après | 6 min | retour sur le format, le contenu, les attentes, les parties utiles (E) |

Le pré-test est long pour un accueil de vingt minutes : l'envoyer **avant la
séance** (mode « au rythme du participant ») laisse l'accueil au clonage et à
la création de la branche.

## Importer dans Wooclap

Dans un événement : **Importer des questions → Depuis un fichier Excel**, puis
choisir le classeur. Créer trois événements, un par classeur.

Les classeurs suivent la forme du modèle Excel de Wooclap : une question par
ligne, et la ligne d'en-tête `Type`, `Title`, `Correct`, `Choice` de l'export
Wooclap du formateur ; les réponses occupent la colonne `Choice` et les
suivantes, et `Correct` porte le numéro de la ou des bonnes réponses.
**L'en-tête et l'intitulé `MCQ` sont confirmés ; les noms des autres types de
question ne le sont pas.** Si l'import en refuse un, créer à la main une
question de ce type dans Wooclap, exporter l'événement, lire le nom dans la
colonne `Type`, puis le corriger dans le script (`TYPES`) et le relancer.

Réglages conseillés : participation anonyme ; **bonnes réponses masquées au
pré-test** (sinon le post-test mesure la mémoire du corrigé), affichées au
post-test.

---

## A. Profil et attentes — pré-test seulement

| # | Type | Question | Réponses |
|---|---|---|---|
| A1 | Sondage | Avez-vous déjà utilisé git ? | Jamais entendu parler · J'en ai entendu parler · Quelques commandes, en suivant un tutoriel · Je m'en sers régulièrement |
| A2 | Sondage | Avez-vous déjà fait tourner un modèle de langage sur votre propre ordinateur ? | Non, et je ne savais pas que c'était possible · Non, mais je sais que cela existe · Oui, une fois · Oui, régulièrement |
| A3 | Sondage | Vous utilisez un assistant d'IA (ChatGPT, Claude, Mistral…) | Jamais · Quelques fois par mois · Chaque semaine · Chaque jour |
| A4 | Sondage, plusieurs | Qu'attendez-vous surtout de cette séance ? (plusieurs réponses possibles) | Comprendre comment fonctionne un modèle de langage · Savoir si l'on peut s'y fier pour des données médicales · Apprendre à me servir de git · Faire tourner une IA sur ma propre machine · Savoir évaluer un outil d'IA avant de l'adopter · Je ne sais pas encore |
| A5 | Question ouverte | Une question à laquelle vous aimeriez avoir une réponse en sortant de la séance. | — |
| A6 | Nuage de mots | En un mot : « IA en médecine », cela vous évoque… | — |

A6 est reposée au post-test (D1) : les deux nuages se projettent côte à côte.
A4 et A5 se relisent avec E4 et E5 : la séance a-t-elle répondu aux attentes ?

## B. Auto-évaluation — pré-test et post-test

| # | Type | Question | Réponses |
|---|---|---|---|
| B1 | Échelle | Je me sens capable d'expliquer à un collègue… (1 = pas du tout, 5 = tout à fait) | la différence entre un modèle et le logiciel qui l'exécute · comment choisir un modèle selon la machine dont on dispose · pourquoi la réponse d'une IA doit être vérifiée avant d'entrer dans une base de recherche · ce que veut dire « un rappel de 0,80 », et son équivalent en médecine · ce qu'est une branche git, et à quoi elle sert · ce qui, dans une IA utilisée à l'hôpital, peut ou non passer par Internet |

## C. Connaissances — pré-test et post-test, à l'identique

La bonne réponse est en **gras**.

| # | Type | Question | Réponses | Notion |
|---|---|---|---|---|
| C1 | QCM | Un modèle de langage répond à une question clinique. Que fait-il réellement ? | Il consulte une base de connaissances médicales validée · **Il produit, mot après mot, la suite la plus plausible** · Il cherche la réponse sur Internet · Il applique des règles écrites par des médecins | LLM probabiliste |
| C2 | QCM | Ollama et llama.cpp sont… | deux modèles de langage · **deux logiciels capables d'exécuter un même modèle** · deux jeux de données médicales · deux fournisseurs d'IA en ligne | modèle ≠ runtime |
| C3 | QCM | Dans le nom de fichier « Qwen3.5-4B-Q4_K_M.gguf », que désigne « Q4 » ? | La quatrième version du modèle · 4 milliards de paramètres · **La compression : 4 bits par paramètre, un fichier plus petit et un peu moins précis** · 4 Go de mémoire nécessaires | quantification |
| C4 | QCM | Par rapport à un modèle généraliste de même taille, MedGemma 4B est… | un dispositif médical certifié · **un modèle réentraîné sur des textes médicaux** · une base de données médicale interrogeable · un modèle plus gros, donc plus lent | types de modèles |
| C5 | QCM, plusieurs | À quoi sert une passerelle LLM ? (plusieurs réponses) | **Offrir un point d'entrée unique aux applications** · **Basculer sur un autre serveur en cas de panne** · Améliorer la justesse médicale des réponses · **Distribuer des clés et limiter le débit** | passerelle |
| C6 | QCM | On remplace le modèle servi derrière la passerelle. Que faut-il changer dans l'application ? | **Rien** · L'adresse à laquelle elle se connecte · La consigne (le prompt) envoyée au modèle · Presque tout : il faut la réécrire | contrat |
| C7 | QCM | Dans la chaîne d'extraction, à quoi sert Pydantic ? | À vérifier que les valeurs extraites sont médicalement justes · **À vérifier que la réponse du modèle respecte le formulaire : types, bornes, valeurs permises** · À retirer les noms des patients avant le traitement · À accélérer le modèle | validation |
| C8 | QCM | Le modèle renvoie « âge : soixante ans » là où un nombre est attendu. Que doit faire la chaîne de traitement ? | Enregistrer la réponse : le sens est clair · **Rejeter la réponse et ne rien écrire dans la base** · Corriger la valeur sans le signaler · Supprimer le dossier du patient | validation |
| C9 | QCM | Le modèle répond « âge : 76 » pour un patient de 67 ans. Qui repère l'erreur ? | Pydantic : il rejette la réponse · **La comparaison à la référence (gold standard) : Pydantic, lui, l'accepte** · La passerelle · Personne : cette erreur est indétectable | forme ≠ fond |
| C10 | QCM | Pseudonymiser un compte rendu avant de le confier au modèle, c'est… | supprimer toutes les informations médicales · chiffrer le fichier · **remplacer les identifiants par des jetons, en gardant le lien entre les documents d'un même patient** · rendre toute réidentification définitivement impossible | pseudonymisation |
| C11 | QCM | Un article annonce : « notre système atteint un F1 de 0,84 ». Qu'en concluez-vous ? | Le système est fiable · 84 % des patients sont bien classés · Le système invente 16 % de ses réponses · **Rien, tant qu'on ne sait pas à quelle référence il a été comparé** | référence |
| C12 | QCM | Un système signale 10 complications ; 8 sont réelles. Il y en avait 16 à trouver. | Précision 50 %, rappel 80 % · **Précision 80 %, rappel 50 %** · Précision 80 %, rappel 80 % · Précision 62 %, rappel 50 % | précision et rappel |
| C13 | QCM | Le compte rendu indique une marge R0 ; le modèle répond « non précisé ». Quelle mesure baisse ? | **Le rappel : une valeur à trouver a été manquée** · La précision : le modèle a inventé une valeur · Les deux · Aucune : « non précisé » est toujours une bonne réponse | rappel |
| C21 | QCM | Le rappel d'un système d'extraction correspond, pour un test diagnostique, à… | la spécificité · **la sensibilité** · la valeur prédictive positive · la valeur prédictive négative | rappel = sensibilité |
| C22 | QCM | Un modèle signale une complication rare (5 % des dossiers) avec une sensibilité de 90 % et une spécificité de 95 %. Quand il la signale… | il a raison dans 95 % des cas · il a raison dans 90 % des cas · **il a raison environ une fois sur deux : la complication est rare** · on ne peut rien en dire | précision = VPP, prévalence |
| C14 | QCM | L'outil qui enregistre les traces tombe en panne pendant une extraction. Dans une plateforme bien conçue… | l'extraction s'arrête, par sécurité · les résultats deviennent faux · **l'extraction continue ; seules les traces manquent** · le traitement bascule sur un service en ligne | résilience, observabilité |
| C15 | QCM, plusieurs | Dans une plateforme d'IA « locale », que peut-on laisser passer par Internet ? (plusieurs réponses) | **Le code du projet** · **Le fichier du modèle, quand on le télécharge** · Les comptes rendus des patients · Les questions posées au modèle et ses réponses | local d'abord |
| C16 | QCM | Dans git, une branche sert à… | sauvegarder le projet en ligne · **travailler sur sa version sans modifier celle des autres** · effacer l'historique · copier le projet sur une clé USB | git : branche |
| C17 | Classement | Remettez ces gestes dans l'ordre. | **1** cloner le projet · **2** créer sa branche · **3** modifier un fichier · **4** enregistrer la modification (commit) · **5** la publier (push) · **6** demander une relecture (Pull Request) | git : parcours |
| C18 | QCM | Que montre la commande « git diff » ? | La liste des branches du projet · **Les lignes ajoutées et retirées depuis le dernier commit** · Les différences entre GitHub et Gitea · Les fichiers trop lourds pour git | git : diff |
| C19 | QCM | Une Pull Request sert à… | télécharger le projet · **faire relire sa branche avant qu'elle soit intégrée au travail commun** · supprimer une branche · annuler son dernier commit | git : Pull Request |
| C20 | QCM | Gitea est… | un concurrent de git · une sauvegarde automatique de GitHub · **une forge que l'on héberge soi-même, avec les mêmes commandes git** · un assistant d'IA pour écrire du code | git : forge |

### Où chaque question trouve sa réponse dans la séance

| Question | Notion | Moment |
|---|---|---|
| C1 | LLM probabiliste | étape 2, premier JSON rejeté |
| C2 | modèle ≠ runtime | étape 1, équipe 2 |
| C3 | quantification | diaporama « Lire le nom d'un modèle » |
| C4 | types de modèles | étape 2, comparaison des trois 4B |
| C5 | passerelle | étape 1, équipe 3 ; panne 01 |
| C6 | contrat | étape 2, changement de modèle ; panne 06 |
| C7 | validation | étape 2 ; diaporama « Pydantic » |
| C8 | validation | étape 2 ; panne 04 |
| C9 | forme ≠ fond | évaluation ; diaporama « Bien formé ne veut pas dire juste » |
| C10 | pseudonymisation | étape 2, équipe 4 |
| C11 | référence | évaluation : le classement projeté |
| C12 | précision et rappel | évaluation |
| C13 | rappel | évaluation ; diaporama « Quatre issues pour chaque champ » |
| C21 | rappel = sensibilité | évaluation ; diaporama « Vous connaissez déjà ces mesures » |
| C22 | précision = VPP, prévalence | évaluation ; diaporama « La prévalence compte » |
| C14 | résilience, observabilité | panne 07 |
| C15 | local d'abord | accueil, et tout au long |
| C16 | git : branche | accueil |
| C17 | git : parcours | accueil, 0:20, 1:15 |
| C18 | git : diff | 0:20, avant le premier commit |
| C19 | git : Pull Request | 1:15 |
| C20 | git : forge | accueil |

## D. Restitution — post-test seulement

| # | Type | Question | Réponses |
|---|---|---|---|
| D1 | Nuage de mots | En un mot : « IA en médecine », cela vous évoque… | — |
| D2 | Question ouverte | Expliquez en une phrase, à un collègue non informaticien, la notion qui vous a le plus marqué. | — |
| D3 | Sondage, plusieurs | Qu'êtes-vous arrivé à faire pendant la séance ? (plusieurs réponses possibles) | Cloner le projet · Créer ma branche · Faire un commit · Pousser ma branche · Ouvrir une Pull Request · Relire celle d'une autre équipe · Faire passer la ligne de mon équipe au vert · Lancer une extraction · Comparer deux modèles · Lire une trace |

## E. Questionnaire de satisfaction

> Pensé pour des étudiants en médecine dans une séance inhabituelle pour eux :
> un atelier technique, en équipe, au terminal. E2 et E3 demandent s'ils s'y
> sont sentis à leur place et si le format les a aidés ; E6 à E8 portent sur
> le contenu ; E11 et E12 sur ce qu'ils en feront.

| # | Type | Question | Réponses |
|---|---|---|---|
| E1 | Échelle | Votre avis sur la séance (1 = pas du tout d'accord, 5 = tout à fait d'accord) | Dans l'ensemble, cette séance m'a été utile · Les objectifs étaient clairs dès le début · J'ai pu participer activement, et pas seulement regarder · Quand j'étais bloqué, j'ai obtenu de l'aide à temps · Le travail en équipe a bien fonctionné · Le support de cours m'a aidé à suivre |
| E2 | Échelle | Un atelier d'informatique pour des étudiants en médecine (1 = pas du tout d'accord, 5 = tout à fait d'accord) | Je me suis senti à ma place, sans être informaticien · Les comparaisons avec la médecine (dossier patient, sensibilité, dépistage) m'ont aidé à comprendre · Je vois le lien avec ma future pratique ou avec un travail de recherche · Je lirai d'un œil plus critique un article ou un outil qui évalue une IA en santé · Je saurais dire à un patient ou à un collègue ce qu'une IA peut et ne peut pas faire |
| E3 | Sondage | Construire soi-même plutôt qu'écouter un cours : pour apprendre ces notions, ce format était… | bien plus efficace qu'un cours magistral · un peu plus efficace · équivalent · moins efficace : j'aurais préféré un cours |
| E4 | Sondage | La séance a-t-elle répondu à vos attentes ? | Oui, complètement · En grande partie · En partie seulement · Non |
| E5 | Question ouverte | Quelle attente n'a pas été satisfaite ? Qu'auriez-vous voulu voir en plus ? | — |
| E6 | Échelle | Utilité de chaque partie pour vous (1 = inutile, 5 = très utile) | Git : cloner, sa branche, commit, Pull Request · Construire la brique de son équipe (étape 1) · Les modèles : tailles, familles, lesquels comparer · L'extraction des dossiers (étape 2) · Pydantic : valider la réponse du modèle · Rappel, précision et lecture du classement · Les pannes provoquées (étape 3) · Le support de cours et le diaporama |
| E7 | Sondage | La partie que vous avez préférée | Git : cloner, sa branche, commit, Pull Request · Construire la brique de son équipe (étape 1) · Les modèles : tailles, familles, lesquels comparer · L'extraction des dossiers (étape 2) · Pydantic : valider la réponse du modèle · Rappel, précision et lecture du classement · Les pannes provoquées (étape 3) · Le support de cours et le diaporama |
| E8 | Sondage | La partie la plus difficile à suivre | Git : cloner, sa branche, commit, Pull Request · Construire la brique de son équipe (étape 1) · Les modèles : tailles, familles, lesquels comparer · L'extraction des dossiers (étape 2) · Pydantic : valider la réponse du modèle · Rappel, précision et lecture du classement · Les pannes provoquées (étape 3) · Le support de cours et le diaporama · Aucune en particulier |
| E9 | Sondage | Le rythme était… | trop lent · adapté · trop rapide |
| E10 | Sondage | Le niveau technique était… | trop simple · adapté · trop difficile, mais j'ai suivi · trop difficile, j'ai décroché |
| E11 | Sondage, plusieurs | Qu'allez-vous réutiliser ? (plusieurs réponses possibles) | git, pour un mémoire, une thèse ou un projet · Faire tourner un modèle sur ma machine, sans envoyer de données en ligne · Vérifier la sortie d'une IA avant de m'en servir · Demander à quelle référence un score a été comparé · Comparer plusieurs modèles avant d'en choisir un · Rien de particulier |
| E12 | Sondage | Cette séance vous donne-t-elle envie d'utiliser ces outils dans un travail de recherche (thèse, mémoire) ? | Oui, j'ai déjà une idée · Peut-être, si j'étais accompagné · Non · Je ne suis pas concerné pour l'instant |
| E13 | Sondage | Avant la séance, mon poste était prêt (projet cloné, brique téléchargée). | Oui · En partie · Non · Je n'avais pas de machine utilisable |
| E14 | Sondage | Dans quelle équipe étiez-vous ? | 0 Forge · 1 Réseau · 2 Inférence · 3 Passerelle · 4 Documents · 5 Observabilité · 6 Évaluation · 7 Applications · 8 Agents |
| E15 | Question ouverte | Ce qui a le mieux fonctionné pour vous. | — |
| E16 | Question ouverte | Ce qui vous a bloqué, ou ce qu'il faudrait changer. | — |
| E17 | Question ouverte | Un sujet que vous aimeriez approfondir dans une prochaine séance. | — |
| E18 | Échelle | Recommanderiez-vous cet atelier à un autre étudiant en médecine ? (0 = certainement pas, 10 = certainement) | Ma recommandation |

---

## Lire les résultats

- **Gain par question** : part de bonnes réponses au post-test moins part au
  pré-test (C1 à C22). Une question déjà réussie à plus de 80 % au pré-test
  désigne une notion connue : y passer moins de temps la prochaine fois.
- **Question sans gain** : la notion n'a pas été vue, ou la question est mal
  posée. Le tableau « Où chaque question trouve sa réponse » dit quel moment
  de la séance revoir.
- **Auto-évaluation contre connaissances** : B qui monte sans que C monte
  signale une confiance mal placée.
- **Attentes** : A4 (ce qu'ils attendaient) contre E4 et E5 (ce qu'ils ont
  eu). Une attente fréquente et non satisfaite est le premier sujet à ajouter.
- **Parties utiles** : E6 note chaque partie, E7 dit la préférée, E8 la plus
  difficile. Une partie jugée utile **et** difficile mérite plus de temps ;
  une partie jugée peu utile et facile peut être raccourcie.
- **Croiser avec le profil** : le gain sur les questions de git chez ceux qui ont répondu
  « jamais » à A1 est la mesure directe de l'objectif git.
- **Le format** : E2 et E3 disent si un atelier technique convient à des
  étudiants en médecine. Un « je me suis senti à ma place » bas avec un niveau
  jugé trop difficile (E10) appelle plus d'accompagnement, pas moins de contenu.
- **Croiser avec E13 et E14** : un poste non préparé ou une équipe en
  difficulté explique souvent une mauvaise note de rythme.
