#!/usr/bin/env bash
# FARCI — scénario 03 : rate limiting
#
# Attendu : ≥1 × 429 + Retry-After ; sk-priority 200

chaos_scenario_apply() {
  local duration="${1:-}"
  info "test de rate limiting (12 requêtes en 2s)..."

  local count_429=0
  local count_200=0

  for i in $(seq 1 12); do
    code=$(curl -s -o /dev/null -w '%{http_code}' \
      -X POST "http://192.168.50.15/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer sk-standard-placeholder" \
      -d '{"model":"med-extraction","messages":[{"role":"user","content":"test"}],"max_tokens":1}' 2>/dev/null || echo "000")

    if [[ "$code" == "429" ]]; then
      count_429=$((count_429 + 1))
    elif [[ "$code" == "200" ]]; then
      count_200=$((count_200 + 1))
    fi
  done

  info "429: $count_429, 200: $count_200"
  echo '{"scenario":"03","action":"rate_limit","429":'$count_429',"200":'$count_200'}' > "$CHAOS_STATE_FILE"

  if [[ -n "$duration" ]]; then
    sleep "$duration"
    chaos_scenario_revert
  fi
}

chaos_scenario_revert() {
  echo '{}' > "$CHAOS_STATE_FILE"
  ok "rate limit test terminé"
}
