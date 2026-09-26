#!/usr/bin/env bash
# FARCI — scénario 04 : JSON invalide
#
# Attendu : Pydantic ValidationError, aucun fichier écrit
# Mécanisme réel : modèle de test med-chaos volontairement non conforme

chaos_scenario_apply() {
  local duration="${1:-}"
  info "test de JSON invalide (modèle med-chaos)..."

  # Appeler le modèle med-chaos qui renvoie un JSON hors schéma
  response=$(curl -sf -X POST "http://192.168.50.15/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer sk-standard-placeholder" \
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

  echo '{"scenario":"04","action":"invalid_json"}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "scenario 04 terminé"
}
