#!/usr/bin/env bash
# FARCI — scénario 04 : JSON invalide
#
# Attendu : Pydantic ValidationError, aucun fichier écrit
# Mécanisme réel : modèle de test med-chaos volontairement non conforme

SCENARIO_TITLE="Sortie JSON invalide (modèle med-chaos)"

chaos_scenario_apply() {
  info "test de JSON invalide (modèle med-chaos)..."

  # Appeler le modèle med-chaos qui renvoie un JSON hors schéma
  response=$(curl -sf --max-time 60 -X POST "${FARCI_GATEWAY_URL:?CADDY_IP manquant (config/network.env)}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${GATEWAY_KEY_STANDARD:-}" \
    -d '{
      "model": "med-chaos",
      "messages": [{"role": "user", "content": "test"}],
      "max_tokens": 256
    }' 2>/dev/null || echo "")

  if [[ -z "$response" ]]; then
    warn "pas de réponse (modèle med-chaos peut ne pas exister)"
  else
    # Vérifier que le JSON est invalide
    if echo "$response" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
      warn "le JSON est valide (attendu : invalide)"
    else
      ok "JSON invalide détecté (comportement attendu)"
    fi
  fi

}

chaos_scenario_revert() {
  ok "scenario 04 terminé"
}
