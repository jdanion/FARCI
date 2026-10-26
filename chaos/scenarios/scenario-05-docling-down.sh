#!/usr/bin/env bash
# FARCI — scénario 05 : Docling indisponible
#
# Action    : l'accueil ne sert plus la chaîne documentaire.
# Attendu   : /docling ne répond plus ; l'extraction des dossiers texte
#             continue ; le tableau passe en DEGRADED.
# Leçon     : les dépendances sont partielles ; savoir ce qui tient compte autant.

SCENARIO_TITLE="Docling indisponible"
SCENARIO_ATTENDU="/docling coupé, l'extraction texte continue"

chaos_scenario_apply() {
  chaos_route block documents
}

chaos_scenario_check() {
  local docling written
  docling="$(http_code "${FARCI_DOCLING_URL:?FARCI_DOCLING_URL manquante}/health" 5)"
  read -r written _ _ <<< "$(chaos_extract 1)"
  chaos_expect "Docling ne répond plus (HTTP $docling)" test "$docling" != 200 \
    && chaos_expect "l'extraction texte continue ($written dossier écrit)" test "$written" = 1
}

chaos_scenario_revert() {
  chaos_route_clear documents
  ok "chaîne documentaire rendue à l'accueil"
}
