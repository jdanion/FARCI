#!/usr/bin/env bash
# FARCI — profil matériel du poste (scripts/lib/machine.sh), à sourcer.
#
#   farci_ram_go        RAM totale, en Go entiers
#   farci_gpu           noms des GPU NVIDIA (vide sans GPU)
#   farci_machine       « grosse » ou « legere »
#   farci_machine_why   la raison, en clair
#
# Une grosse configuration a un GPU NVIDIA, ou au moins FARCI_GROSSE_RAM_GO
# de RAM (32 par défaut, même seuil que casting/roles.py) : elle seule sert
# Ollama et le modèle 9B. Docker sur Mac n'utilise pas le GPU Apple : un Mac
# compte par sa RAM. FARCI_MACHINE=grosse|legere force le profil.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "machine.sh est une bibliothèque : source scripts/lib/machine.sh" >&2
  exit 64
fi

farci_ram_go() {
  local kb bytes
  kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || true)"
  if [[ -n "$kb" ]]; then
    printf '%s\n' "$(( (kb + 524288) / 1048576 ))"
    return
  fi
  bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
  printf '%s\n' "$(( (${bytes:-0} + 536870912) / 1073741824 ))"
}

farci_gpu() {
  command -v nvidia-smi >/dev/null 2>&1 || return 0
  nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -3 | paste -sd',' - || true
}

farci_machine() {
  case "${FARCI_MACHINE:-}" in
    grosse|legere) printf '%s\n' "$FARCI_MACHINE"; return ;;
  esac
  # Un portable « 32 Go » annonce ~31 Go (mémoire réservée au noyau, à la
  # carte graphique) : 2 Go de tolérance.
  if [[ -n "$(farci_gpu)" ]] || (( $(farci_ram_go) + 2 >= ${FARCI_GROSSE_RAM_GO:-32} )); then
    printf 'grosse\n'
  else
    printf 'legere\n'
  fi
}

farci_machine_why() {
  local gpu ram
  gpu="$(farci_gpu)"; ram="$(farci_ram_go)"
  if [[ -n "${FARCI_MACHINE:-}" ]]; then
    printf 'imposé par FARCI_MACHINE=%s\n' "$FARCI_MACHINE"
  elif [[ -n "$gpu" ]]; then
    printf '%s Go de RAM, GPU %s\n' "$ram" "$gpu"
  else
    printf '%s Go de RAM, pas de GPU NVIDIA (seuil : %s Go)\n' "$ram" "${FARCI_GROSSE_RAM_GO:-32}"
  fi
}
