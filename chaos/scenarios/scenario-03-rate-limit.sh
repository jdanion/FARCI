#!/usr/bin/env bash
# FARCI — scénario 03 : rate limiting
#
# Attendu : ≥1 × 429 + Retry-After ; sk-priority 200

SCENARIO_TITLE="Limitation de débit (clé standard)"

chaos_scenario_apply() {
  info "test de rate limiting (12 requêtes en 2s)..."

  local count_429=0
  local count_200=0

  for i in $(seq 1 12); do
    code=$(curl -s --max-time 30 -o /dev/null -w '%{http_code}' \
      -X POST "${FARCI_GATEWAY_URL:?CADDY_IP manquant (config/network.env)}/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${GATEWAY_KEY_STANDARD:-}" \
      -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}' 2>/dev/null || true)

    if [[ "$code" == "429" ]]; then
      count_429=$((count_429 + 1))
    elif [[ "$code" == "200" ]]; then
      count_200=$((count_200 + 1))
    fi
  done

  info "429: $count_429, 200: $count_200"
}

chaos_scenario_revert() {
  ok "rate limit test terminé"
}
