#!/usr/bin/env python3
"""FARCI — Agent Arcane de supervision.

Supervise une brique du pipeline et alerte en cas d'anomalie.
Stdlib uniquement : urllib, json, time, http.server.

Variables d'environnement :
    TARGET_SERVICE   : nom de la brique (ollama, llamacpp, gateway, ...)
    TARGET_URL       : URL de healthcheck de la brique
    CHECK_INTERVAL   : intervalle de vérification en secondes
    ALERT_WEBHOOK    : URL de webhook d'alerte (optionnel)
"""

from __future__ import annotations

import json
import os
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone

TARGET_SERVICE = os.environ.get("TARGET_SERVICE", "unknown")
TARGET_URL = os.environ["TARGET_URL"]  # fourni par docker-compose.yml, aucune valeur par défaut
CHECK_INTERVAL = int(os.environ.get("CHECK_INTERVAL", "30"))
ALERT_WEBHOOK = os.environ.get("ALERT_WEBHOOK", "")


def check_service() -> dict:
    """Vérifie l'état de santé de la brique cible."""
    result = {
        "service": TARGET_SERVICE,
        "url": TARGET_URL,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "unknown",
        "latency_ms": 0,
        "http_status": 0,
    }

    start = time.time()
    try:
        req = urllib.request.Request(TARGET_URL, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            result["latency_ms"] = int((time.time() - start) * 1000)
            result["http_status"] = resp.status
            result["status"] = "up" if resp.status == 200 else "degraded"
    except urllib.error.HTTPError as e:
        result["latency_ms"] = int((time.time() - start) * 1000)
        result["http_status"] = e.code
        result["status"] = "down"
    except Exception as e:
        result["latency_ms"] = int((time.time() - start) * 1000)
        result["status"] = "error"
        result["error"] = str(e)

    return result


def send_alert(result: dict):
    """Envoie une alerte si le webhook est configuré."""
    if not ALERT_WEBHOOK:
        return

    try:
        data = json.dumps(result).encode("utf-8")
        req = urllib.request.Request(
            ALERT_WEBHOOK,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        # Ne jamais bloquer sur l'alerte
        pass


def main():
    """Boucle principale de supervision."""
    print(f"Arcane agent started: {TARGET_SERVICE} -> {TARGET_URL}")

    while True:
        result = check_service()

        # Log le résultat
        status_icon = "🟢" if result["status"] == "up" else "🔴"
        print(f"{status_icon} [{result['timestamp']}] {TARGET_SERVICE}: {result['status']} ({result['latency_ms']}ms)")

        # Alerter si le service est down
        if result["status"] != "up":
            send_alert(result)

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
