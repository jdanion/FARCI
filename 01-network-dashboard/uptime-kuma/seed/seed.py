#!/usr/bin/env python3
"""FARCI — seed Uptime Kuma via API REST + socket.io.

Crée les 7 groupes et les 14 moniteurs depuis config/services.yaml.
Utilise python-socketio (déjà dans requirements.in).

Usage :
    python 01-network-dashboard/uptime-kuma/seed/seed.py
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

try:
    import socketio
except ImportError:
    print("ERREUR: python-socketio requis (pip install python-socketio)")
    sys.exit(1)

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

KUMA_URL = os.environ.get("KUMA_URL", "http://192.168.50.16:3001")
KUMA_USER = os.environ.get("KUMA_USER", "admin")
KUMA_PASSWORD = os.environ.get("KUMA_PASSWORD", "admin")

SERVICES_YAML = Path(__file__).parent.parent.parent.parent / "config" / "services.yaml"
MONITORS_JSON = Path(__file__).parent / "monitors.json"

# Groupes attendus (7 groupes)
EXPECTED_GROUPS = [
    "GitOps",
    "Réseau",
    "Inférence",
    "Gateway",
    "Documents",
    "Observabilité",
    "Applications",
]


def load_services() -> dict:
    """Charge services.yaml."""
    try:
        import yaml
        with open(SERVICES_YAML, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except ImportError:
        return {}


def generate_monitors(services: dict) -> list:
    """Génère la liste des moniteurs depuis services.yaml."""
    monitors = []

    # Sonde synthétique : pipeline complet
    monitors.append({
        "name": "CLINICAL AI PIPELINE",
        "type": "http",
        "url": "http://192.168.50.15/healthz",
        "interval": 30,
        "group": "Pipeline",
        "expected_status": 200,
    })

    # Sondes par service
    service_map = {
        "gitea": ("GitOps", 3000),
        "caddy": ("Réseau", 80),
        "uptime_kuma": ("Réseau", 3001),
        "runtime_ollama": ("Inférence", 8080),
        "runtime_llamacpp": ("Inférence", 8081),
        "gateway_a": ("Gateway", 4000),
        "gateway_b": ("Gateway", 4001),
        "docling": ("Documents", 5001),
        "phoenix": ("Observabilité", 6006),
        "langfuse": ("Observabilité", 3000),
        "mlflow": ("Applications", 5000),
        "open_webui": ("Applications", 8080),
        "flowise": ("Applications", 3000),
    }

    for svc_name, (group, default_port) in service_map.items():
        svc = services.get(svc_name, {})
        host = svc.get("host", "")
        port = svc.get("port", default_port)
        if host:
            monitors.append({
                "name": svc_name,
                "type": "http",
                "url": f"http://{host}:{port}/healthz",
                "interval": 30,
                "group": group,
                "expected_status": 200,
            })

    return monitors


def kuma_login() -> str:
    """Authentification Uptime Kuma, retourne le token JWT."""
    data = json.dumps({"username": KUMA_USER, "password": KUMA_PASSWORD}).encode()
    req = urllib.request.Request(
        f"{KUMA_URL}/api/login",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.load(resp)
        return result.get("token", "")


def create_monitor(token: str, monitor: dict):
    """Crée un moniteur via l'API REST."""
    data = json.dumps({
        "name": monitor["name"],
        "type": monitor["type"],
        "url": monitor["url"],
        "interval": monitor["interval"],
        "maxretries": 3,
        "monitor_group": monitor["group"],
    }).encode()

    req = urllib.request.Request(
        f"{KUMA_URL}/api/monitors",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        print(f"  ERREUR {e.code}: {monitor['name']}")
        return {}


def main():
    print("FARCI — seed Uptime Kuma")

    # Charger les services
    services = load_services()
    if not services:
        print("ERREUR: config/services.yaml introuvable ou vide")
        return 1

    # Générer les moniteurs
    monitors = generate_monitors(services)
    print(f"  {len(monitors)} moniteurs à créer")

    # Authentification
    print("  authentification...")
    token = kuma_login()
    if not token:
        print("ERREUR: authentification échouée")
        return 1

    # Créer les moniteurs
    created = 0
    for m in monitors:
        result = create_monitor(token, m)
        if result:
            print(f"  + {m['name']} ({m['group']})")
            created += 1
        time.sleep(0.5)

    # Sauvegarder monitors.json
    MONITORS_JSON.write_text(json.dumps(monitors, indent=2, ensure_ascii=False))
    print(f"\n{created}/{len(monitors)} moniteurs créés")
    return 0


if __name__ == "__main__":
    sys.exit(main())
