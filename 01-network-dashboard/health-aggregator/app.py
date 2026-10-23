#!/usr/bin/env python3
"""FARCI — health-aggregator (FARCI §14).

Sonde tous les services de config/services.yaml et applique LA règle de
CLINICAL PIPELINE READY, celle de scripts/services.py (pipeline_state) : le
tableau `./bin/farci status` et cet agrégateur ne peuvent donc pas diverger.

Stdlib uniquement. Les adresses viennent de l'environnement (config/network.env,
transmis par docker-compose.yml) ; le registre ne contient que des noms de
variables.

Endpoints (relayés par Caddy) :
  GET /status   JSON : état de chaque service (tier, critique) + pipeline
  GET /healthz  200 si le pipeline est READY, 503 sinon (sonde Uptime Kuma)
  GET /livez    200 si le processus répond : c'est la sonde de l'agrégateur
                lui-même (sonder /healthz relancerait l'agrégation en boucle)
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
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

PORT = int(os.environ.get("HEALTH_AGGREGATOR_PORT", "8081"))
TIMEOUT = float(os.environ.get("FARCI_HEALTH_TIMEOUT", "3"))
# Le résultat est gardé quelques secondes : plusieurs écrans qui rafraîchissent
# ne doivent pas multiplier les sondes.
CACHE_SECONDS = float(os.environ.get("FARCI_HEALTH_CACHE", "2"))
_cache: tuple[float, dict] | None = None


def probe(service: dict) -> dict:
    """Essaie chaque chemin de santé dans l'ordre ; UP au premier 200."""
    base = registry.base_url(service)
    result = {
        "id": service["id"],
        "label": service.get("label"),
        "tier": service.get("tier"),
        "critical": bool(service.get("critical")),
        "status": "unknown",
        "latency_ms": None,
    }
    if base is None:
        return result
    result["status"] = "down"
    started = time.monotonic()
    for path in service.get("health_paths") or []:
        try:
            with urllib.request.urlopen(base + path, timeout=TIMEOUT) as response:
                if response.status == 200:
                    result["status"] = "up"
                    break
        except (urllib.error.URLError, OSError, ValueError):
            continue
    result["latency_ms"] = round((time.monotonic() - started) * 1000)
    return result


def aggregate_status() -> dict:
    global _cache
    now = time.monotonic()
    if _cache and now - _cache[0] < CACHE_SECONDS:
        return _cache[1]
    services = registry.services()
    with ThreadPoolExecutor(max_workers=max(1, len(services))) as pool:
        results = list(pool.map(probe, services))
    states = {r["id"]: r["status"] == "up" for r in results}
    pipeline = registry.pipeline_state(states)
    status = {
        "status": "ready" if pipeline["state"] == "READY" else "degraded",
        "pipeline": pipeline,
        "services": results,
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "version": "2",
    }
    _cache = (now, status)
    return status


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/livez":
            self._send_json(200, {"status": "alive"})
        elif path == "/status":
            self._send_json(200, aggregate_status())
        elif path == "/healthz":
            status = aggregate_status()
            code = 200 if status["status"] == "ready" else 503
            self._send_json(code, {"status": status["status"], "missing": status["pipeline"]["missing"]})
        else:
            self._send_json(404, {"error": "not_found"})

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002 — signature imposée
        pass


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), HealthHandler)
    print(f"health-aggregator : écoute sur :{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
