#!/usr/bin/env python3
"""FARCI — health-aggregator (FARCI §14).

Sonde tous les services de config/services.yaml (et leur doublure sur la
pile de référence) avec scripts/services.py (room_state) : le tableau
`./bin/farci status` et cet agrégateur ne peuvent donc pas diverger.

Stdlib uniquement. Les adresses viennent de l'environnement (config/network.env,
transmis par docker-compose.yml) ; le registre ne contient que des noms de
variables.

Endpoints (relayés par Caddy) :
  GET /status   JSON : chaque service (équipe, référence), pipeline des
                équipes et service rendu à la salle
  GET /healthz  200 si la salle peut travailler (équipes ou référence), 503 sinon
  GET /livez    200 si le processus répond : c'est la sonde de l'agrégateur
                lui-même (sonder /healthz relancerait l'agrégation en boucle)
  GET /tableau        le tableau de la salle (page web, pour l'écran projeté)
  GET /tableau/etat   JSON du tableau : lignes, scores, badges, fil, chrono
  GET /rejoindre      la marche à suivre d'un étudiant arrivé sans rien
                      (les fichiers eux-mêmes sont servis par l'accueil :
                      ./bin/farci partage)

Le tableau est tenu par un fil de fond qui sonde la salle toutes les
TABLEAU_TICK secondes (tableau.py) et sauvegarde les scores dans
TABLEAU_STATE. Supprimer ce fichier remet scores et chrono à zéro
(./bin/farci tableau reset).
"""

from __future__ import annotations

import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# scripts/ est monté à côté de l'application (docker-compose.yml) ; en local,
# on le trouve à la racine du dépôt.
HERE = Path(__file__).resolve().parent
for candidate in (HERE / "scripts", *(parent / "scripts" for parent in HERE.parents)):
    if (candidate / "services.py").is_file():
        sys.path.insert(0, str(candidate))
        os.environ.setdefault("FARCI_ROOT", str(candidate.parent))
        break

import services as registry  # noqa: E402
import tableau  # noqa: E402

# Port d'écoute DANS le conteneur ; HEALTH_AGGREGATOR_PORT est le port publié.
PORT = int(os.environ.get("AGGREGATOR_LISTEN_PORT", "8081"))
TIMEOUT = float(os.environ.get("FARCI_HEALTH_TIMEOUT", "3"))
# Le résultat est gardé quelques secondes : plusieurs écrans qui rafraîchissent
# ne doivent pas multiplier les sondes.
CACHE_SECONDS = float(os.environ.get("FARCI_HEALTH_CACHE", "2"))
_cache: tuple[float, dict] | None = None

TABLEAU_HTML = Path(os.environ.get("TABLEAU_HTML", HERE.parent / "tableau" / "index.html"))
REJOINDRE_HTML = TABLEAU_HTML.parent / "rejoindre.html"
TABLEAU_TICK = float(os.environ.get("TABLEAU_TICK", "5"))
_board = tableau.Scoreboard(os.environ.get("TABLEAU_STATE") or None)
_board_lock = threading.Lock()


def aggregate_status() -> dict:
    """État de la salle, mis en cache quelques secondes."""
    global _cache
    now = time.monotonic()
    if _cache and now - _cache[0] < CACHE_SECONDS:
        return _cache[1]
    room = registry.room_state(TIMEOUT)
    status = {
        # « ready » : la salle peut travailler (équipes, ou référence 🛟)
        "status": "ready" if room["service_rendu"]["state"] == "READY" else "degraded",
        **room,
        "version": "3",
    }
    _cache = (now, status)
    return status


def board_tick() -> None:
    """Un sondage : met à jour scores et fil, puis sauvegarde."""
    room = aggregate_status()
    with _board_lock:
        if _board.path and not _board.path.exists():
            _board.reset()  # fichier supprimé : nouvelle séance
        _board.update(room, registry.services())
        _board.save()


def board_loop() -> None:
    while True:
        try:
            board_tick()
        except Exception as exc:  # le tableau ne doit jamais arrêter l'agrégateur
            print(f"tableau : {exc}", file=sys.stderr, flush=True)
        time.sleep(TABLEAU_TICK)


def board_view() -> dict:
    room = aggregate_status()
    with _board_lock:
        return _board.view(room, registry.services(), registry.registry().get("status_rows", []),
                           dict(os.environ))


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/livez":
            self._send_json(200, {"status": "alive"})
        elif path == "/status":
            self._send_json(200, aggregate_status())
        elif path in ("/tableau", "/tableau/"):
            self._send_file(TABLEAU_HTML, "text/html; charset=utf-8")
        elif path in ("/rejoindre", "/rejoindre/"):
            self._send_file(REJOINDRE_HTML, "text/html; charset=utf-8")
        elif path == "/tableau/etat":
            self._send_json(200, board_view())
        elif path == "/healthz":
            status = aggregate_status()
            code = 200 if status["status"] == "ready" else 503
            self._send_json(code, {
                "status": status["status"],
                "equipes": status["pipeline"]["state"],
                "missing": status["service_rendu"]["missing"],
            })
        else:
            self._send_json(404, {"error": "not_found"})

    def _send_file(self, path: Path, content_type: str):
        try:
            body = path.read_bytes()
        except OSError:
            self._send_json(404, {"error": f"{path.name} introuvable"})
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002 — signature imposée
        pass


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), HealthHandler)
    threading.Thread(target=board_loop, daemon=True).start()
    print(f"health-aggregator : écoute sur :{PORT}, tableau sur /tableau", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
