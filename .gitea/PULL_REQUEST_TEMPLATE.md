# ---------------------------------------------------------------------------
# Bout de Pull Request — FARCI
# ---------------------------------------------------------------------------
# Une Pull Request est l'unité de revue ET d'intégration de l'infrastructure.
# Une brique non intégrée n'existe pas pour le reste de l'atelier.
# ---------------------------------------------------------------------------

## Quelle brique cette Pull Request apporte-t-elle ?

<!-- Équipe 0 à 7, et la brique concernée. -->

- Équipe : <!-- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7 -->
- Brique : <!-- ex. runtime llama.cpp, passerelle Bifrost, sondes Uptime Kuma -->
- Implémentation : <!-- ex. LiteLLM (option 3A) -->
- Le contrat est-il inchangé ? <!-- oui / non, et pourquoi c'est justifié -->

## Le problème que cela résout

<!-- Une phrase, en langage non technique. Un relecteur non technique doit comprendre. -->

## Ce que le rellecteur doit savoir pour comprendre

<!-- Une phrase expliquant le choix d'implémentation, surtout si une option
     était disponible et n'a pas été retenue. -->

## Vérifications faites

- [ ] `./bin/farci lint` est vert
- [ ] `./bin/farci selftest` est vert
- [ ] Le **test contractuel** de l'équipe passe
  (`tests/test_<sujet>.sh` — préciser la commande et son résultat)
- [ ] Le **healthcheck** est vert sur un endpoint réel, pas sur « le processus existe »
- [ ] Le service apparaît **UP** dans le tableau de progression
- [ ] `./bin/farci status` ne régresse pas

## Contrat

- [ ] Les points d'interface décrits dans `CONTRACTS.md` sont respectés
- [ ] Aucun appel sortant (air-gap)
- [ ] Les erreurs ont des **codes** documentés, pas du texte libre
- [ ] Les en-têtes de propagation (`traceparent`, `X-Request-Id`) sont relayés

## Versionnement et air-gap

- [ ] `versions.env` est à jour si une version a changé (jamais `latest`)
- [ ] Aucune ressource distante (CDN, police, script distant)
- [ ] Aucun secret dans le dépôt

## Données

- [ ] Aucune donnée réelle de patient n'apparaît
- [ ] Si des données synthétiques ont été ajoutées, le générateur reste
      **déterministe** (même graine → mêmes fichiers)

## Documentation

- [ ] `NN-<équipe>/TUTORIAL.md` est à jour, avec ses 14 sections
- [ ] Les décisions non évidentes sont commentées **dans le code**, pas seulement ici

## Ce que je n'ai pas fait, et pourquoi

<!--
Section la plus utile du formulaire. Elle évite les surprises en revue et
documente les arbitrages.
-->

## Captures ou traces utiles pour la revue

<!--
Pour une brique d'observabilité : un extrait de trace.
Pour une brique d'extraction : le JSON de sortie contre le gold.
-->
