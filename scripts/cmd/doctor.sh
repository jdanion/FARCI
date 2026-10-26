#!/usr/bin/env bash
# FARCI — ./bin/farci doctor
# Diagnostic de la machine AVANT de lancer quoi que ce soit.
# Sort en 1 si un prérequis indispensable manque (python3, git, curl…), 0 sinon.
# Un poste sans Docker reste utilisable : il ne peut pas héberger de brique,
# mais il fait les étapes 2 et 3 (le diagnostic le dit).

set -uo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"
farci_load_env

FATAL=0
line() { printf '  %-26s %s\n' "$1" "$2"; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,9p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
  exit 0
fi

section "Outils indispensables"
for tool in git python3 curl tar sha256sum; do
  if have "$tool"; then
    line "$tool" "${C_GREEN}présent${C_RESET}"
  else
    line "$tool" "${C_RED}MANQUANT${C_RESET}"
    FATAL=1
  fi
done

# Sans Docker, le poste ne peut pas HÉBERGER une brique, mais il fait toute
# l'étape 2 (parcours Python, Open WebUI du Pi) et l'étape 3 : ce n'est pas
# bloquant, c'est un changement de rôle (binôme pour l'étape 1).
DOCKER_OK=0
section "Docker (pour héberger une brique)"
DOCKER_WHY="$(docker_diagnose)"
if ! have docker; then
  line "docker" "${C_YELLOW}absent${C_RESET}"
elif [[ -n "$DOCKER_WHY" ]]; then
  line "docker" "${C_YELLOW}${DOCKER_WHY}${C_RESET}"
elif ! docker compose version >/dev/null 2>&1; then
  line "docker compose" "${C_YELLOW}plugin absent${C_RESET}"
else
  line "docker" "${C_GREEN}joignable, compose $(docker compose version --short 2>/dev/null)${C_RESET}"
  DOCKER_OK=1
fi
if (( ! DOCKER_OK )); then
  line "→ plan B" "étape 1 en binôme avec un poste qui a Docker ;"
  line "" "étapes 2 et 3 sans Docker : ./bin/farci extract, Open WebUI du Pi"
fi
python3 -c "import sys; sys.exit(0 if sys.version_info>=(3,11) else 1)" 2>/dev/null \
  && line "python3 >= 3.11" "${C_GREEN}ok${C_RESET}" \
  || { line "python3 >= 3.11" "${C_RED}trop ancien (trouvé $(python3 -V 2>&1))${C_RESET}"; FATAL=1; }

section "Outils pratiques (absents = warnings)"
have make && line "make" "présent" || line "make" "${C_YELLOW}absent — ./bin/farci fait le même travail${C_RESET}"
python3 -c "import pydantic" 2>/dev/null \
  && line "dépendances Python" "${C_GREEN}ok (pydantic)${C_RESET}" \
  || line "dépendances Python" "${C_YELLOW}absentes — ./bin/farci bootstrap (installe .venv/ hors ligne)${C_RESET}"
have jq && line "jq" "présent" || line "jq" "${C_DIM}absent — inutile, les tests utilisent python3${C_RESET}"
have shellcheck && line "shellcheck" "présent" \
  || line "shellcheck" "${C_DIM}absent — le lint le signalera en SKIP${C_RESET}"

section "Configuration"
for f in .env config/network.env config/workshop.env; do
  if [[ -r "$FARCI_ROOT/$f" ]]; then
    line "$f" "${C_GREEN}présent${C_RESET}"
  else
    line "$f" "${C_YELLOW}absent — ./bin/farci bootstrap le créera${C_RESET}"
  fi
done

section "Données lourdes (§0.1 du plan)"
data="${FARCI_DATA_DIR:-/srv/farci}"
if [[ -d "$data" ]]; then
  avail_kb="$(df -Pk "$data" | awk 'NR==2 {print $4}')"
  avail_gb=$(( avail_kb / 1024 / 1024 ))
  need_gb=30
  if (( avail_gb >= need_gb )); then
    line "$data" "${C_GREEN}${avail_gb} Go libres${C_RESET} (il en faut ~30 pour --all)"
  else
    line "$data" "${C_YELLOW}${avail_gb} Go libres${C_RESET} (--all en demande ~30 : utiliser --core)"
  fi
else
  line "$data" "${C_YELLOW}n'existe pas encore — ./bin/farci bootstrap le créera${C_RESET}"
fi
if [[ -L "$FARCI_ROOT/offline" ]]; then
  line "offline (lien)" "${C_GREEN}→ $(readlink -f "$FARCI_ROOT/offline" 2>/dev/null || echo '?')"
elif [[ -d "$FARCI_ROOT/offline" ]]; then
  line "offline (dossier)" "${C_YELLOW}réel et non lié — il devrait pointer vers $data/offline${C_RESET}"
else
  line "offline" "${C_DIM}pas encore créé${C_RESET}"
fi

section "Ressources de la machine"
mem_gb="$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null || true)"
if [[ -z "$mem_gb" ]] && have sysctl; then
  mem_gb="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f", $1/1073741824}')"
fi
mem_gb="${mem_gb:-?}"
if [[ "$mem_gb" != "?" ]] && awk "BEGIN{exit !($mem_gb < 8)}"; then
  line "RAM" "${C_YELLOW}${mem_gb} Go — insuffisant pour le modèle 9B (il en faut ~8 Go)${C_RESET}"
  line "" "${C_DIM}→ modèle de secours : 02-inference/ollama/create-model.sh secours${C_RESET}"
else
  line "RAM" "${C_GREEN}${mem_gb} Go${C_RESET}"
fi
line "CPU" "$(nproc 2>/dev/null || echo '?') cœurs"
gpus="$(command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -3 | paste -sd' ' - || true)"
line "GPU" "${gpus:-${C_DIM}aucun (CPU uniquement)${C_RESET}}"

section "Réseau de la salle"
ips="$( (hostname -I 2>/dev/null || ipconfig getifaddr en0 2>/dev/null || true) | tr ' ' '\n' \
        | grep -E '^[0-9]+(\.[0-9]+){3}$' | grep -vE '^(127|172\.(1[6-9]|2[0-9]|3[01]))\.' | paste -sd' ' - || true)"
line "IP de cette machine" "${ips:-${C_YELLOW}introuvable${C_RESET}}  ${C_DIM}(à donner au formateur pour ./bin/farci room set)${C_RESET}"
if [[ -n "${FARCI_ENTRY_URL:-}" ]]; then
  if [[ "$(http_code "$FARCI_ENTRY_URL/livez" 3)" == "200" ]]; then
    line "accueil de la salle" "${C_GREEN}joignable${C_RESET} ($FARCI_ENTRY_URL)"
  else
    line "accueil de la salle" "${C_YELLOW}injoignable${C_RESET} ($FARCI_ENTRY_URL) — bon Wi-Fi ? REFERENCE_IP ?"
  fi
else
  line "accueil de la salle" "${C_YELLOW}REFERENCE_IP absente de config/network.env${C_RESET}"
fi
if curl -s --max-time 3 -o /dev/null https://example.com 2>/dev/null; then
  line "accès internet" "${C_GREEN}disponible${C_RESET} (préchargement possible)"
else
  line "accès internet" "${C_DIM}coupé${C_RESET} ${C_YELLOW}(mode atelier attendu)${C_RESET}"
fi

printf '\n'
if (( FATAL )); then
  err "prérequis indispensables manquants — voir ci-dessus"
  exit 1
fi
ok "machine utilisable"
printf '  suite : ./bin/farci bootstrap   puis   ./bin/farci status\n\n'
exit 0
