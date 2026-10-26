#!/usr/bin/env bash
# FARCI — recharger l'accueil de cette machine (scripts/lib/entry.sh)
#
# Après un changement d'adresses (room set) ou de bascule (rescue), l'accueil
# doit relire ses amonts UP_* : on relance sa compose, qui ne recrée que ce
# qui a changé (Caddy, agrégateur). Sur le Pi c'est reference/, sur la
# machine de l'équipe 1 c'est 01-network-dashboard/.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "entry.sh est une bibliothèque : utilisez 'source scripts/lib/entry.sh'" >&2
  exit 64
fi

farci_reload_entry() {
  local running
  # Environnement neuf : les adresses viennent d'être modifiées dans
  # config/network.env, et une valeur héritée du shell gagnerait toujours.
  local -a clean=(env -i "HOME=$HOME" "PATH=$PATH" "TERM=${TERM:-dumb}" "NO_COLOR=${NO_COLOR:-}")
  running="$(docker ps --format '{{.Names}}' 2>/dev/null || true)"
  local caddy=""
  if grep -qx 'farci-ref-caddy' <<< "$running"; then
    caddy=farci-ref-caddy
    "${clean[@]}" "$FARCI_ROOT/bin/farci" up reference caddy health-aggregator
  elif grep -qx 'farci-caddy' <<< "$running"; then
    caddy=farci-caddy
    "${clean[@]}" "$FARCI_ROOT/bin/farci" up 01-network-dashboard caddy health-aggregator
  fi
  if [[ -n "$caddy" ]]; then
    # Si son environnement n'a pas changé, compose ne recrée pas Caddy : il
    # garderait alors des amonts poussés par l'onglet formateur. On lui fait
    # relire son fichier avec son environnement, qui est le bon.
    docker exec "$caddy" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
      || warn "Caddy n'a pas relu sa configuration : ./bin/farci logs reference caddy"
  else
    info "aucun accueil ne tourne sur cette machine : la configuration s'appliquera au prochain ./bin/farci up reference"
  fi
}
