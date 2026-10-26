"""Préchargement par poste : la brique de l'équipe, selon la machine.

Les fonctions shell (scripts/lib/machine.sh, poste_groups, farci_images poste)
sont appelées comme par preload.sh, sans réseau ni Docker."""

from __future__ import annotations

import os
import subprocess
import sys
import unittest

from _paths import ROOT

sys.path.insert(0, str(ROOT / "casting"))
from casting import Student  # noqa: E402
from roles import get_role  # noqa: E402


def bash(script: str, **env: str) -> str:
    full = {**os.environ, "FARCI_ROOT": str(ROOT), **env}
    return subprocess.run(["bash", "-c", script], env=full, check=True,
                          capture_output=True, text=True, cwd=ROOT).stdout.split()


def groupes(equipe: str, profil: str) -> list[str]:
    return bash(f'source scripts/preload_lib.sh >/dev/null; poste_groups {equipe} {profil}')


def images(equipe: str, profil: str) -> list[str]:
    return bash(f'source scripts/dev-env.sh; farci_load_versions; source scripts/lib/images.sh; '
                f'farci_images poste {equipe} {profil}')


class Profil(unittest.TestCase):
    def test_force_par_farci_machine(self):
        for profil in ("grosse", "legere"):
            self.assertEqual(bash("source scripts/lib/machine.sh; farci_machine", FARCI_MACHINE=profil), [profil])

    def test_seuil_de_ram(self):
        self.assertEqual(bash("source scripts/lib/machine.sh; farci_machine", FARCI_GROSSE_RAM_GO="1",
                              PATH="/usr/bin:/bin"), ["grosse"])
        self.assertEqual(bash("source scripts/lib/machine.sh; farci_machine", FARCI_GROSSE_RAM_GO="100000",
                              PATH="/usr/bin:/bin"), ["legere"])


class Brique(unittest.TestCase):
    def test_inference_selon_la_machine(self):
        self.assertIn("inference_ollama", groupes("2", "grosse"))
        self.assertIn("models_ornith", groupes("2", "grosse"))
        legere = groupes("2", "legere")
        self.assertEqual(legere, ["build_llamacpp", "models_ci"])
        self.assertTrue(any("llamacpp" in i for i in images("2", "legere")))
        self.assertFalse(any("ollama" in i for i in images("2", "legere")))

    def test_langfuse_reserve_aux_grosses_configurations(self):
        self.assertEqual(groupes("5", "legere"), ["observability_phoenix"])
        self.assertTrue(any("langfuse" in i for i in images("5", "grosse")))

    def test_jamais_plus_de_deux_stacks_ni_hors_atelier(self):
        for equipe in map(str, range(9)):
            for profil in ("grosse", "legere"):
                g = groupes(equipe, profil)
                self.assertNotIn("models_qwen38", g)
                self.assertFalse(any("flowise" in i for i in images(equipe, profil)))

    def test_equipe_inconnue(self):
        with self.assertRaises(subprocess.CalledProcessError):
            groupes("9", "legere")


class Casting(unittest.TestCase):
    def test_ollama_exige_une_grosse_configuration(self):
        ollama = next(o for o in get_role("inference").options if o.name == "ollama")
        self.assertFalse(Student("léger", ram_gb=16).can_run(ollama))
        self.assertTrue(Student("gpu", ram_gb=16, has_gpu=True, vram_gb=8).can_run(ollama))
        self.assertTrue(Student("ram", ram_gb=32).can_run(ollama))

    def test_deux_options_au_plus_par_brique(self):
        from roles import ROLES
        for role in ROLES:
            self.assertLessEqual(len(role.options), 2, role.name)


if __name__ == "__main__":
    unittest.main()
