#!/usr/bin/env bash
# FARCI — scénario 03 : limitation de débit (BONUS)
#
# Pré-requis : clés virtuelles LiteLLM (PostgreSQL), voir 03-llm-gateway/TUTORIAL.md.
# Action     : 12 requêtes rapides avec la clé standard.
# Attendu    : au moins un 429 avec Retry-After.
# Leçon      : le débit est une propriété de la passerelle, pas du modèle.

SCENARIO_TITLE="Limitation de débit (bonus : clés LiteLLM requises)"
SCENARIO_ATTENDU="au moins un HTTP 429"

chaos_scenario_apply() {
  CHAOS_429=0
  local i code
  for i in $(seq 1 12); do
    code="$(curl -s --noproxy '*' --max-time 30 -o /dev/null -w '%{http_code}' \
      -X POST "${FARCI_GATEWAY_URL:?FARCI_GATEWAY_URL manquante (REFERENCE_IP)}/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${GATEWAY_KEY_STANDARD:-}" \
      -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}' || true)"
    [[ "$code" == "429" ]] && CHAOS_429=$((CHAOS_429 + 1))
  done
  info "429 reçus : $CHAOS_429 / 12"
}

chaos_scenario_check() {
  chaos_expect "au moins un 429" test "${CHAOS_429:-0}" -gt 0
}

chaos_scenario_revert() {
  ok "rien à réparer : le quota se recharge seul"
}
