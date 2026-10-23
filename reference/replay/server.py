#!/usr/bin/env python3
"""FARCI — runtime « rejoué » : plan C, sans GPU ni modèle.

Un runtime d'inférence conforme au contrat (02-inference/CONTRACT.md) qui ne
calcule rien : il reconnaît le dossier patient envoyé et renvoie la réponse
ENREGISTRÉE pour lui (reference/replay/recordings.json). Les étapes 2 et 3 de
l'atelier fonctionnent donc même si aucun modèle ne tourne dans la salle.

Ce qu'il implémente du contrat :
  GET  /v1/models              med-extraction, med-extraction-lite, med-chaos
  POST /v1/chat/completions    réponse complète, ou en flux SSE (stream: true)
  GET  /health, /healthz       {"status": "ok"}
  le raisonnement sort dans `reasoning_content`, jamais dans `content`

Reconnaissance du dossier : par recouvrement des lignes cliniques du message
avec celles de chaque dossier de datasets/raw/. Les lignes d'identité (nom,
IPP, NIR, date de naissance) sont ignorées : un dossier pseudonymisé est donc
reconnu comme l'original. Prompt v2 détecté par son titre dans le message
système ; v1 sinon. Modèle `med-chaos` : réponse hors schéma (scénario 04).

Stdlib uniquement. Usage :
    python3 reference/replay/server.py                # port REPLAY_PORT ou 8090
    python3 reference/replay/server.py --port 18090 --delay 0
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RAW = Path(os.environ.get("REPLAY_RAW_DIR", ROOT / "datasets" / "raw"))
RECORDINGS = Path(os.environ.get("REPLAY_RECORDINGS", HERE / "recordings.json"))
MODELS = ("med-extraction", "med-extraction-lite", "med-chaos")
IDENTITY = re.compile(r"^(patient|patiente|nom|prenom|ipp|nir|date de naissance)\b")
NOT_A_DOSSIER = (
    "Mode rejoué (plan C) : je ne reconnais pas de dossier du jeu de données "
    "dans ce message. Collez le contenu d'un dossier de datasets/raw/."
)


def normalize(line: str) -> str:
    text = unicodedata.normalize("NFKD", line.lower().replace("œ", "oe"))
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", text).strip(" -:")


def clinical_lines(text: str) -> set[str]:
    lines = set()
    for raw in text.splitlines():
        line = normalize(raw)
        if len(line) < 6 or IDENTITY.match(line) or "[" in line:
            continue
        lines.add(line)
    return lines


class Library:
    """Les dossiers connus et leurs réponses enregistrées."""

    def __init__(self, raw_dir: Path = RAW, recordings: Path = RECORDINGS):
        self.fingerprints: dict[str, set[str]] = {}
        for path in sorted(raw_dir.glob("patient_*.txt")):
            key = path.name.split("_")[1]
            self.fingerprints.setdefault(key, set()).update(
                clinical_lines(path.read_text(encoding="utf-8"))
            )
        self.recordings = json.loads(recordings.read_text(encoding="utf-8"))["models"]
        # Une ligne commune à tous les dossiers (« Intervention : DPC ») ne
        # distingue rien : on ne compte que les lignes rares.
        counts: dict[str, int] = {}
        for lines in self.fingerprints.values():
            for line in lines:
                counts[line] = counts.get(line, 0) + 1
        self.weight = {line: 1.0 / n for line, n in counts.items()}

    def identify(self, text: str) -> str | None:
        lines = clinical_lines(text)
        best, best_score = None, 0.0
        for key, fingerprint in self.fingerprints.items():
            score = sum(self.weight[line] for line in lines & fingerprint)
            if score > best_score:
                best, best_score = key, score
        return best if best_score >= 1.0 else None

    def answer(self, model: str, prompt: str, key: str) -> str:
        if model == "med-chaos":
            return self.recordings["med-chaos"]["*"][key]
        table = self.recordings["med-extraction"]
        return table.get(prompt, table["v1"]).get(key, NOT_A_DOSSIER)


def prompt_version(messages: list) -> str:
    system = " ".join(str(m.get("content", "")) for m in messages if m.get("role") == "system")
    return "v2" if re.search(r"prompt d'extraction v2", system) else "v1"


def completion(library: Library, body: dict) -> tuple[str, str, str]:
    """(modèle, contenu, raisonnement) pour une requête chat."""
    model = body.get("model") or "med-extraction"
    if model not in MODELS:
        model = "med-extraction"
    messages = body.get("messages") or []
    user_text = "\n".join(str(m.get("content", "")) for m in messages if m.get("role") == "user")
    key = library.identify(user_text)
    prompt = prompt_version(messages)
    if key is None:
        return model, NOT_A_DOSSIER, "Mode rejoué : aucun dossier reconnu."
    content = library.answer(model, prompt, key)
    reasoning = f"Mode rejoué : dossier reconnu, réponse enregistrée (prompt {prompt})."
    return model, content, reasoning


class Handler(BaseHTTPRequestHandler):
    library: Library
    delay: float = 0.0
    protocol_version = "HTTP/1.1"

    def _json(self, code: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 — nom imposé par http.server
        path = self.path.split("?", 1)[0].rstrip("/")
        if path in ("/health", "/healthz", "/livez"):
            self._json(200, {"status": "ok", "mode": "replay"})
        elif path in ("/v1/models", "/models"):
            self._json(200, {"object": "list", "data": [
                {"id": m, "object": "model", "owned_by": "farci-replay"} for m in MODELS
            ]})
        else:
            self._json(404, {"error": {"message": f"chemin inconnu : {path}", "type": "not_found"}})

    def do_POST(self):  # noqa: N802
        path = self.path.split("?", 1)[0].rstrip("/")
        if path not in ("/v1/chat/completions", "/chat/completions"):
            self._json(404, {"error": {"message": f"chemin inconnu : {path}", "type": "not_found"}})
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self._json(400, {"error": {"message": "corps JSON invalide", "type": "invalid_request_error"}})
            return
        model, content, reasoning = completion(self.library, body)
        if self.delay:
            time.sleep(self.delay)
        ident = f"chatcmpl-replay-{uuid.uuid4().hex[:12]}"
        created = int(time.time())
        prompt_tokens = sum(len(str(m.get("content", ""))) for m in body.get("messages") or []) // 4
        usage = {"prompt_tokens": prompt_tokens, "completion_tokens": len(content) // 4,
                 "total_tokens": prompt_tokens + len(content) // 4}
        if body.get("stream"):
            self._stream(ident, created, model, content, reasoning)
            return
        self._json(200, {
            "id": ident, "object": "chat.completion", "created": created, "model": model,
            "choices": [{"index": 0, "finish_reason": "stop", "message": {
                "role": "assistant", "content": content, "reasoning_content": reasoning}}],
            "usage": usage,
        })

    def _stream(self, ident: str, created: int, model: str, content: str, reasoning: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()

        def send(delta: dict, finish=None) -> None:
            chunk = {"id": ident, "object": "chat.completion.chunk", "created": created, "model": model,
                     "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
            self.wfile.write(f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n".encode("utf-8"))

        send({"role": "assistant", "reasoning_content": reasoning})
        for start in range(0, len(content), 40):
            send({"content": content[start:start + 40]})
        send({}, finish="stop")
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()
        self.close_connection = True

    def log_message(self, format, *args):  # noqa: A002 — signature imposée
        if os.environ.get("REPLAY_VERBOSE"):
            sys.stderr.write("replay: " + format % args + "\n")


def make_server(port: int, delay: float = 0.0, host: str = "0.0.0.0") -> ThreadingHTTPServer:
    handler = type("ReplayHandler", (Handler,), {"library": Library(), "delay": delay})
    return ThreadingHTTPServer((host, port), handler)


def main() -> int:
    parser = argparse.ArgumentParser(description="FARCI — runtime rejoué (plan C, sans modèle)")
    parser.add_argument("--port", type=int, default=int(os.environ.get("REPLAY_PORT", "8090")))
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--delay", type=float, default=float(os.environ.get("REPLAY_DELAY", "0.3")),
                        help="latence simulée par réponse, en secondes")
    args = parser.parse_args()
    server = make_server(args.port, args.delay, args.host)
    print(f"runtime rejoué : http://{args.host}:{args.port}/v1 "
          f"({len(server.RequestHandlerClass.library.fingerprints)} dossiers connus)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
