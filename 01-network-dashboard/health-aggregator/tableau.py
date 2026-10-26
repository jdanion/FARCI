"""FARCI — le tableau de la salle : livraisons, points, badges, fil d'actualité.

Transforme les états successifs de la salle (scripts/services.py,
room_state) en événements et en scores. Aucune entrée manuelle : une équipe
marque des points quand l'accueil de la salle sert SA brique (✅), pas quand
elle le déclare.

Barème (positif seulement : une panne ne coûte rien, c'est la séance) :
  livraison d'une brique cœur      100   première fois servie par l'équipe
  livraison d'une brique bonus      50
  « Premiers ! »                    +50  première équipe à livrer une brique
  « Pipeline READY »                +50  chaque équipe ayant livré, quand le
                                         pipeline des équipes passe READY
  « Increvable »                    +50  une brique servie 30 min sans interruption

Stdlib uniquement ; l'état tient dans un petit JSON (sauvegarde et reprise).
"""

from __future__ import annotations

import json
import os
import time
from pathlib import Path

POINTS = {"core": 100, "bonus": 50, "premiers": 50, "ready": 50, "increvable": 50}
INCREVABLE_SECONDS = 30 * 60
MAX_EVENTS = 60

TEAMS = {
    "0": "GitOps", "1": "Réseau", "2": "Inférence", "3": "Passerelle", "4": "Documents",
    "5": "Observabilité", "6": "Évaluation", "7": "Applications", "8": "Agents",
}

# Les fiches du tableau : ce que l'on montre en touchant une tuile. « demo » est
# un appel en direct PAR L'ACCUEIL DE LA SALLE (même origine que la page).
FICHES = {
    "Network": {
        "role": "L'accueil de la salle : une seule adresse pour tout. Il envoie chaque demande vers la brique "
                "d'une équipe, ou vers la doublure du Pi si elle ne répond pas. L'agrégateur sonde tout le "
                "monde et alimente ce tableau.",
        "analogie": "L'accueil de l'hôpital : le patient ne connaît pas les numéros des services.",
        "contrat": "/v1  /runtime  /docling  /eds  /observability  /status",
        "demo": {"methode": "GET", "chemin": "/status", "resume": "status"},
    },
    "Inference": {
        "role": "Le runtime fait tourner le modèle de langage (Ollama, llama.cpp) et le sert sous un nom "
                "logique, med-extraction, avec l'API OpenAI.",
        "analogie": "Le modèle est le livre, le runtime est la personne qui le lit à voix haute.",
        "contrat": "API OpenAI : /v1/models, /v1/chat/completions  (accueil : /runtime/v1)",
        "demo": {"methode": "GET", "chemin": "/runtime/v1/models"},
    },
    "LLM Gateway": {
        "role": "La passerelle : le seul point d'entrée des applications vers les modèles. Elle réessaie, "
                "bascule sur un modèle de secours et mesure chaque appel.",
        "analogie": "Le standard téléphonique : on appelle un service, pas un poste.",
        "contrat": "API OpenAI par l'accueil : /v1/models, /v1/chat/completions",
        "demo": {"methode": "GET", "chemin": "/v1/models"},
    },
    "Documents": {
        "role": "Docling convertit les PDF en texte structuré avant l'extraction.",
        "analogie": "La secrétaire médicale qui retape un courrier reçu par fax.",
        "contrat": "/docling/v1/convert/file",
        "demo": {"methode": "GET", "chemin": "/docling/health"},
    },
    "EDS-NLP": {
        "role": "La bibliothèque de l'AP-HP : EDS-Pseudo remplace nom, IPP, NIR, dates… avant tout envoi au "
                "modèle, puis le LLM balise diagnostic, intervention, complication et stade.",
        "analogie": "Le secret médical : le modèle lit le dossier, pas l'identité du patient.",
        "contrat": "/eds/v1/pseudonymiser, /eds/v1/entites",
        "demo": {"methode": "POST", "chemin": "/eds/v1/pseudonymiser",
                 "corps": {"texte": "Patient : Jean Dupont, IPP 1234567890123, né le 15/03/1958. "
                                    "DPC pour adénocarcinome du pancréas.",
                           "contexte": {"NOM": ["Dupont"], "PRENOM": ["Jean"], "IPP": ["1234567890123"]}}},
    },
    "Observability": {
        "role": "Phoenix garde une trace de chaque appel au modèle : durée, tokens, erreurs. Si elle tombe, "
                "l'extraction continue : elle n'est pas sur le chemin du soin.",
        "analogie": "Le dossier de soins : on ne se souvient pas, on lit.",
        "contrat": "OpenTelemetry (OTLP) : /observability/v1/traces",
    },
    "Open WebUI": {
        "role": "Une interface de discussion branchée sur la passerelle, pour essayer un prompt à la main "
                "(et pour ceux qui n'ont pas de machine utilisable).",
        "analogie": "La consultation : on pose la question, on lit la réponse.",
        "contrat": "navigateur ; elle appelle /v1 comme toute application",
    },
    "GitOps": {"role": "La forge (Gitea) : chaque changement passe par une demande relue et vérifiée.",
               "analogie": "Le dossier de procédures : ce qui est écrit et relu est appliqué."},
    "Inference Secondary": {"role": "llama.cpp, un second runtime sur le même fichier de poids.",
                            "analogie": "Un second lecteur pour le même livre."},
    "Inference Mac": {"role": "oMLX, le runtime des Mac Apple Silicon.", "analogie": "Un lecteur spécialisé."},
    "Bifrost": {"role": "Une seconde passerelle : le client ne change pas d'adresse si la première tombe.",
                "analogie": "Un second standard téléphonique."},
    "Langfuse": {"role": "Un second backend de traces, sur le même flux OpenTelemetry.",
                 "analogie": "Une seconde lecture du même dossier de soins."},
    "MLflow": {"role": "Suit les expériences : une configuration (modèle, prompt) par essai, avec ses scores.",
               "analogie": "Le cahier de laboratoire."},
    "Uptime Kuma": {"role": "Sonde chaque service et garde l'historique de disponibilité.",
                    "analogie": "La surveillance continue au scope."},
    "Flowise": {"role": "Construire une chaîne d'extraction à la souris, sans code.",
                "analogie": "Le protocole dessiné plutôt qu'écrit."},
}

# La page utile de chaque service, ouverte depuis la fiche (sur sa machine).
PAGES = {
    "caddy": "/status", "health-aggregator": "/tableau", "gitea": "/",
    "inference-ollama": "/v1/models", "inference-llamacpp": "/v1/models", "inference-omlx": "/v1/models",
    "gateway-litellm": "/", "gateway-bifrost": "/", "docling": "/docs", "eds-nlp": "/health",
    "phoenix": "/", "langfuse": "/", "mlflow": "/", "uptime-kuma": "/", "open-webui": "/", "flowise": "/",
}

# Le déroulé de la séance (docs/WORKSHOP_FLOW.md), en minutes depuis le début.
PHASES = (
    (0, "Accueil"), (20, "Étape 1 — Construire"), (110, "Pause"), (120, "Étape 2 — Utiliser"),
    (170, "Évaluation"), (190, "Étape 3 — Casser"), (225, "Clôture"), (240, "Fin"),
)
DURATION_MIN = 240


def phase_at(minutes: float) -> dict:
    current = PHASES[0]
    for start, name in PHASES:
        if minutes >= start:
            current = (start, name)
    index = PHASES.index(current)
    end = PHASES[index + 1][0] if index + 1 < len(PHASES) else DURATION_MIN
    return {"nom": current[1], "debut_min": current[0], "fin_min": end}


def row_state(states: list[dict]) -> str:
    """equipe | reference | partiel | panne | inconnu — pour une ligne du tableau."""
    if not states:
        return "inconnu"
    if all(s["served_by"] == "equipe" for s in states):
        return "equipe"
    if all(s["served_by"] for s in states):
        return "reference"
    if any(s["served_by"] for s in states):
        return "partiel"
    if all(s["team"] == "unknown" and s["reference"] in (None, "unknown") for s in states):
        return "inconnu"
    return "panne"


class Scoreboard:
    """Mémoire de la séance. `update(room, services, rows)` à chaque sondage."""

    def __init__(self, path: str | os.PathLike | None = None, now: float | None = None):
        self.path = Path(path) if path else None
        self.reset(now)
        if self.path and self.path.is_file():
            try:
                self.__dict__.update(json.loads(self.path.read_text(encoding="utf-8")))
            except (ValueError, OSError):
                pass  # état illisible : on repart de zéro plutôt que de planter

    def reset(self, now: float | None = None) -> None:
        self.debut = now if now is not None else time.time()
        self.livres: dict[str, dict] = {}      # service -> {equipe, tier, at}
        self.servi_depuis: dict[str, float] = {}  # service -> servi par l'équipe depuis
        self.precedent: dict[str, str | None] = {}
        self.badges: list[dict] = []           # {equipe, badge, at}
        self.evenements: list[dict] = []
        self.ready_at: float | None = None
        self.chaos: list[str] = []
        self.seq = 0

    # --- persistance -------------------------------------------------------
    def to_json(self) -> dict:
        keys = ("debut", "livres", "servi_depuis", "precedent", "badges", "evenements",
                "ready_at", "chaos", "seq")
        return {k: getattr(self, k) for k in keys}

    def save(self) -> None:
        if not self.path:
            return
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.to_json(), ensure_ascii=False), encoding="utf-8")
        tmp.replace(self.path)

    # --- événements --------------------------------------------------------
    def _event(self, kind: str, text: str, now: float, team: str | None = None, points: int = 0) -> None:
        self.seq += 1
        self.evenements.append({"id": self.seq, "type": kind, "texte": text, "at": now,
                                "equipe": team, "points": points})
        del self.evenements[:-MAX_EVENTS]

    def _badge(self, team: str, badge: str, now: float, points: int) -> None:
        if any(b["equipe"] == team and b["badge"] == badge for b in self.badges):
            return
        self.badges.append({"equipe": team, "badge": badge, "at": now, "points": points})
        self._event("badge", f"Équipe {team} — {TEAMS.get(team, '')} : badge « {badge} »", now, team, points)

    def update(self, room: dict, services: list[dict], now: float | None = None) -> None:
        now = now if now is not None else time.time()
        by_id = {s["id"]: s for s in services}
        for state in room["services"]:
            sid, served = state["id"], state["served_by"]
            service = by_id.get(sid, {})
            team = str(service.get("team", ""))
            label = state.get("label") or sid
            before = self.precedent.get(sid, "absent")
            if served == "equipe":
                self.servi_depuis.setdefault(sid, now)
                if sid not in self.livres:
                    tier = service.get("tier", "core")
                    points = POINTS["core"] if tier == "core" else POINTS["bonus"]
                    self.livres[sid] = {"equipe": team, "tier": tier, "at": now, "points": points}
                    self._event("livraison", f"Équipe {team} livre {label}", now, team, points)
                    if len({v["equipe"] for v in self.livres.values()}) == 1 and len(self.livres) == 1:
                        self._badge(team, "Premiers !", now, POINTS["premiers"])
                elif before not in ("equipe", "absent"):
                    self._event("retour", f"{label} : l'équipe {team} reprend la main", now, team)
                if now - self.servi_depuis[sid] >= INCREVABLE_SECONDS:
                    self._badge(team, "Increvable", now, POINTS["increvable"])
            else:
                self.servi_depuis.pop(sid, None)
                if before == "equipe":
                    if served == "reference":
                        self._event("relais", f"La référence prend le relais : {label}", now, team)
                    else:
                        self._event("panne", f"{label} ne répond plus", now, team)
            self.precedent[sid] = served

        if room["pipeline"]["state"] == "READY" and self.ready_at is None:
            self.ready_at = now
            self._event("ready", "CLINICAL PIPELINE READY", now)
            for team in sorted({v["equipe"] for v in self.livres.values()}):
                self._badge(team, "Pipeline READY", now, POINTS["ready"])

        chaos = sorted(set(room.get("chaos", {}).get("exclues", [])) | set(room.get("chaos", {}).get("coupees", [])))
        for route in set(chaos) - set(self.chaos):
            self._event("chaos", f"Panne simulée : {route}", now)
        for route in set(self.chaos) - set(chaos):
            self._event("reparation", f"Réparé : {route}", now)
        self.chaos = chaos

    # --- vue ---------------------------------------------------------------
    def scores(self) -> list[dict]:
        teams: dict[str, dict] = {}
        for sid, item in self.livres.items():
            entry = teams.setdefault(item["equipe"], {"points": 0, "briques": [], "badges": []})
            entry["points"] += item["points"]
            entry["briques"].append(sid)
        for badge in self.badges:
            entry = teams.setdefault(badge["equipe"], {"points": 0, "briques": [], "badges": []})
            entry["points"] += badge["points"]
            entry["badges"].append(badge["badge"])
        ranked = [{"equipe": t, "nom": TEAMS.get(t, ""), **v} for t, v in teams.items()]
        return sorted(ranked, key=lambda e: (-e["points"], e["equipe"]))

    @staticmethod
    def _service_links(service: dict, state: dict, env: dict) -> dict:
        """Qui rend ce service, et où l'ouvrir : chez l'équipe, ou sur le Pi."""
        page = PAGES.get(str(service.get("id")), "/")
        ip, port = env.get(str(service.get("ip_var", "")), ""), env.get(str(service.get("port_var", "")), "")
        ref_ip, ref_port = env.get("REFERENCE_IP", ""), env.get(str(service.get("reference_port_var", "")), "")
        return {
            "id": service.get("id"), "label": state.get("label") or service.get("id"),
            "equipe": str(service.get("team", "")), "etat_equipe": state.get("team"),
            "servi_par": state.get("served_by"),
            "url_equipe": f"http://{ip}:{port}{page}" if ip and port else "",
            "url_reference": f"http://{ref_ip}:{ref_port}{page}" if ref_ip and ref_port else "",
        }

    def view(self, room: dict, services: list[dict], rows: list[dict], env: dict, now: float | None = None) -> dict:
        now = now if now is not None else time.time()
        by_id = {s["id"]: s for s in services}
        states = {s["id"]: s for s in room["services"]}
        lignes = []
        for row in rows:
            members = [states[sid] for sid in row.get("check", []) if sid in states]
            first = by_id.get(row.get("check", [""])[0], {})
            team = str(first.get("team", ""))
            ip = env.get(str(first.get("ip_var", "")), "")
            lignes.append({"label": row["label"], "tier": row.get("tier", "core"), "etat": row_state(members),
                           "equipe": team, "nom_equipe": TEAMS.get(team, ""), "ip": ip,
                           "fiche": FICHES.get(row["label"], {}),
                           "services": [self._service_links(by_id.get(m["id"], {}), m, env) for m in members]})
        minutes = (now - self.debut) / 60
        return {
            "lignes": lignes,
            "pipeline": room["pipeline"],
            "service_rendu": room["service_rendu"],
            "chaos": self.chaos,
            "rescue": room.get("rescue", []),
            "scores": self.scores(),
            "evenements": list(reversed(self.evenements[-12:])),
            "dernier_evenement": self.seq,
            "chrono": {"minutes": round(minutes, 1), "duree": DURATION_MIN, "phase": phase_at(minutes)},
            "heure": time.strftime("%H:%M", time.localtime(now)),
        }
