#!/usr/bin/env bash
# FARCI — scénario 04 : sortie JSON invalide
#
# Action    : extraire avec `med-chaos`, un modèle de test déclaré à la
#             passerelle, qui renvoie une sortie hors schéma (vrai mécanisme,
#             pas une fausse URL).
# Attendu   : chaque dossier est REJETÉ par la validation ; aucun fichier écrit.
# Leçon     : une sortie de LLM ne devient une donnée qu'une fois validée.

SCENARIO_TITLE="Sortie JSON invalide (modèle med-chaos)"
SCENARIO_ATTENDU="dossiers rejetés, aucun fichier écrit"

chaos_scenario_apply() {
  info "extraction de 3 dossiers avec le modèle med-chaos…"
  read -r CHAOS_ECRITS CHAOS_REJETES CHAOS_ERREURS <<< "$(chaos_extract 3 med-chaos)"
  info "écrits : $CHAOS_ECRITS, rejetés : $CHAOS_REJETES, erreurs d'appel : $CHAOS_ERREURS"
}

chaos_scenario_check() {
  chaos_expect "aucun dossier écrit, 3 rejetés" test "${CHAOS_ECRITS:-1}" = 0 -a "${CHAOS_REJETES:-0}" = 3
}

chaos_scenario_revert() {
  ok "rien à réparer : rien n'a été écrit"
}
