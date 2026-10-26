"""FARCI — l'onglet formateur du tableau : qui est dans quelle équipe, et où.

Le formateur saisit, depuis le navigateur (/tableau/formateur) :
  - le nom de chaque équipe et ses étudiants   -> config/salle.json
  - l'adresse IP de la machine de chaque brique -> config/network.env
puis l'accueil de la salle (Caddy) est rechargé par son API d'administration
(réseau Docker seulement). C'est exactement ce que fait `./bin/farci room set`
en ligne de commande : même fichier, mêmes règles (services.cmd_check_network).

Le suivi, lui, existe déjà : l'agrégateur sonde chaque adresse toutes les
TABLEAU_TICK secondes (app.board_loop). Ce module garde seulement, pour
chaque brique, depuis quand elle est UP ou DOWN.

Stdlib seulement.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

from tableau import TEAMS

IP_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
MAX_NOM, MAX_ETUDIANTS = 40, 12


def root() -> Path:
    return Path(os.environ.get("FARCI_ROOT", Path(__file__).resolve().parents[2]))


def salle_path() -> Path:
    return root() / "config" / "salle.json"


def network_env_path() -> Path:
    return root() / "config" / "network.env"


# --- Noms et étudiants (config/salle.json) ---------------------------------

def charger() -> dict:
    try:
        data = json.loads(salle_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    equipes = data.get("equipes") if isinstance(data.get("equipes"), dict) else {}
    return {"equipes": {num: _equipe_propre(equipes.get(num, {})) for num in TEAMS}}


def _equipe_propre(raw: object) -> dict:
    raw = raw if isinstance(raw, dict) else {}
    nom = str(raw.get("nom", "")).strip()[:MAX_NOM]
    etudiants = raw.get("etudiants", [])
    if isinstance(etudiants, str):
        etudiants = re.split(r"[,\n]", etudiants)
    etudiants = [str(e).strip()[:MAX_NOM] for e in etudiants if str(e).strip()][:MAX_ETUDIANTS]
    return {"nom": nom, "etudiants": etudiants}


def noms() -> dict[str, str]:
    """Nom affiché de chaque équipe : celui du formateur, sinon celui du rôle."""
    equipes = charger()["equipes"]
    return {num: equipes[num]["nom"] or TEAMS[num] for num in TEAMS}


def _ecrire_proprement(path: Path, texte: str) -> None:
    """Écrit EN PLACE (même inode : le fichier monté reste celui de l'hôte) et
    donne au fichier le propriétaire de config/network.env (pas root)."""
    existe = path.exists()
    with open(path, "r+" if existe else "w", encoding="utf-8") as handle:
        handle.seek(0)
        handle.write(texte)
        handle.truncate()
    if not existe:
        with contextlib.suppress(OSError):
            ref = network_env_path().stat()
            os.chown(path, ref.st_uid, ref.st_gid)


# --- Adresses (config/network.env) ------------------------------------------

def lire_network_env() -> dict[str, str]:
    values: dict[str, str] = {}
    with contextlib.suppress(OSError):
        for line in network_env_path().read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def rafraichir_environnement() -> None:
    """L'environnement du conteneur est figé à sa création : on relit les
    adresses du fichier (modifié depuis par room set ou par ce module)."""
    for key, value in lire_network_env().items():
        if key.endswith("_IP") or key == "FARCI_SUBNET":
            os.environ[key] = value


def ecrire_adresses(changements: dict[str, str]) -> None:
    path = network_env_path()
    lignes = path.read_text(encoding="utf-8").splitlines()
    restants = dict(changements)
    for i, line in enumerate(lignes):
        key = line.partition("=")[0].strip()
        if key in restants and not line.lstrip().startswith("#"):
            lignes[i] = f"{key}={restants.pop(key)}"
    lignes += [f"{key}={value}" for key, value in restants.items()]
    _ecrire_proprement(path, "\n".join(lignes) + "\n")


def verifier_adresses(registry, changements: dict[str, str]) -> list[str]:
    """Les règles de room set (services.cmd_check_network), sur l'état futur."""
    erreurs = []
    for var, ip in changements.items():
        if ip and not IP_RE.match(ip):
            erreurs.append(f"{var} : « {ip} » n'est pas une adresse IPv4")
    if erreurs:
        return erreurs
    avant = {var: os.environ.get(var) for var in changements}
    os.environ.update(changements)
    sortie = io.StringIO()
    try:
        with contextlib.redirect_stdout(sortie):
            failures = registry.cmd_check_network()
    finally:
        for var, value in avant.items():
            if value is None:
                os.environ.pop(var, None)
            else:
                os.environ[var] = value
    if failures:
        erreurs = [line.removeprefix("KO").strip() for line in sortie.getvalue().splitlines()
                   if line.startswith("KO")]
    return erreurs


# --- Rechargement de l'accueil (Caddy) --------------------------------------

def caddyfile_rendu(registry) -> str:
    """Le Caddyfile de l'accueil, variables UP_* remplacées par les amonts
    calculés à partir des adresses actuelles (comme `up reference`)."""
    texte = (root() / "01-network-dashboard" / "caddy" / "Caddyfile").read_text(encoding="utf-8")
    for var, value in registry.upstreams().items():
        texte = texte.replace("{$" + var + "}", value)
    return texte


def recharger_caddy(registry) -> tuple[bool, str]:
    admin = os.environ.get("FARCI_CADDY_ADMIN", "")
    if not admin:
        return False, "FARCI_CADDY_ADMIN absent : ./bin/farci up reference caddy pour appliquer"
    request = urllib.request.Request(f"{admin.rstrip('/')}/load", data=caddyfile_rendu(registry).encode(),
                                     headers={"Content-Type": "text/caddyfile"}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status == 200, "accueil rechargé"
    except urllib.error.HTTPError as exc:
        return False, f"Caddy refuse la configuration ({exc.code}) : {exc.read()[:200].decode(errors='replace')}"
    except OSError as exc:
        return False, f"Caddy injoignable ({exc}) : ./bin/farci up reference caddy pour appliquer"


def caddy_a_jour(registry) -> bool | None:
    """Caddy sert-il les amonts attendus ? (il a pu redémarrer avec son
    ancien environnement). None : on ne sait pas."""
    admin = os.environ.get("FARCI_CADDY_ADMIN", "")
    if not admin:
        return None
    try:
        with urllib.request.urlopen(f"{admin.rstrip('/')}/config/", timeout=3) as response:
            config = response.read().decode()
    except OSError:
        return None
    voulus = {h for value in registry.upstreams().values() for h in value.split()}
    return all(f'"{h}"' in config for h in voulus)


# --- Suivi : depuis quand chaque brique est UP / DOWN ------------------------

class Suivi:
    def __init__(self) -> None:
        self.etats: dict[str, tuple[str, float]] = {}

    def noter(self, room: dict, now: float | None = None) -> None:
        now = now if now is not None else time.time()
        for service in room.get("services", []):
            etat = service.get("team") or "unknown"
            if self.etats.get(service["id"], ("", 0.0))[0] != etat:
                self.etats[service["id"]] = (etat, now)

    def depuis(self, sid: str) -> float | None:
        return self.etats.get(sid, ("", None))[1]


# --- Vue et enregistrement ---------------------------------------------------

def vue(registry, room: dict, suivi: Suivi, modifiable: bool, message: str = "") -> dict:
    equipes = charger()["equipes"]
    etats = {s["id"]: s for s in room.get("services", [])}
    # Seulement les briques du tableau : oMLX et Flowise (hors atelier) n'y sont pas.
    au_tableau = {sid for row in registry.registry().get("status_rows", []) for sid in row.get("check", [])}
    resultat = []
    for num, nom_role in TEAMS.items():
        briques = []
        for service in registry.services():
            if str(service.get("team")) != num or service["id"] not in au_tableau:
                continue
            etat = etats.get(service["id"], {})
            briques.append({
                "id": service["id"], "label": service.get("label"), "tier": service.get("tier"),
                "ip_var": service.get("ip_var"), "ip": os.environ.get(str(service.get("ip_var")), ""),
                "port": os.environ.get(str(service.get("port_var")), ""),
                "equipe": etat.get("team", "unknown"), "servi_par": etat.get("served_by"),
                "depuis": suivi.depuis(service["id"]),
            })
        if not briques:
            continue
        coeur = [b["ip"] for b in briques if b["tier"] == "core" and b["ip"]]
        resultat.append({"num": num, "role": nom_role, **equipes[num],
                         "ip": coeur[0] if coeur else next((b["ip"] for b in briques if b["ip"]), ""),
                         "briques": briques})
    return {"equipes": resultat, "modifiable": modifiable, "message": message,
            "reference_ip": os.environ.get("REFERENCE_IP", ""), "reseau": os.environ.get("FARCI_SUBNET", ""),
            "tick": float(os.environ.get("TABLEAU_TICK", "5")), "maintenant": time.time()}


def enregistrer(registry, payload: dict) -> tuple[list[str], dict[str, str]]:
    """Valide puis écrit noms (salle.json) et adresses (network.env).
    Renvoie (erreurs, changements d'adresses appliqués)."""
    entrantes = payload.get("equipes")
    if not isinstance(entrantes, dict):
        return ["corps attendu : {\"equipes\": {\"2\": {\"nom\": …, \"etudiants\": […], \"briques\": {id: ip}}}}"], {}
    par_id = {str(s["id"]): s for s in registry.services()}
    changements: dict[str, str] = {}
    erreurs: list[str] = []
    for num, equipe in entrantes.items():
        if num not in TEAMS or not isinstance(equipe, dict):
            erreurs.append(f"équipe inconnue : {num}")
            continue
        for sid, ip in (equipe.get("briques") or {}).items():
            service = par_id.get(str(sid))
            if not service or str(service.get("team")) != num:
                erreurs.append(f"brique inconnue pour l'équipe {num} : {sid}")
                continue
            ip = str(ip or "").strip()
            var = str(service["ip_var"])
            if ip and not IP_RE.match(ip):
                erreurs.append(f"{service.get('label')} : « {ip} » n'est pas une adresse IPv4")
            elif changements.get(var, ip) != ip:
                erreurs.append(f"{var} reçoit deux adresses différentes")
            elif os.environ.get(var, "") != ip:
                changements[var] = ip
    if not erreurs and changements:
        erreurs = verifier_adresses(registry, changements)
    if erreurs:
        return erreurs, {}

    actuel = charger()["equipes"]
    for num, equipe in entrantes.items():
        if "nom" in equipe or "etudiants" in equipe:
            actuel[num] = _equipe_propre({**actuel[num], **{k: equipe[k] for k in ("nom", "etudiants") if k in equipe}})
    _ecrire_proprement(salle_path(), json.dumps({"equipes": actuel}, ensure_ascii=False, indent=2) + "\n")
    if changements:
        ecrire_adresses(changements)
        os.environ.update(changements)
    return [], changements

