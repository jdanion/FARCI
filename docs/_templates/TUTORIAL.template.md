<!--
FARCI — gabarit de TUTORIAL.md (FARCI §45)

Chaque dossier d'équipe contient un TUTORIAL.md qui reprend EXACTEMENT les
sections ci-dessous (titres de niveau 2 dans le TUTORIAL, précédés d'un titre
« # TUTORIAL — Équipe X : <brique> »). `./bin/farci lint-docs` vérifie leur
présence : ce gabarit est la liste de référence.

Écart assumé au §45 : « Vérification dans Uptime Kuma » devient
« Vérification sur le tableau de bord », parce que le tableau projeté est
`./bin/farci status` (Uptime Kuma est une brique bonus). « Dépannage » est
ajouté : indispensable en atelier.

Règles d'écriture :
  - toutes les commandes se lancent depuis la RACINE du dépôt (pas de `cd`) ;
  - aucune adresse IP : on nomme la variable de config/network.env ;
  - une commande citée doit exister (`./bin/farci lint-commands` le vérifie).
-->

# Mission

Ce que l'équipe livre, en une ou deux phrases. L'objectif minimal (vert sur le
tableau) puis l'objectif bonus.

# Ce que votre service apporte

À quoi sert la brique dans la chaîne patient → variable de recherche, et ce
qui casse sans elle.

# Ce que vous devez comprendre

Les deux ou trois notions à savoir expliquer avec vos mots, avec leur analogie
médicale (voir le README).

# Vos dépendances

Les briques qui doivent tourner avant la vôtre, et celles qui dépendent de vous.

# Votre IP

Le nom de la variable de `config/network.env` (et du port) qui porte votre
adresse. Jamais l'adresse elle-même.

# Installation

Ce qui doit être présent sur la machine (images préchargées, poids, wheels).

# Configuration

Les fichiers à relire ou adapter, et les variables utiles.

# Démarrage

La commande `./bin/farci up <dossier>` et ce qu'on doit voir.

# Test local

Comment vérifier que la brique répond, sur votre machine.

# Test contractuel

Le test qui prouve que la brique respecte son contrat (`./bin/farci test`).

# Vérification sur le tableau de bord

La ligne de `./bin/farci status` qui doit passer au vert.

# Commit

Ce qu'on versionne (configuration, jamais de secret ni de poids).

# Pull Request

Ce que doit contenir la PR, et qui la relit.

# Définition de DONE

```text
[ ] service démarré
[ ] sonde verte sur ./bin/farci status
[ ] test contractuel réussi
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

# Dépannage

Les trois pannes les plus probables, leur symptôme et la commande qui répare.
