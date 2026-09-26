#!/usr/bin/env bash
# FARCI — point d'entrée unique d'installation (racine du dépôt).
#
# Rôle volontairement limité : ce script prépare la machine et vérifie que tout
# va bien. Il ne télécharge JAMAIS d'image ni de modèle — c'est le rôle de
# preload.sh, qui n'est exécuté qu'une fois, avec Internet, avant le workshop.
#
#   ./bootstrap.sh            préparer cette machine
#   ./bootstrap.sh --check    vérifier uniquement, n'écrire rien
#
# Voir scripts/cmd/bootstrap.sh pour le détail des étapes.

set -uo pipefail
FARCI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FARCI_ROOT

exec "$FARCI_ROOT/bin/farci" bootstrap "$@"
