#!/usr/bin/env python3
"""FARCI — health-aggregator (FARCI §14).

Agrège l'état de santé de tous les services requis et optionnels.
Stdlib uniquement : http.server, urllib, json, yaml (PyYAML si dispo).

Endpoints :
  GET /status  → JSON détaillé (required, optional, status global)
  GET /healthz → 200 si tout est UP, 503 sinon (sonde Uptime Kuma)
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

CONFIG_PATH = Path(__file__).parent / "config" / "services.yaml"
PORT = int(os.environ.get("HEALTH_AGGREGATOR_PORT", "8081"))

# Services requis pour un statut "ready"
REQUIRED_SERVICES = [
    "caddy",
    "gateway_a",
    "runtime_ollama",
    "docling",
    "phoenix",
]

# Services optionnels
OPTIONAL_SERVICES = [
    "gitea",
    "uptime_kuma",
    "mlflow",
    "open_webui",
    "flowise",
    "langfuse",
]

# --------------------------------------------------------------------------
# Chargement de la configuration
# --------------------------------------------------------------------------

def load_services() -> dict:
    """Charge config/services.yaml (source de vérité)."""
    try:
        import yaml
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except ImportError:
        # Fallback : parsing minimal sans PyYAML
        services = {}
        current = None
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and line.endswith(":"):
                    current = line[:-1]
                    services[current] = {}
                elif current and ":" in line:
                    key, value = line.split(":", 1)
                    value = value.strip()
                    if value.startswith("${") and value.endswith("}"):
                        var_name = value[2:-1]
                        value = os.environ.get(var_name, "")
                    services[current][key.strip()] = value
        return services


# --------------------------------------------------------------------------
# Health check
# --------------------------------------------------------------------------

def check_service(name: str, config: dict) -> dict:
    """Vérique qu'un service répond."""
    host = config.get("host", "")
    port = int(config.get("port", 0))
    path = config.get("health_path", "/healthz")

    if not host or not port:
        return {"name": name, "status": "unknown", "latency_ms": 0}

    url = f"http://{host}:{port}{path}"
    start = time.time()
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=3) as resp:
            latency = int((time.time() - start) * 1000)
            return {
                "name": name,
                "status": "up" if resp.status == 200 else "degraded",
                "http_status": resp.status,
                "latency_ms": latency,
            }
    except urllib.error.HTTPError as e:
        latency = int((time.time() - start) * 1000)
        return {"name": name, "status": "down", "http_status": e.code, "latency_ms": latency}
    except Exception:
        latency = int((time.time() - start) * 1000)
        return {"name": name, "status": "down", "http_status": 0, "latency_ms": latency}


def aggregate_status() -> dict:
    """Agrège l'état de tous les services."""
    services = load_services()

    required = {}
    for name in REQUIRED_SERVICES:
        config = services.get(name, {})
        required[name] = check_service(name, config)

    optional = {}
    for name in OPTIONAL_SERVICES:
        config = services.get(name, {})
        optional[name] = check_service(name, config)

    all_up = all(s["status"] == "up" for s in required.values())

    return {
        "status": "ready" if all_up else "degraded",
        "required": required,
        "optional": optional,
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "version": "1",
    }


# --------------------------------------------------------------------------
# HTTP Server
# --------------------------------------------------------------------------

class HealthHandler(BaseHTTPRequestHandler):
    """Handler HTTP pour /status et /healthz."""

    def do_GET(self):
        if self.path == "/status":
            self._send_json(200, aggregate_status())
        elif self.path == "/healthz":
            status = aggregate_status()
            code = 200 if status["status"] == "ready" else 503
            self._send_json(code, {"status": status["status"]})
        else:
            self._send_json(404, {"error": "not_found"})

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Silence les logs HTTP pour ne pas spammer
        pass


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), HealthHandler)
    print(f"health-aggregator listening on :{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
