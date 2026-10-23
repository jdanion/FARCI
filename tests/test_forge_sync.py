"""Synchronisation GitHub → Gitea : avance rapide seulement, jamais de force.

Trois dépôts git locaux jouent GitHub, Gitea et le poste du formateur :
aucun réseau, aucun Gitea réel. Le script est appelé comme en séance."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

SCRIPT = ROOT / "scripts" / "cmd" / "forge-sync.sh"


def git(cwd: Path, *args: str) -> str:
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    return subprocess.run(["git", *args], cwd=cwd, env=env, check=True,
                          capture_output=True, text=True).stdout.strip()


@unittest.skipUnless(shutil.which("git"), "git absent")
class ForgeSync(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        for name in ("github.git", "gitea.git"):
            git(self.tmp, "init", "-q", "--bare", "-b", "main", name)
        self.dev = self.tmp / "dev"          # celui qui fusionne sur GitHub
        git(self.tmp, "clone", "-q", "github.git", "dev")
        git(self.dev, "checkout", "-q", "-b", "main")
        self.commit(self.dev, "origine")
        self.poste = self.tmp / "poste"      # le poste du formateur (relais)
        git(self.tmp, "clone", "-q", "github.git", "poste")
        git(self.poste, "remote", "add", "gitea", str(self.tmp / "gitea.git"))

    def commit(self, repo: Path, message: str, remote: str = "origin") -> str:
        git(repo, "commit", "-q", "--allow-empty", "-m", message)
        git(repo, "push", "-q", remote, "HEAD:main")
        return git(repo, "rev-parse", "HEAD")

    def sync(self, *args: str) -> subprocess.CompletedProcess:
        env = {**os.environ, "FARCI_SYNC_REPO": str(self.poste), "NO_COLOR": "1"}
        return subprocess.run([str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def gitea_main(self) -> str:
        return git(self.tmp / "gitea.git", "rev-parse", "main")

    def test_gitea_vide_puis_avance_rapide(self):
        self.assertEqual(self.sync("push").returncode, 0)
        newer = self.commit(self.dev, "correctif")
        result = self.sync("push")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.gitea_main(), newer)
        # la branche de séance est créée une fois, puis laissée à la séance
        self.assertNotEqual(git(self.tmp / "gitea.git", "rev-parse", "seance"), newer)

    def test_divergence_refusee_sans_rien_ecraser(self):
        self.sync("push")
        salle = self.tmp / "salle"
        git(self.tmp, "clone", "-q", "gitea.git", "salle")
        local = self.commit(salle, "fusionné sur Gitea pendant la séance")
        self.commit(self.dev, "correctif GitHub")
        result = self.sync("push")
        self.assertEqual(result.returncode, 1)
        self.assertIn("REFUSÉE", result.stdout + result.stderr)
        self.assertEqual(self.gitea_main(), local)
        # rapatrier : la branche Gitea devient une branche locale à proposer sur GitHub
        self.assertEqual(self.sync("rapatrier", "main").returncode, 0)
        self.assertEqual(git(self.poste, "rev-parse", "depuis-gitea/main"), local)

    def test_bundle_pour_la_salle_sans_internet(self):
        newer = self.commit(self.dev, "version du jour J")
        bundle = self.tmp / "main.bundle"
        self.assertEqual(self.sync("bundle", str(bundle)).returncode, 0)
        result = self.sync("from-bundle", str(bundle))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.gitea_main(), newer)


if __name__ == "__main__":
    unittest.main()
