"""Rejoindre la salle sans rien : ce que le Pi publie (./bin/farci partage maj).

Le script est appelé comme sur le Pi, avec un FARCI_DATA_DIR temporaire et
une adresse de salle fictive : aucun réseau, aucun Docker."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

SCRIPT = ROOT / "scripts" / "cmd" / "partage.sh"


@unittest.skipUnless(shutil.which("git") and (ROOT / ".git").exists(), "git ou dépôt absent")
class Publication(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = Path(tempfile.mkdtemp())
        env = {**os.environ, "FARCI_DATA_DIR": str(cls.data), "NO_COLOR": "1",
               "REFERENCE_IP": "198.51.100.1", "INFERENCE_A_IP": "198.51.100.20"}
        cls.result = subprocess.run([str(SCRIPT), "maj"], env=env, capture_output=True, text=True)
        cls.share = cls.data / "partage"

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.data)

    def test_depot_clonable_en_http_simple(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr)
        refs = (self.share / "farci.git" / "info" / "refs").read_text()
        self.assertIn("refs/heads/main", refs)  # git update-server-info
        clone = self.data / "clone"
        subprocess.run(["git", "clone", "-q", str(self.share / "farci.git"), str(clone)], check=True)
        self.assertTrue((clone / "bin" / "farci").exists())

    def test_archives_dans_un_dossier_farci(self):
        with tarfile.open(self.share / "farci.tar.gz") as tar:
            self.assertIn("farci/bin/farci", tar.getnames())
        self.assertTrue((self.share / "farci.zip").stat().st_size > 0)
        self.assertIn("version :", (self.share / "VERSION.txt").read_text())

    def test_network_env_etudiant_sans_ip_d_equipe(self):
        lines = (self.share / "network.env").read_text().splitlines()
        ips = {line.split("=", 1)[0]: line.split("=", 1)[1] for line in lines if re.match(r"^[A-Z0-9_]+_IP=", line)}
        self.assertIn("REFERENCE_IP", ips)
        self.assertTrue(all(v == "" for k, v in ips.items() if k != "REFERENCE_IP"), ips)
        self.assertIn("http://198.51.100.1/rejoindre", self.result.stdout)


class PageRejoindre(unittest.TestCase):
    def test_aucune_ressource_externe(self):
        html = (ROOT / "01-network-dashboard" / "tableau" / "rejoindre.html").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"""(src|href)=["']https?://""", html))
        self.assertIn("/farci.git", html)
        self.assertIn("FARCI_WHEELS_URL=", html)


if __name__ == "__main__":
    unittest.main()
