"""« Ensuite : » — la ou les commandes à lancer après chaque commande.

farci_suite (scripts/lib/suite.sh) est appelé comme par bin/farci, avec
FARCI_SUITE=1 pour forcer l'affichage hors terminal. Ni réseau ni Docker."""

from __future__ import annotations

import os
import subprocess
import unittest

from _paths import ROOT


def suite(*args: str, **env: str) -> subprocess.CompletedProcess:
    script = 'source scripts/lib/common.sh; farci_suite "$@"'
    full = {**os.environ, "FARCI_ROOT": str(ROOT), "FARCI_SUITE": "1", "NO_COLOR": "1",
            "FARCI_EQUIPE": "", **env}
    return subprocess.run(["bash", "-c", script, "suite", *args], env=full, cwd=ROOT,
                          capture_output=True, text=True)


class Suggestions(unittest.TestCase):
    def test_la_cle_la_plus_precise_gagne(self):
        out = suite("up", "0", "02-inference/ollama").stderr
        self.assertIn("02-inference/ollama/create-model.sh", out)
        generique = suite("up", "0", "06-evaluation/mlflow").stderr
        self.assertIn("./bin/farci evaluate", generique)          # « up 06-evaluation »
        self.assertIn("./bin/farci logs 06-evaluation/mlflow", generique)

    def test_echec_propose_de_comprendre(self):
        out = suite("up", "1", "02-inference/llamacpp").stderr
        self.assertIn("Pour comprendre et réparer", out)
        self.assertIn("./bin/farci logs 02-inference/llamacpp", out)
        self.assertNotIn("Ensuite :", out)

    def test_equipe_et_valeurs_par_defaut(self):
        self.assertIn("./preload.sh --equipe <équipe>", suite("bootstrap", "0").stderr)
        self.assertIn("./preload.sh --equipe 4", suite("bootstrap", "0", FARCI_EQUIPE="4").stderr)
        self.assertIn("./verify-airgap.sh --equipe 3", suite("preload", "0", "--equipe", "3").stderr)
        self.assertIn("rescue --off <brique>", suite("rescue", "0").stderr)
        self.assertIn("rescue --off inference", suite("rescue", "0", "inference").stderr)

    def test_silencieux_quand_il_le_faut(self):
        self.assertEqual(suite("up", "0", "02-inference/ollama", FARCI_SUITE="0").stderr, "")
        self.assertEqual(suite("status", "0", "--help").stderr, "")
        self.assertEqual(suite("status", "130").stderr, "")          # Ctrl+C
        self.assertEqual(suite("cible-inconnue", "0").stderr, "")

    def test_seulement_sur_la_sortie_d_erreur(self):
        result = suite("status", "0")
        self.assertEqual(result.stdout, "")
        self.assertIn("./bin/farci room", result.stderr)


class Lanceur(unittest.TestCase):
    def run_farci(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        # Lancé par ./bin/farci test-unit, l'environnement porte déjà
        # FARCI_SUITE_PARENT : on repart d'un lanceur « du haut ».
        full = {k: v for k, v in os.environ.items() if k != "FARCI_SUITE_PARENT"}
        full.update({"FARCI_SUITE": "1", "NO_COLOR": "1", **env})
        return subprocess.run([str(ROOT / "bin" / "farci"), *args], env=full, cwd=ROOT,
                              capture_output=True, text=True)

    def test_bin_farci_ajoute_la_suite_et_garde_le_code(self):
        result = self.run_farci("version")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Ensuite :", result.stderr)
        self.assertNotIn("Ensuite :", result.stdout)

    def test_appel_imbrique_silencieux(self):
        result = self.run_farci("version", FARCI_SUITE_PARENT="1")
        self.assertNotIn("Ensuite :", result.stderr)

    def test_registre_coherent(self):
        result = subprocess.run(["python3", str(ROOT / "scripts" / "check_suite.py")],
                                env={**os.environ, "FARCI_ROOT": str(ROOT)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
