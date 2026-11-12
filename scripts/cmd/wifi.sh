#!/usr/bin/env bash
# FARCI — ./bin/farci wifi : la radio du Pi, en salle ou sur Internet
#
#   ./bin/farci wifi                    où en est la radio, qui est connecté
#   ./bin/farci wifi internet [profil]  quitte la salle, rejoint un Wi-Fi qui a Internet
#   ./bin/farci wifi salle              recrée le Wi-Fi de la salle (point d'accès)
#   ./bin/farci wifi ajouter <nom>      enregistre un Wi-Fi ; le mot de passe est
#                                       demandé, jamais écrit dans l'historique
#
# Le Pi n'a qu'une radio : elle est SOIT le point d'accès de la salle, SOIT
# cliente d'un autre Wi-Fi. Basculer coupe donc la connexion SSH en cours.
#
# LA RÈGLE DE RETOUR : sur Internet, si personne n'est connecté en SSH pendant
# FARCI_WIFI_DELAI secondes (300 par défaut) et qu'aucun téléchargement ne
# tourne, le Pi recrée seul le Wi-Fi de la salle. Un Pi sans écran n'est donc
# jamais perdu sur un réseau où on ne le trouve pas : au pire, on attend cinq
# minutes. Un Wi-Fi injoignable (mauvais mot de passe, hors de portée) ramène
# le Pi en salle tout de suite.
#
# Réglages (.env) : FARCI_WIFI_AP (farci-ap), FARCI_WIFI_DEV (wlan0),
# FARCI_WIFI_DELAI (300), FARCI_WIFI_INTERNET (profil par défaut).
# Journal : journalctl -u farci-wifi

set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
# shellcheck source=scripts/dev-env.sh
source "$FARCI_ROOT/scripts/dev-env.sh"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

farci_load_env
AP="${FARCI_WIFI_AP:-farci-ap}"
DEV="${FARCI_WIFI_DEV:-wlan0}"
DELAI="${FARCI_WIFI_DELAI:-300}"
PAS="${FARCI_WIFI_PAS:-15}"
UNIT="farci-wifi"
# Ce qui compte comme « un téléchargement tourne » : on ne coupe pas Internet dessous.
OCCUPE="${FARCI_WIFI_OCCUPE:-preload\.sh|docker (pull|load|build)|git (pull|fetch|clone)|pip3? (download|install)}"
SELF="$FARCI_ROOT/scripts/cmd/wifi.sh"

# root n'a pas besoin de sudo (l'unité systemd, les tests).
as_root() { if (( EUID == 0 )); then "$@"; else sudo "$@"; fi; }

active() { nmcli -g GENERAL.CONNECTION dev show "$DEV" 2>/dev/null | head -1; }
# Sessions SSH vivantes. En quittant la salle, l'adresse du point d'accès
# disparaît mais la session qui a lancé la bascule reste « établie » de longues
# minutes côté noyau : on ne compte que celles dont l'adresse locale existe encore.
ssh_sessions() {
  local ips
  ips="$(ip -4 -o addr show 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4}')"
  ss -Htn state established '( sport = :22 )' 2>/dev/null \
    | awk -v ips="$ips" 'BEGIN { n = split(ips, a, "\n"); for (i = 1; i <= n; i++) ok[a[i]] = 1 }
        { for (f = 1; f <= NF; f++) if ($f ~ /:22$/) {   # premier champ en :22 = adresse locale
            addr = $f; sub(/:22$/, "", addr); gsub(/[\[\]]/, "", addr); if (addr in ok) c++; break } }
        END { print c + 0 }'
}
busy() { pgrep -f "$OCCUPE" >/dev/null 2>&1; }

# Les Wi-Fi enregistrés autres que le point d'accès (un par ligne).
client_profiles() {
  nmcli -t -f NAME,TYPE con show 2>/dev/null | awk -F: -v ap="$AP" '$2 ~ /wireless|wifi/ && $1 != ap {print $1}'
}

to_salle() {
  nmcli con up "$AP" && ok "Wi-Fi de la salle recréé ($AP)"
}

# La veille : tant que la radio est sur Internet, compter le temps sans SSH.
cmd_veille() {
  local idle=0
  info "veille : retour en salle après ${DELAI}s sans connexion SSH ni téléchargement"
  while sleep "$PAS"; do
    [[ "$(active)" != "$AP" ]] || { info "la radio est revenue en salle : fin de la veille"; return 0; }
    if (( $(ssh_sessions) > 0 )) || busy; then
      idle=0
    else
      idle=$(( idle + PAS ))
    fi
    if (( idle >= DELAI )); then
      warn "personne en SSH depuis ${DELAI}s : retour en salle"
      to_salle
      return 0
    fi
  done
}

# Exécuté par l'unité systemd, détaché de la session SSH qui va tomber.
cmd_bascule() {
  local profil="$1"
  if nmcli con up "$profil"; then
    ok "radio sur « $profil »"
    cmd_veille
  else
    err "« $profil » injoignable (mot de passe ? hors de portée ?) : retour en salle"
    to_salle
  fi
}

detach() {
  have systemd-run || die "systemd-run absent : cette commande se lance sur le Pi"
  as_root systemctl stop "$UNIT" 2>/dev/null || true
  as_root systemd-run --quiet --collect --unit="$UNIT" \
    --setenv=FARCI_WIFI_DELAI="$DELAI" --setenv=FARCI_WIFI_AP="$AP" --setenv=FARCI_WIFI_DEV="$DEV" \
    "$SELF" "$@"
}

cmd_internet() {
  local profil="${1:-${FARCI_WIFI_INTERNET:-}}" candidates
  need nmcli
  if [[ -z "$profil" ]]; then
    candidates="$(client_profiles)"
    [[ -n "$candidates" ]] || die "aucun Wi-Fi enregistré : ./bin/farci wifi ajouter <nom du réseau>"
    if (( $(grep -c . <<< "$candidates") > 1 )); then
      err "plusieurs Wi-Fi enregistrés : lequel ?"
      sed 's/^/    .\/bin\/farci wifi internet /' <<< "$candidates" >&2
      return 64
    fi
    profil="$candidates"
  fi
  nmcli -t -f NAME con show | grep -qxF "$profil" || die "Wi-Fi inconnu : $profil (./bin/farci wifi pour la liste)"
  [[ "$profil" != "$AP" ]] || die "$AP est le Wi-Fi de la salle : ./bin/farci wifi salle"
  detach _bascule "$profil"
  cat <<EOF

  Le Wi-Fi de la salle va disparaître, et cette connexion SSH avec lui.
  Rejoignez « $profil » avec votre appareil, puis :
      ssh ${USER:-farci}@$(hostname).local

  Sans connexion SSH pendant $(( DELAI / 60 )) min (et sans téléchargement en cours),
  le Pi recrée seul le Wi-Fi de la salle. Pour y revenir vous-même :
      ./bin/farci wifi salle
EOF
}

cmd_salle() {
  need nmcli
  [[ "$(active)" != "$AP" ]] || { ok "la radio est déjà en salle ($AP)"; return 0; }
  detach _salle
  printf '\n  Le Pi recrée le Wi-Fi de la salle : cette connexion SSH va tomber.\n'
  printf '  Rejoignez-le, puis : ssh %s@%s\n' "${USER:-farci}" "${REFERENCE_IP:-<REFERENCE_IP>}"
}

cmd_ajouter() {
  local ssid="${1:?usage : ./bin/farci wifi ajouter <nom du réseau>}" psk
  need nmcli
  ! nmcli -t -f NAME con show | grep -qxF "$ssid" || die "« $ssid » est déjà enregistré (sudo nmcli con delete '$ssid' pour recommencer)"
  read -r -s -p "  Mot de passe de « $ssid » : " psk; printf '\n'
  (( ${#psk} >= 8 )) || die "mot de passe trop court (8 caractères au moins)"
  # autoconnect no : après un redémarrage, le Pi revient toujours en salle.
  as_root nmcli con add type wifi ifname "$DEV" con-name "$ssid" ssid "$ssid" \
    connection.autoconnect no wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk" >/dev/null
  ok "« $ssid » enregistré : ./bin/farci wifi internet '$ssid'"
}

cmd_etat() {
  local now profils
  need nmcli
  section "La radio du Pi ($DEV)"
  now="$(active)"
  if [[ "$now" == "$AP" ]]; then
    printf '  mode           salle : point d'"'"'accès « %s »\n' "$AP"
  elif [[ -n "$now" ]]; then
    printf '  mode           Internet : cliente de « %s »\n' "$now"
    if systemctl is-active --quiet "$UNIT" 2>/dev/null; then
      printf '  retour         en salle après %s min sans SSH ni téléchargement\n' "$(( DELAI / 60 ))"
    else
      printf '  retour         AUCUNE veille active : ./bin/farci wifi salle pour revenir\n'
    fi
  else
    printf '  mode           radio inactive : ./bin/farci wifi salle\n'
  fi
  printf '  sessions SSH   %s\n' "$(ssh_sessions)"
  profils="$(client_profiles | paste -sd',' - | sed 's/,/, /g')"
  printf '  Wi-Fi connus   %s\n\n' "${profils:-aucun (./bin/farci wifi ajouter <nom>)}"
}

case "${1:-}" in
  "")         cmd_etat ;;
  internet)   shift; cmd_internet "$@" ;;
  salle)      cmd_salle ;;
  ajouter)    shift; cmd_ajouter "$@" ;;
  _bascule)   shift; cmd_bascule "$@" ;;
  _salle)     to_salle ;;
  _veille)    cmd_veille ;;
  -h|--help)  usage ;;
  *)          err "commande inconnue : $1"; usage >&2; exit 64 ;;
esac
