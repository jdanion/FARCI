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
  GET /tableau/formateur   l'onglet du formateur : équipes, étudiants, adresses
  GET /tableau/salle       équipes, étudiants, adresses et suivi UP/DOWN de
                           chaque brique
  POST /tableau/salle      enregistrer : écrit config/salle.json et
                           config/network.env, puis recharge l'accueil
                           (Caddy) — comme room set
  GET /tableau/extraction  l'étape 2 sur des exemples : documents, dossier
                           pseudonymisé, prompts, gold, runs de la machine
  GET /tableau/extraction/cas[/<IPP>]   les dossiers du jeu rapide
  POST /tableau/extraction/direct       {"ipp", "prompt"} : extraction en
                           direct par l'accueil (/v1), comparée au gold
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

import extraction  # noqa: E402
import salle  # noqa: E402
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
FORMATEUR_HTML = TABLEAU_HTML.parent / "formateur.html"
EXTRACTION_HTML = TABLEAU_HTML.parent / "extraction.html"
TABLEAU_TICK = float(os.environ.get("TABLEAU_TICK", "5"))
_board = tableau.Scoreboard(os.environ.get("TABLEAU_STATE") or None)
_board_lock = threading.Lock()
# L'onglet formateur n'écrit que sur l'accueil de la SALLE (le Pi) ; celui de
# l'équipe 1 (FARCI_ACCUEIL=equipe-1) le montre en lecture seule.
MODIFIABLE = os.environ.get("FARCI_ACCUEIL", "salle") != "equipe-1"
_suivi = salle.Suivi()
_salle_lock = threading.Lock()
CADDY_CHECK_SECONDS = 30.0
_caddy_check = 0.0
_last_room: dict | None = None  # dernier sondage de fond (board_loop)


def aggregate_status(fresh: bool = False) -> dict:
    """État de la salle, mis en cache quelques secondes."""
    global _cache
    now = time.monotonic()
    if _cache and now - _cache[0] < CACHE_SECONDS and not fresh:
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
    global _caddy_check
    # Les adresses peuvent avoir changé (onglet formateur, room set) : le
    # fichier fait foi, pas l'environnement figé à la création du conteneur.
    global _last_room
    salle.rafraichir_environnement()
    room = aggregate_status()
    _last_room = room
    _suivi.noter(room)
    with _board_lock:
        if _board.path and not _board.path.exists():
            _board.reset()  # fichier supprimé : nouvelle séance
        _board.noms = salle.noms()
        _board.update(room, registry.services())
        _board.save()
    # Caddy a pu redémarrer avec son ancien environnement : on lui redonne
    # les amonts actuels s'il ne les sert plus.
    if MODIFIABLE and time.monotonic() - _caddy_check > CADDY_CHECK_SECONDS:
        _caddy_check = time.monotonic()
        if salle.caddy_a_jour(registry) is False:
            ok, message = salle.recharger_caddy(registry)
            print(f"accueil : amonts rétablis ({message})" if ok else f"accueil : {message}",
                  file=sys.stderr, flush=True)


def board_loop() -> None:
    while True:
        try:
            board_tick()
        except Exception as exc:  # le tableau ne doit jamais arrêter l'agrégateur
            print(f"tableau : {exc}", file=sys.stderr, flush=True)
        time.sleep(TABLEAU_TICK)


def board_view() -> dict:
    # Plusieurs écrans rafraîchissent toutes les 3 s : le sondage de fond suffit.
    room = _last_room or aggregate_status()
    with _board_lock:
        return _board.view(room, registry.services(), registry.registry().get("status_rows", []),
                           dict(os.environ))


def salle_view(fresh: bool = False, message: str = "") -> dict:
    # Le sondage de fond suffit (toutes les TABLEAU_TICK s) ; « Sonder
    # maintenant » ou un enregistrement en relancent un tout de suite.
    room = aggregate_status(True) if fresh or _last_room is None else _last_room
    if fresh:
        _suivi.noter(room)
    return salle.vue(registry, room, _suivi, MODIFIABLE, message)


def salle_save(payload: dict) -> tuple[int, dict]:
    global _cache
    with _salle_lock:
        erreurs, changements = salle.enregistrer(registry, payload)
        if erreurs:
            return 422, {"ok": False, "erreurs": erreurs}
        message = "enregistré"
        if changements:
            ok, detail = salle.recharger_caddy(registry)
            message = f"adresses enregistrées ({len(changements)}) — {detail}"
            if not ok:
                return 200, {"ok": True, "avertissement": detail, "vue": salle_view(True, message)}
        _cache = None
        with _board_lock:
            _board.noms = salle.noms()
        return 200, {"ok": True, "vue": salle_view(True, message)}


class HealthHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path == "/tableau/extraction/direct":
            try:
                length = min(int(self.headers.get("Content-Length", "0")), 4096)
                payload = json.loads(self.rfile.read(length) or b"{}")
            except (ValueError, OSError):
                self._send_json(400, {"ok": False, "erreur": "JSON illisible"})
                return
            code, body = extraction.extraire(str(payload.get("ipp", "")), str(payload.get("prompt", "v2")))
            self._send_json(code, body)
            return
        if path != "/tableau/salle":
            self._send_json(404, {"error": "not_found"})
            return
        if not MODIFIABLE:
            self._send_json(403, {"ok": False, "erreurs": [
                "accueil de l'équipe 1 : les adresses se déclarent sur le Pi "
                f"(http://{os.environ.get('REFERENCE_IP', '<IP du Pi>')}/tableau/formateur)"]})
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 65536)
            payload = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, OSError):
            self._send_json(400, {"ok": False, "erreurs": ["JSON illisible"]})
            return
        code, body = salle_save(payload if isinstance(payload, dict) else {})
        self._send_json(code, body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/livez":
            self._send_json(200, {"status": "alive"})
        elif path == "/status":
            self._send_json(200, aggregate_status())
        elif path in ("/tableau", "/tableau/"):
            self._send_file(TABLEAU_HTML, "text/html; charset=utf-8")
        elif path in ("/tableau/formateur", "/tableau/formateur/"):
            self._send_file(FORMATEUR_HTML, "text/html; charset=utf-8")
        elif path == "/tableau/salle":
            self._send_json(200, salle_view(fresh="sonder=1" in self.path))
        elif path in ("/tableau/extraction", "/tableau/extraction/"):
            self._send_file(EXTRACTION_HTML, "text/html; charset=utf-8")
        elif path == "/tableau/extraction/cas":
            self._send_json(200, {"cas": extraction.liste()})
        elif path.startswith("/tableau/extraction/cas/"):
            ex = extraction.exemple(path.rsplit("/", 1)[1])
            self._send_json(200 if ex else 404, ex or {"error": "dossier inconnu"})
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
