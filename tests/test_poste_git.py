"""Le parcours git de l'étudiant : cloner, créer sa branche, écrire sa fiche.

./bin/farci poste est joué dans un clone temporaire, face à une « forge » nue
dont le chemin a la forme de celle de la salle (…/FARCI/farci.git). Aucun
réseau, aucun Docker."""

from __future__ import annotations

import base64
import http.server
import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path

from _paths import ROOT

IGNORE = shutil.ignore_patterns(".git", ".venv", "offline", "vendor", "__pycache__", "postes")


@unittest.skipUnless(shutil.which("git"), "git absent")
class ParcoursEtudiant(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.forge = self.tmp / "FARCI" / "farci.git"
        self.clone = self.tmp / "farci"
        source = self.tmp / "source"
        shutil.copytree(ROOT, source, ignore=IGNORE, symlinks=True)
        for name in (".env", "config/network.env", "config/workshop.env", "config/salle.json"):
            (source / name).unlink(missing_ok=True)
        self.git("init", "-q", "-b", "main", cwd=source)
        self.git("add", "-A", cwd=source)
        self.git("commit", "-qm", "projet", cwd=source)
        self.git("init", "-q", "--bare", "-b", "main", str(self.forge), cwd=self.tmp)
        self.git("push", "-q", str(self.forge), "main:main", "main:seance", cwd=source)
        self.git("clone", "-q", str(self.forge), str(self.clone), cwd=self.tmp)

    def git(self, *args: str, cwd: Path | None = None) -> str:
        env = {**os.environ, "GIT_AUTHOR_NAME": "equipe-2", "GIT_AUTHOR_EMAIL": "equipe-2@farci.local",
               "GIT_COMMITTER_NAME": "equipe-2", "GIT_COMMITTER_EMAIL": "equipe-2@farci.local",
               "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull}
        return subprocess.run(["git", *args], cwd=cwd or self.clone, env=env, check=True,
                              capture_output=True, text=True).stdout

    def farci(self, *args: str, **extra: str) -> subprocess.CompletedProcess:
        env = {k: v for k, v in os.environ.items() if not k.startswith(("FARCI_", "GITEA_"))}
        env.update(NO_COLOR="1", FARCI_SUITE="0", GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, **extra)
        return subprocess.run([str(self.clone / "bin" / "farci"), *args], cwd=self.clone, env=env,
                              capture_output=True, text=True)

    def identite(self):
        self.git("config", "user.name", "equipe-2")
        self.git("config", "user.email", "equipe-2@farci.local")

    def test_chaque_etat_donne_la_commande_git_suivante(self):
        self.assertIn("git config user.name", self.farci("poste").stdout)
        self.identite()
        self.assertIn("git switch -c poste/equipe-", self.farci("poste").stdout)

        self.git("switch", "-qc", "poste/equipe-2-atlas")
        self.assertIn("./bin/farci poste nouveau", self.farci("poste").stdout)
        ecrit = self.farci("poste", "nouveau", FARCI_GROSSE_RAM_GO="100000")
        self.assertEqual(ecrit.returncode, 0, ecrit.stderr)
        fiche = (self.clone / "postes" / "equipe-2-atlas.env").read_text(encoding="utf-8")
        self.assertIn("FARCI_EQUIPE=2", fiche)
        self.assertIn("git commit", ecrit.stdout)

        self.git("add", "postes")
        self.git("commit", "-qm", "poste: atlas")
        etat = self.farci("poste").stdout
        self.assertIn("forge Gitea de la salle", etat)
        self.assertIn("git push -u origin poste/equipe-2-atlas", etat)

        self.git("push", "-q", "-u", "origin", "poste/equipe-2-atlas")
        etat = self.farci("poste").stdout
        self.assertIn("Pull Request", etat)
        self.assertIn("compare/seance...poste/equipe-2-atlas", etat)

    def test_la_fiche_s_ecrit_sur_sa_branche_pas_sur_main(self):
        self.identite()
        refus = self.farci("poste", "nouveau")
        self.assertNotEqual(refus.returncode, 0)
        self.assertIn("git switch -c", refus.stdout)
        self.assertFalse((self.clone / "postes").exists())

    def test_changer_de_branche_change_la_configuration(self):
        self.identite()
        self.git("switch", "-qc", "poste/equipe-2-atlas")
        self.farci("poste", "nouveau")
        fiche = self.clone / "postes" / "equipe-2-atlas.env"
        fiche.write_text(fiche.read_text(encoding="utf-8").replace("FARCI_TRACK=python", "FARCI_TRACK=webui"),
                         encoding="utf-8")
        self.git("add", "postes")
        self.git("commit", "-qm", "poste: atlas")
        self.assertIn("FARCI_TRACK=webui", self.farci("env").stdout)
        self.git("switch", "-q", "main")
        self.assertNotIn("FARCI_TRACK=webui", self.farci("env").stdout)

    def fausse_forge(self, mot_de_passe: str) -> str:
        """Une forge de théâtre : /api/healthz, /api/v1/user (compte equipe-2) et le partage du Pi."""
        attendu = "Basic " + base64.b64encode(f"equipe-2:{mot_de_passe}".encode()).decode()

        class Forge(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/api/healthz":
                    code, corps = 200, b"{}"
                elif self.path == "/api/v1/user":
                    code = 200 if self.headers.get("Authorization") == attendu else 401
                    corps = b"{}"
                elif self.path == "/partage/forge.json":
                    code, corps = 200, json.dumps({"mot_de_passe": mot_de_passe}).encode()
                else:
                    code, corps = 404, b""
                self.send_response(code)
                self.end_headers()
                self.wfile.write(corps)

            def log_message(self, *args):
                pass

        serveur = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Forge)
        threading.Thread(target=serveur.serve_forever, daemon=True).start()
        self.addCleanup(serveur.server_close)
        self.addCleanup(serveur.shutdown)
        return f"http://127.0.0.1:{serveur.server_address[1]}"

    def test_poste_salle_branche_le_clone_sur_la_forge_sans_rien_saisir(self):
        forge = self.fausse_forge("mot de passe/de la salle")
        self.git("switch", "-qc", "poste/equipe-2-atlas")
        resultat = self.farci("poste", "salle", GITEA_URL=forge, FARCI_ENTRY_URL=forge)
        self.assertEqual(resultat.returncode, 0, resultat.stderr)
        self.assertEqual(self.git("remote", "get-url", "salle").strip(), f"{forge}/FARCI/farci.git")
        self.assertEqual(self.git("config", "user.name").strip(), "equipe-2")
        compte = (self.clone / ".git" / "farci-forge-credentials").read_text(encoding="utf-8")
        self.assertIn("equipe-2:mot%20de%20passe%2Fde%20la%20salle@127.0.0.1", compte)
        self.assertIn("git push -u salle poste/equipe-2-atlas", resultat.stdout)
        self.assertNotIn("mot de passe/de la salle", resultat.stdout)  # jamais affiché

    def test_poste_salle_refuse_un_mauvais_mot_de_passe_et_une_forge_absente(self):
        forge = self.fausse_forge("le-bon")
        self.git("switch", "-qc", "poste/equipe-2-atlas")
        refus = self.farci("poste", "salle", GITEA_URL=forge, FARCI_SALLE_MOT_DE_PASSE="le-mauvais")
        self.assertNotEqual(refus.returncode, 0)
        self.assertIn("refuse le compte equipe-2", refus.stderr)
        absente = self.farci("poste", "salle", GITEA_URL="http://127.0.0.1:9", FARCI_SALLE_MOT_DE_PASSE="x")
        self.assertIn("Wi-Fi de la salle", absente.stderr)
        self.assertNotIn("salle", self.git("remote"))

    def test_une_fiche_ne_contient_ni_secret_ni_cle_inconnue(self):
        postes = self.clone / "postes"
        postes.mkdir()
        (postes / "equipe-3-bon.env").write_text("FARCI_EQUIPE=3\nPOSTE_RAM_GO=16\n", encoding="utf-8")
        self.assertEqual(self.farci("poste", "verifier").returncode, 0)
        (postes / "equipe-3-fuite.env").write_text("FARCI_EQUIPE=3\nLITELLM_MASTER_KEY=sk-x\n", encoding="utf-8")
        (postes / "equipe-4-faux.env").write_text("FARCI_EQUIPE=5\nGITEA_IP=198.51.100.9\n", encoding="utf-8")
        mauvais = self.farci("poste", "verifier")
        self.assertNotEqual(mauvais.returncode, 0)
        self.assertIn("LITELLM_MASTER_KEY ressemble à un secret", mauvais.stderr)
        self.assertIn("GITEA_IP inconnu", mauvais.stderr)
        self.assertIn("ne correspond pas au nom du fichier", mauvais.stderr)


if __name__ == "__main__":
    unittest.main()
