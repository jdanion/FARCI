"""La radio du Pi : salle ou Internet, et le retour seul en salle.

./bin/farci wifi est joué avec de faux nmcli, ss, pgrep et systemd-run : aucun
réseau n'est touché. Le faux nmcli tient l'état de la radio dans un fichier."""

from __future__ import annotations

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

from _paths import ROOT

SCRIPT = ROOT / "scripts" / "cmd" / "wifi.sh"

NMCLI = r"""#!/usr/bin/env bash
echo "$*" >> "$FAKE/appels"
case "$*" in
  "-g GENERAL.CONNECTION dev show wlan0") cat "$FAKE/actif" ;;
  "-t -f NAME,TYPE con show") printf 'farci-ap:802-11-wireless\n'; sed 's/$/:802-11-wireless/' "$FAKE/profils" ;;
  "-t -f NAME con show") echo farci-ap; cat "$FAKE/profils" ;;
  "con up "*) args="$*"; name="${args#con up }"; grep -qxF "$name" "$FAKE/injoignables" && exit 4; echo "$name" > "$FAKE/actif" ;;
esac
"""
SS = '#!/usr/bin/env bash\ncat "$FAKE/ssh" 2>/dev/null\n'
IP = '#!/usr/bin/env bash\necho "3: wlan0    inet 198.51.100.1/24 brd 198.51.100.255 scope global wlan0"\n'
PGREP = '#!/usr/bin/env bash\n[[ -e "$FAKE/telechargement" ]]\n'
SYSTEMD_RUN = '#!/usr/bin/env bash\necho "systemd-run $*" >> "$FAKE/appels"\n'
SYSTEMCTL = '#!/usr/bin/env bash\nexit 0\n'


class Radio(unittest.TestCase):
    def setUp(self):
        self.fake = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.fake)
        for name, body in (("nmcli", NMCLI), ("ss", SS), ("ip", IP), ("pgrep", PGREP),
                           ("systemd-run", SYSTEMD_RUN), ("systemctl", SYSTEMCTL), ("sudo", '#!/usr/bin/env bash\nexec "$@"\n')):
            path = self.fake / name
            path.write_text(body, encoding="utf-8")
            path.chmod(path.stat().st_mode | stat.S_IEXEC)
        for name, content in (("actif", "farci-ap\n"), ("profils", "maison\n"), ("injoignables", ""), ("appels", "")):
            (self.fake / name).write_text(content, encoding="utf-8")

    def wifi(self, *args: str, timeout: int = 20) -> subprocess.CompletedProcess:
        env = {k: v for k, v in os.environ.items() if not k.startswith("FARCI_")}
        env.update(PATH=f"{self.fake}:{env['PATH']}", FAKE=str(self.fake), NO_COLOR="1", FARCI_SKIP_ENV="1",
                   FARCI_WIFI_DELAI="2", FARCI_WIFI_PAS="1")
        return subprocess.run([str(SCRIPT), *args], env=env, capture_output=True, text=True, timeout=timeout)

    def actif(self) -> str:
        return (self.fake / "actif").read_text(encoding="utf-8").strip()

    def test_sans_ssh_la_radio_revient_seule_en_salle(self):
        resultat = self.wifi("_bascule", "maison")
        self.assertEqual(resultat.returncode, 0, resultat.stderr)
        self.assertIn("con up maison", (self.fake / "appels").read_text())
        self.assertEqual(self.actif(), "farci-ap")

    def test_une_session_ssh_garde_internet(self):
        (self.fake / "ssh").write_text("0 0 198.51.100.1:22 198.51.100.7:50000\n", encoding="utf-8")
        with self.assertRaises(subprocess.TimeoutExpired):
            self.wifi("_bascule", "maison", timeout=5)
        self.assertEqual(self.actif(), "maison")

    def test_la_session_restee_sur_l_adresse_de_la_salle_ne_compte_pas(self):
        # La session qui a lancé la bascule : son adresse locale n'existe plus.
        (self.fake / "ssh").write_text("0 0 192.0.2.1:22 192.0.2.7:50000\n", encoding="utf-8")
        self.wifi("_bascule", "maison")
        self.assertEqual(self.actif(), "farci-ap")

    def test_un_telechargement_garde_internet(self):
        (self.fake / "telechargement").touch()
        with self.assertRaises(subprocess.TimeoutExpired):
            self.wifi("_bascule", "maison", timeout=5)
        self.assertEqual(self.actif(), "maison")

    def test_un_wifi_injoignable_ramene_en_salle_tout_de_suite(self):
        (self.fake / "injoignables").write_text("maison\n", encoding="utf-8")
        (self.fake / "actif").write_text("\n", encoding="utf-8")
        resultat = self.wifi("_bascule", "maison", timeout=5)
        self.assertEqual(self.actif(), "farci-ap")
        self.assertIn("injoignable", resultat.stderr)

    def test_la_bascule_est_detachee_de_la_session_ssh(self):
        resultat = self.wifi("internet")
        self.assertEqual(resultat.returncode, 0, resultat.stderr)
        self.assertIn("systemd-run", (self.fake / "appels").read_text())
        self.assertIn("_bascule maison", (self.fake / "appels").read_text())
        self.assertEqual(self.actif(), "farci-ap")  # rien n'a encore basculé dans cette session
        self.assertIn("recrée seul le Wi-Fi de la salle", resultat.stdout)

    def test_plusieurs_wifi_il_faut_choisir(self):
        (self.fake / "profils").write_text("maison\nbureau\n", encoding="utf-8")
        resultat = self.wifi("internet")
        self.assertEqual(resultat.returncode, 64)
        self.assertIn("wifi internet bureau", resultat.stderr)


if __name__ == "__main__":
    unittest.main()
