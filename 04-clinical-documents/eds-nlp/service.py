#!/usr/bin/env python3
"""FARCI — service EDS-NLP (équipe 4) : pseudonymiser, puis extraire des entités.

Deux briques de l'AP-HP, servies en HTTP :
  - EDS-Pseudo (règles + contexte patient) : remplace nom, prénom, IPP, NIR,
    dates, adresses, téléphones… par [NOM], [IPP]… AVANT tout envoi à un modèle ;
  - eds.llm_markup_extractor (EDS-NLP) : demande au LLM de la salle (passerelle,
    API OpenAI) de recopier le texte en balisant diagnostic, intervention,
    complication et stade, puis réaligne les balises sur le texte.

    GET  /health, /livez         {"status": "ok", ...}
    POST /v1/pseudonymiser       {"texte": "...", "contexte": {"NOM": ["Dupont"], ...}}
         → {"texte": "<texte pseudonymisé>", "entites": [{"label", "debut", "fin", "texte"}]}
    POST /v1/entites             {"texte": "...", "contexte": {...}, "pseudonymiser": true}
         → {"texte_envoye": "...", "entites": [...], "modele": "med-extraction"}

Le contexte est ce que le dossier informatisé sait déjà du patient (nom,
IPP, NIR) : c'est l'usage d'EDS-Pseudo à l'AP-HP. /v1/entites pseudonymise
d'abord, sauf "pseudonymiser": false : aucune identité ne part vers le modèle.

Configuration (environnement) : FARCI_GATEWAY_URL (le LLM, par l'accueil de la
salle), EDS_LLM_MODEL (défaut med-extraction), EDS_NLP_LISTEN_PORT (défaut 8000).
"""

from __future__ import annotations

import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTEXT_KEYS = ("NOM", "PRENOM", "IPP", "NDA", "SECU", "DATE_NAISSANCE",
                "ADRESSE", "VILLE", "ZIP", "TEL", "MAIL", "HOPITAL")
MAX_CHARS = 20_000


def build_pseudonymizer():
    """EDS-Pseudo, version règles + contexte (sans modèle appris ni PyTorch)."""
    import edsnlp
    import eds_pseudo  # noqa: F401 — enregistre les composants eds_pseudo.*

    nlp = edsnlp.blank("eds")
    nlp.add_pipe("eds.normalizer")
    nlp.add_pipe("eds_pseudo.simple_rules", config={"pattern_keys": ["TEL", "MAIL", "SECU", "PERSON"]})
    nlp.add_pipe("eds_pseudo.addresses")
    nlp.add_pipe("eds_pseudo.dates")
    nlp.add_pipe("eds_pseudo.context")
    return nlp


def build_extractor(api_url: str, model: str):
    """eds.llm_markup_extractor branché sur la passerelle de la salle."""
    import edsnlp
    import edsnlp.pipes as eds
    from edsnlp.data.converters import MarkupToDocConverter

    convert = MarkupToDocConverter(preset="xml")
    examples = [convert(line) for line in
                (HERE / "exemples.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    nlp = edsnlp.blank("eds")
    nlp.add_pipe(eds.llm_markup_extractor(
        api_url=api_url,
        model=model,
        prompt=(HERE / "prompt.md").read_text(encoding="utf-8").strip(),
        examples=examples,
        max_few_shot_examples=len(examples),
        use_retriever=False,
        api_kwargs={"temperature": 0},
    ))
    return nlp


def spans(doc) -> list[dict]:
    return [{"label": ent.label_, "debut": ent.start_char, "fin": ent.end_char, "texte": ent.text}
            for ent in sorted(doc.ents, key=lambda e: e.start_char)]


def clean_context(raw) -> dict[str, list[str]]:
    """Contexte patient accepté : {CLÉ: [valeurs]} ou {CLÉ: "valeur"}."""
    if not isinstance(raw, dict):
        return {}
    context = {}
    for key, values in raw.items():
        key = str(key).upper()
        if key not in CONTEXT_KEYS:
            continue
        values = [values] if isinstance(values, str) else values
        context[key] = [str(v) for v in values if str(v).strip()]
    return context


class Service:
    """Les deux pipelines, chargés une fois ; un verrou les protège (le LLM
    de la salle traite de toute façon une requête à la fois)."""

    def __init__(self, api_url: str, model: str):
        self.api_url, self.model = api_url, model
        self.pseudonymizer = build_pseudonymizer()
        self.extractor = build_extractor(api_url, model)
        self.lock = threading.Lock()

    def pseudonymize(self, text: str, context: dict) -> dict:
        with self.lock:
            doc = self.pseudonymizer.make_doc(text)
            doc._.context = dict(context)
            doc = self.pseudonymizer(doc)
        found = spans(doc)
        result = text
        for span in reversed(found):
            result = result[:span["debut"]] + f"[{span['label']}]" + result[span["fin"]:]
        return {"texte": result, "entites": found}

    def entities(self, text: str, context: dict, pseudonymize: bool = True) -> dict:
        sent = self.pseudonymize(text, context)["texte"] if pseudonymize else text
        with self.lock:
            doc = self.extractor(sent)
        return {"texte_envoye": sent, "entites": spans(doc), "modele": self.model}


class Handler(BaseHTTPRequestHandler):
    service: Service

    def _json(self, code: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 — nom imposé par http.server
        if self.path.split("?", 1)[0].rstrip("/") in ("/health", "/healthz", "/livez"):
            self._json(200, {"status": "ok", "llm": self.service.api_url, "modele": self.service.model})
        else:
            self._json(404, {"erreur": f"chemin inconnu : {self.path}"})

    def do_POST(self):  # noqa: N802
        path = self.path.split("?", 1)[0].rstrip("/")
        if path not in ("/v1/pseudonymiser", "/v1/entites"):
            self._json(404, {"erreur": f"chemin inconnu : {path}"})
            return
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
            text = body["texte"]
            if not isinstance(text, str) or not text.strip() or len(text) > MAX_CHARS:
                raise ValueError
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            self._json(400, {"erreur": f'corps attendu : {{"texte": "...", "contexte": {{...}}}} ({MAX_CHARS} caractères au plus)'})
            return
        context = clean_context(body.get("contexte"))
        if path == "/v1/pseudonymiser":
            self._json(200, self.service.pseudonymize(text, context))
            return
        try:
            self._json(200, self.service.entities(text, context, body.get("pseudonymiser", True) is not False))
        except Exception as exc:  # passerelle injoignable, réponse illisible…
            self._json(502, {"erreur": f"le LLM n'a pas répondu correctement ({self.service.api_url}) : {exc}"})

    def log_message(self, format, *args):  # noqa: A002 — signature imposée
        sys.stderr.write("eds-nlp: " + (format % args) + "\n")


def make_server(service: Service, port: int, host: str = "0.0.0.0") -> ThreadingHTTPServer:
    handler = type("BoundHandler", (Handler,), {"service": service})
    return ThreadingHTTPServer((host, port), handler)


def main() -> int:
    api_url = os.environ.get("FARCI_GATEWAY_URL", "")
    if not api_url:
        sys.exit("FARCI_GATEWAY_URL manquante : l'adresse du LLM de la salle (…/v1)")
    os.environ.setdefault("OPENAI_API_KEY", "farci")
    service = Service(api_url, os.environ.get("EDS_LLM_MODEL", "med-extraction"))
    port = int(os.environ.get("EDS_NLP_LISTEN_PORT", "8000"))
    print(f"EDS-NLP prêt sur :{port} (LLM : {api_url}, modèle : {service.model})", flush=True)
    make_server(service, port).serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
