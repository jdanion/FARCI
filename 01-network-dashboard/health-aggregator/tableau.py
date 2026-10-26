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
                           "equipe": team, "nom_equipe": TEAMS.get(team, ""), "ip": ip})
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
