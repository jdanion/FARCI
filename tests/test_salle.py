"""Onglet formateur du tableau : noms, étudiants, adresses, suivi.

Le module (01-network-dashboard/health-aggregator/salle.py) travaille sur une
copie temporaire de config/ : network.env et salle.json. Ni réseau ni Docker
(FARCI_CADDY_ADMIN n'est pas défini : pas de rechargement)."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "01-network-dashboard" / "health-aggregator"))
import salle  # noqa: E402
import services  # noqa: E402

# Le registre du dépôt, quel que soit FARCI_ROOT (pointé plus bas sur une copie de config/).
services.REGISTRY = str(ROOT / "config" / "services.yaml")

NETWORK_ENV = """# réseau de test
FARCI_SUBNET=198.51.100.0/24
REFERENCE_IP=198.51.100.1
GATEWAY_A_IP=
GATEWAY_A_PORT=4000
"""


class Salle(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        for sub in ("config", "01-network-dashboard/caddy"):
            (self.tmp / sub).mkdir(parents=True)
        shutil.copy(ROOT / "01-network-dashboard" / "caddy" / "Caddyfile", self.tmp / "01-network-dashboard" / "caddy")
        # L'exemple du dépôt, avec le réseau de test à la place de ses valeurs.
        cles = {line.split("=", 1)[0] for line in NETWORK_ENV.splitlines() if "=" in line}
        base = [line for line in (ROOT / "config" / "network.env.example").read_text(encoding="utf-8").splitlines()
                if line.split("=", 1)[0] not in cles]
        (self.tmp / "config" / "network.env").write_text("\n".join(base) + "\n" + NETWORK_ENV, encoding="utf-8")
        self.env = dict(os.environ)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(self.env)))
        os.environ["FARCI_ROOT"] = str(self.tmp)
        os.environ.pop("FARCI_CADDY_ADMIN", None)
        for key, value in salle.lire_network_env().items():
            os.environ[key] = value

    def test_noms_et_etudiants_puis_adresse(self):
        erreurs, changements = salle.enregistrer(services, {"equipes": {"3": {
            "nom": "Les Standardistes", "etudiants": ["Alice", " ", "Bob"],
            "briques": {"gateway-litellm": "198.51.100.30"}}}})
        self.assertEqual(erreurs, [])
        self.assertEqual(changements, {"GATEWAY_A_IP": "198.51.100.30"})
        self.assertIn("GATEWAY_A_IP=198.51.100.30", (self.tmp / "config" / "network.env").read_text())
        data = json.loads((self.tmp / "config" / "salle.json").read_text())
        self.assertEqual(data["equipes"]["3"], {"nom": "Les Standardistes", "etudiants": ["Alice", "Bob"]})
        self.assertEqual(salle.noms()["3"], "Les Standardistes")
        self.assertEqual(salle.noms()["2"], "Inférence")   # nom du rôle par défaut

    def test_adresse_refusee_rien_n_est_ecrit(self):
        avant = (self.tmp / "config" / "network.env").read_text()
        erreurs, _ = salle.enregistrer(services, {"equipes": {"3": {
            "nom": "X", "briques": {"gateway-litellm": "10.0.0.5"}}}})
        self.assertTrue(any("hors du réseau" in e for e in erreurs), erreurs)
        self.assertEqual((self.tmp / "config" / "network.env").read_text(), avant)
        self.assertFalse((self.tmp / "config" / "salle.json").exists())
        erreurs, _ = salle.enregistrer(services, {"equipes": {"3": {"briques": {"gateway-litellm": "abc"}}}})
        self.assertTrue(erreurs)
        erreurs, _ = salle.enregistrer(services, {"equipes": {"3": {"briques": {"phoenix": "198.51.100.9"}}}})
        self.assertIn("brique inconnue pour l'équipe 3 : phoenix", erreurs)

    def test_ecriture_en_place(self):
        path = self.tmp / "config" / "network.env"
        inode = path.stat().st_ino
        salle.ecrire_adresses({"GATEWAY_A_IP": "198.51.100.31", "NOUVELLE_IP": "198.51.100.32"})
        texte = path.read_text()
        self.assertEqual(path.stat().st_ino, inode)      # le fichier monté reste celui de l'hôte
        self.assertIn("GATEWAY_A_IP=198.51.100.31", texte)
        self.assertTrue(texte.rstrip().endswith("NOUVELLE_IP=198.51.100.32"))
        self.assertIn("# réseau de test", texte)          # commentaires conservés

    def test_vue_suivi_et_briques_hors_atelier(self):
        os.environ["GATEWAY_A_IP"] = "198.51.100.30"
        room = {"services": [{"id": "gateway-litellm", "team": "up", "served_by": "equipe"}]}
        suivi = salle.Suivi()
        suivi.noter(room, now=100)
        suivi.noter(room, now=200)                       # toujours UP : l'heure ne bouge pas
        v = salle.vue(services, room, suivi, True)
        ids = [b["id"] for e in v["equipes"] for b in e["briques"]]
        self.assertNotIn("inference-omlx", ids)
        self.assertNotIn("flowise", ids)
        equipe3 = next(e for e in v["equipes"] if e["num"] == "3")
        self.assertEqual(equipe3["ip"], "198.51.100.30")
        litellm = next(b for b in equipe3["briques"] if b["id"] == "gateway-litellm")
        self.assertEqual((litellm["equipe"], litellm["servi_par"], litellm["depuis"]), ("up", "equipe", 100))
        suivi.noter({"services": [{"id": "gateway-litellm", "team": "down"}]}, now=300)
        self.assertEqual(suivi.depuis("gateway-litellm"), 300)

    def test_caddyfile_rendu_avec_les_amonts(self):
        os.environ["GATEWAY_A_IP"] = "198.51.100.30"
        texte = salle.caddyfile_rendu(services)
        self.assertNotIn("{$UP_PASSERELLE}", texte)
        self.assertIn("198.51.100.30:4000", texte)
        self.assertIn("admin 0.0.0.0:2019", texte)       # le prochain rechargement reste possible

    def test_relit_les_adresses_du_fichier(self):
        os.environ["GATEWAY_A_IP"] = ""
        salle.ecrire_adresses({"GATEWAY_A_IP": "198.51.100.33"})
        salle.rafraichir_environnement()
        self.assertEqual(os.environ["GATEWAY_A_IP"], "198.51.100.33")


class Page(unittest.TestCase):
    def test_aucune_ressource_externe(self):
        import re
        html = (ROOT / "01-network-dashboard" / "tableau" / "formateur.html").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"""(src|href)=["']https?://""", html))
        self.assertIn('fetch("/tableau/salle"', html)


if __name__ == "__main__":
    unittest.main()
