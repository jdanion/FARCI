"""Le tableau de la salle : points, badges, fil d'actualité, chrono.

Le moteur (01-network-dashboard/health-aggregator/tableau.py) ne voit que des
états de salle successifs, comme ceux de scripts/services.py (room_state) :
on les fabrique ici. Stdlib seulement, sans réseau ni Docker."""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

sys.path.insert(0, str(ROOT / "01-network-dashboard" / "health-aggregator"))
import tableau  # noqa: E402

SERVICES = [
    {"id": "caddy", "team": "1", "tier": "core", "ip_var": "CADDY_IP"},
    {"id": "inference-ollama", "team": "2", "tier": "core", "ip_var": "INFERENCE_A_IP"},
    {"id": "gateway-bifrost", "team": "3", "tier": "bonus", "ip_var": "GATEWAY_B_IP"},
]


def room(served: dict, pipeline: str = "DEGRADED", coupees=()) -> dict:
    return {
        "services": [{"id": sid, "label": sid, "team": "up" if s == "equipe" else "down",
                      "reference": "up" if s == "reference" else None, "served_by": s}
                     for sid, s in served.items()],
        "pipeline": {"state": pipeline, "missing": [], "met": 1, "required": 2, "exigences": []},
        "service_rendu": {"state": "READY", "missing": []},
        "rescue": [], "chaos": {"exclues": [], "coupees": list(coupees)},
    }


BASE = {"caddy": "reference", "inference-ollama": "reference", "gateway-bifrost": None}


class Points(unittest.TestCase):
    def setUp(self):
        self.board = tableau.Scoreboard(now=0)

    def tick(self, now, **served):
        self.board.update(room({**BASE, **served}), SERVICES, now=now)

    def test_livraison_et_premiers(self):
        self.tick(60, **{"inference-ollama": "equipe"})
        self.assertEqual(self.board.scores(), [{"equipe": "2", "nom": "Inférence", "points": 150,
                                                "briques": ["inference-ollama"], "badges": ["Premiers !"]}])

    def test_bonus_vaut_moins_et_premiers_une_seule_fois(self):
        self.tick(60, caddy="equipe")
        self.tick(120, caddy="equipe", **{"gateway-bifrost": "equipe"})
        points = {s["equipe"]: s["points"] for s in self.board.scores()}
        self.assertEqual(points, {"1": 150, "3": 50})

    def test_une_panne_ne_coute_rien_et_se_raconte(self):
        self.tick(60, caddy="equipe")
        self.tick(120, caddy="reference")
        self.tick(180, caddy="equipe")
        self.assertEqual(self.board.scores()[0]["points"], 150)
        types = [e["type"] for e in self.board.evenements]
        self.assertEqual(types, ["livraison", "badge", "relais", "retour"])

    def test_pipeline_ready_recompense_les_equipes_qui_ont_livre(self):
        self.tick(60, caddy="equipe")
        self.board.update(room({**BASE, "caddy": "equipe", "inference-ollama": "equipe"}, "READY"),
                          SERVICES, now=120)
        badges = {(b["equipe"], b["badge"]) for b in self.board.badges}
        self.assertIn(("1", "Pipeline READY"), badges)
        self.assertIn(("2", "Pipeline READY"), badges)
        self.assertEqual(sum(1 for e in self.board.evenements if e["type"] == "ready"), 1)

    def test_increvable_apres_trente_minutes(self):
        self.tick(0, caddy="equipe")
        self.tick(29 * 60, caddy="equipe")
        self.assertNotIn("Increvable", self.board.scores()[0]["badges"])
        self.tick(31 * 60, caddy="equipe")
        self.assertIn("Increvable", self.board.scores()[0]["badges"])

    def test_chaos_annonce_puis_repare(self):
        self.board.update(room(BASE, coupees=["inference"]), SERVICES, now=10)
        self.board.update(room(BASE), SERVICES, now=20)
        self.assertEqual([e["type"] for e in self.board.evenements], ["chaos", "reparation"])


class VueEtPersistance(unittest.TestCase):
    def test_vue_lignes_et_chrono(self):
        board = tableau.Scoreboard(now=0)
        rows = [{"label": "Inference", "tier": "core", "check": ["inference-ollama"]}]
        r = room({**BASE, "inference-ollama": "equipe"})
        board.update(r, SERVICES, now=60)
        view = board.view(r, SERVICES, rows, {"INFERENCE_A_IP": "198.51.100.20"}, now=45 * 60)
        self.assertEqual(view["lignes"][0]["etat"], "equipe")
        self.assertEqual(view["lignes"][0]["ip"], "198.51.100.20")
        self.assertEqual(view["chrono"]["phase"]["nom"], "Étape 1 — Construire")
        self.assertEqual(view["evenements"][0]["type"], "badge")  # le plus récent d'abord

    def test_sauvegarde_et_reprise(self):
        path = Path(tempfile.mkdtemp()) / "tableau.json"
        board = tableau.Scoreboard(path, now=0)
        board.update(room({**BASE, "caddy": "equipe"}), SERVICES, now=60)
        board.save()
        again = tableau.Scoreboard(path)
        self.assertEqual(again.scores(), board.scores())
        self.assertEqual(again.debut, 0)

    def test_etats_de_ligne(self):
        self.assertEqual(tableau.row_state([{"served_by": "equipe"}, {"served_by": "reference"}]), "reference")
        self.assertEqual(tableau.row_state([{"served_by": None, "team": "down", "reference": "down"}]), "panne")
        self.assertEqual(tableau.row_state([]), "inconnu")


class PageHorsLigne(unittest.TestCase):
    def test_aucune_ressource_externe(self):
        html = (ROOT / "01-network-dashboard" / "tableau" / "index.html").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"""(src|href)=["']https?://""", html))
        self.assertIn('fetch("/tableau/etat"', html)


if __name__ == "__main__":
    unittest.main()
