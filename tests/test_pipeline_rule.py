"""CLINICAL PIPELINE READY : une seule règle, celle de scripts/services.py,
partagée par le tableau (./bin/farci status) et le health-aggregator.

Ces cas sont ceux que l'on joue devant la salle : s'ils changent, le
déroulé de l'étape 3 (docs/CHAOS.md) doit changer avec eux."""

from __future__ import annotations

import os
import sys
import unittest

from _paths import ROOT

os.environ.setdefault("FARCI_ROOT", str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))

import services  # noqa: E402

CORE_UP = {
    "caddy": True,
    "health-aggregator": True,
    "inference-ollama": True,
    "gateway-litellm": True,
    "docling": True,
    "phoenix": True,
    "open-webui": True,
}


def state(**changes):
    return services.pipeline_state({**CORE_UP, **changes})["state"]


class RegleDuPipeline(unittest.TestCase):
    def test_registre_coherent(self):
        self.assertEqual(services.validate_registry(), [])

    def test_coeur_complet(self):
        self.assertEqual(state(), "READY")

    def test_aucun_bonus_requis(self):
        bonus = [s["id"] for s in services.services() if s.get("tier") == "bonus"]
        self.assertTrue(bonus)
        self.assertEqual(services.pipeline_state({**CORE_UP, **{b: False for b in bonus}})["state"], "READY")

    def test_critiques_tous_du_coeur(self):
        for service in services.services():
            if service.get("critical") is True or service.get("critical_group"):
                self.assertIn(service.get("tier"), ("core", "bonus"))
            if service.get("critical") is True:
                self.assertEqual(service.get("tier"), "core", service["id"])

    def test_une_passerelle_suffit_litellm_ou_bifrost(self):
        self.assertEqual(state(**{"gateway-litellm": False, "gateway-bifrost": True}), "READY")
        self.assertNotEqual(state(**{"gateway-litellm": False, "gateway-bifrost": False}), "READY")
        noms = [e["nom"] for e in services.pipeline_state(CORE_UP)["exigences"]]
        self.assertIn("Une passerelle", noms)

    def test_scenario_01_un_runtime_suffit(self):
        self.assertEqual(state(**{"inference-ollama": False, "inference-llamacpp": True}), "READY")

    def test_scenario_02_plus_aucun_runtime(self):
        result = services.pipeline_state({**CORE_UP, "inference-ollama": False})
        self.assertEqual(result["state"], "DEGRADED")
        self.assertTrue(any(m.startswith("1 runtime") for m in result["missing"]))

    def test_scenario_05_docling_degrade(self):
        self.assertEqual(state(docling=False), "DEGRADED")

    def test_scenario_07_observabilite_hors_chemin_critique(self):
        self.assertEqual(state(phoenix=False), "READY")

    def test_rien_ne_repond(self):
        self.assertEqual(services.pipeline_state({})["state"], "NOT READY")


if __name__ == "__main__":
    unittest.main()
