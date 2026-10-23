"""Repli pédagogique : l'accueil sert la brique de l'équipe si elle est saine,
sinon celle de la référence ; `rescue` force la référence ; le chaos coupe
une route ; le tableau dit qui rend le service (✅ / 🛟).

Deux runtimes rejoués jouent l'équipe 2 et la référence, sur 127.0.0.1 :
aucun Docker, aucun réseau de salle."""

from __future__ import annotations

import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

from _paths import ROOT

sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "reference" / "replay"))

import board  # noqa: E402
import server  # noqa: E402
import services  # noqa: E402

BASE_ENV = {
    "REFERENCE_IP": "198.51.100.1",
    "FARCI_SUBNET": "198.51.100.0/24",
    "ENTRY_PORT": "80", "REPLAY_PORT": "8090", "GATEWAY_A_PORT": "4000",
    "GATEWAY_B_PORT": "4001", "INFERENCE_A_PORT": "11434", "INFERENCE_B_PORT": "8081",
    "INFERENCE_C_PORT": "8082", "DOCLING_PORT": "5001", "PHOENIX_PORT": "6006",
    "CADDY_PORT": "8080", "HEALTH_AGGREGATOR_PORT": "8088", "OPEN_WEBUI_PORT": "3080",
}


def isolated(env: dict):
    """Environnement maîtrisé + FARCI_ROOT temporaire (aucun état réel lu)."""
    root = tempfile.mkdtemp()
    (Path(root) / "config").mkdir()
    (Path(root) / "config" / "services.yaml").write_text(
        (ROOT / "config" / "services.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    return mock.patch.dict(os.environ, {**env, "FARCI_ROOT": root}, clear=True), Path(root)


class Amonts(unittest.TestCase):
    def run_with(self, extra: dict, rescue: str = "", chaos: str = "") -> dict:
        patcher, root = isolated({**BASE_ENV, **extra})
        with patcher, mock.patch.object(services, "REGISTRY", str(root / "config" / "services.yaml")):
            if rescue:
                (root / "config" / "rescue.env").write_text(f"FARCI_RESCUE={rescue}\n")
            if chaos:
                (root / ".chaos").mkdir()
                (root / ".chaos" / "routes.env").write_text(chaos)
            return services.upstreams()

    def test_sans_equipe_la_reference_sert(self):
        up = self.run_with({})
        self.assertEqual(up["UP_INFERENCE"], "198.51.100.1:8090")
        self.assertEqual(up["UP_PASSERELLE"], "198.51.100.1:4000")

    def test_equipe_puis_reference(self):
        up = self.run_with({"INFERENCE_A_IP": "198.51.100.20", "INFERENCE_B_IP": "198.51.100.21"})
        self.assertEqual(up["UP_INFERENCE"], "198.51.100.20:11434 198.51.100.21:8081 198.51.100.1:8090")

    def test_bifrost_avant_la_reference(self):
        up = self.run_with({"GATEWAY_A_IP": "198.51.100.30", "GATEWAY_B_IP": "198.51.100.31"})
        self.assertEqual(up["UP_PASSERELLE"], "198.51.100.30:4000 198.51.100.31:4001 198.51.100.1:4000")

    def test_rescue_force_la_reference(self):
        up = self.run_with({"DOCLING_IP": "198.51.100.46"}, rescue="documents")
        self.assertEqual(up["UP_DOCUMENTS"], "198.51.100.1:5001")

    def test_chaos_exclut_ou_coupe(self):
        up = self.run_with({"INFERENCE_A_IP": "198.51.100.20", "OBSERVABILITY_A_IP": "198.51.100.40"},
                           chaos="FARCI_CHAOS_EXCLUDE=inference\nFARCI_CHAOS_BLOCK=observabilite\n")
        self.assertEqual(up["UP_INFERENCE"], "198.51.100.1:8090")
        self.assertEqual(up["UP_OBSERVABILITE"], "127.0.0.1:9")

    def test_brique_sur_le_pi_lui_meme_sans_doublon(self):
        up = self.run_with({"GATEWAY_A_IP": "198.51.100.1"})
        self.assertEqual(up["UP_PASSERELLE"], "198.51.100.1:4000")


class TableauEquipeOuReference(unittest.TestCase):
    """room_state contre de vrais serveurs HTTP (runtimes rejoués)."""

    @classmethod
    def setUpClass(cls):
        cls.team = server.make_server(0, host="127.0.0.1")
        cls.reference = server.make_server(0, host="127.0.0.1")
        for httpd in (cls.team, cls.reference):
            threading.Thread(target=httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.team.shutdown()
        cls.reference.shutdown()

    def room(self, team_up: bool, rescue: str = "", chaos: str = "") -> dict:
        env = {**BASE_ENV, "REFERENCE_IP": "127.0.0.1",
               "REPLAY_PORT": str(self.reference.server_address[1]),
               "INFERENCE_A_IP": "127.0.0.1",
               "INFERENCE_A_PORT": str(self.team.server_address[1] if team_up else 9)}
        patcher, root = isolated(env)
        with patcher, mock.patch.object(services, "REGISTRY", str(root / "config" / "services.yaml")):
            if rescue:
                (root / "config" / "rescue.env").write_text(f"FARCI_RESCUE={rescue}\n")
            if chaos:
                (root / ".chaos").mkdir()
                (root / ".chaos" / "routes.env").write_text(chaos)
            return services.room_state(timeout=1)

    def inference(self, room: dict) -> dict:
        return next(s for s in room["services"] if s["id"] == "inference-ollama")

    def test_equipe_saine(self):
        self.assertEqual(self.inference(self.room(True))["served_by"], "equipe")

    def test_equipe_absente_reference(self):
        room = self.room(False)
        self.assertEqual(self.inference(room)["served_by"], "reference")
        rendered = board.render(room, show_all=False)
        self.assertIn("🛟 REF", rendered)
        self.assertIn("NOT READY", rendered)

    def test_rescue_le_tableau_montre_la_reference(self):
        """L'équipe répond, mais l'accueil sert la référence : le tableau le dit."""
        room = self.room(True, rescue="inference")
        self.assertEqual(self.inference(room)["served_by"], "reference")
        self.assertEqual(room["pipeline"]["state"], "NOT READY")
        self.assertIn("🛟 REF", board.render(room, show_all=False))

    def test_chaos_coupe_personne_ne_sert(self):
        room = self.room(True, chaos="FARCI_CHAOS_BLOCK=inference\n")
        self.assertIsNone(self.inference(room)["served_by"])
        rendered = board.render(room, show_all=False)
        self.assertIn("PANNE EN COURS", rendered)
        self.assertNotIn("✅", rendered.split("Inference")[1].splitlines()[0])

    def test_cadre_aligne_malgre_les_emojis(self):
        rendered = board.render(self.room(True), show_all=True)
        widths = {board.width(line) for line in rendered.splitlines() if line.startswith(("║", "╔", "╚", "╠"))}
        self.assertEqual(len(widths), 1, widths)


if __name__ == "__main__":
    unittest.main()
