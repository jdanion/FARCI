#!/usr/bin/env python3
"""FARCI — récepteur de webhooks Gitea.

Reçoit les événements push/PR de Gitea et déclenche le déploiement GitOps.
Stdlib uniquement : http.server, json, hmac, hashlib, subprocess.

Variables d'environnement :
    WEBHOOK_SECRET : secret partagé avec Gitea (header X-Gitea-Signature)
    GITOPS_SCRIPT  : chemin vers gitops.sh
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "")
GITOPS_SCRIPT = os.environ.get("GITOPS_SCRIPT", "/app/gitops/gitops.sh")
PORT = int(os.environ.get("WEBHOOK_PORT", "9000"))

# Événements à traiter
HANDLED_EVENTS = {"push", "pull_request"}


def verify_signature(payload: bytes, signature: str) -> bool:
    """Vérifie la signature HMAC du webhook Gitea."""
    if not WEBHOOK_SECRET:
        return True  # Pas de vérification si pas de secret

    expected = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def trigger_gitops(branch: str = "main"):
    """Déclenche le script GitOps."""
    script = Path(GITOPS_SCRIPT)
    if not script.exists():
        print(f"ERREUR: script gitops introuvable : {GITOPS_SCRIPT}")
        return False

    try:
        subprocess.run(
            [str(script), branch],
            check=True,
            capture_output=True,
            text=True,
        )
        print(f"GitOps déclenché pour la branche {branch}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"GitOps échoué: {e.stderr}")
        return False


class WebhookHandler(BaseHTTPRequestHandler):
    """Handler HTTP pour les webhooks Gitea."""

    def do_POST(self):
        if self.path != "/webhook":
            self._send_json(404, {"error": "not_found"})
            return

        # Lire le payload
        content_length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(content_length)

        # Vérifier la signature
        signature = self.headers.get("X-Gitea-Signature", "")
        if not verify_signature(payload, signature):
            self._send_json(401, {"error": "invalid_signature"})
            return

        # Parser l'événement
        try:
            event = json.loads(payload)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return

        # Déterminer le type d'événement
        gitea_event = self.headers.get("X-Gitea-Event", "")
        if gitea_event not in HANDLED_EVENTS:
            self._send_json(200, {"status": "ignored", "reason": "event_not_handled"})
            return

        # Extraire la branche
        branch = event.get("repository", {}).get("default_branch", "main")
        if gitea_event == "push":
            ref = event.get("ref", "")
            branch = ref.replace("refs/heads/", "") if ref.startswith("refs/heads/") else "main"

        # Déclencher GitOps
        if trigger_gitops(branch):
            self._send_json(200, {"status": "ok", "gitops": "triggered"})
        else:
            self._send_json(500, {"error": "gitops_failed"})

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), WebhookHandler)
    print(f"Webhook receiver listening on :{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
