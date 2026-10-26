#!/usr/bin/env python3
"""FARCI — accès au registre des services (config/services.yaml).

Point d'entrée unique pour tout ce qui a besoin de savoir « quels services
existent et où les joindre » : le tableau de progression, le diagnostic, et plus
tard Caddy, l'agrégateur de santé et les sondes Uptime Kuma.

Le registre ne contient AUCUNE adresse IP : il référence le NOM des variables
d'environnement (ip_var / port_var). Les adresses vivent dans
config/network.env. C'est ce qui rend FARCI §4 respectable : changer de réseau
ne demande qu'une édition de config/network.env.

Commandes :
  list                 tableau lisible de tous les services
  groups               groupe -> nombre de services
  get <id>             détail d'un service (JSON)
  url <id> [chemin]    URL de base d'un service, ou URL complète
  health <id>          liste des chemins de santé candidats
  critical             ids des services indispensables (pipeline "ready")
  pipeline             état du pipeline ; lit {"id": "UP"|"DOWN"...} en JSON sur stdin
  status-rows          lignes du tableau de progression (§49) : label, tier, ids
  validate             cohérence interne du registre (tier, groupes, lignes)
  reference-url <id>   URL du même service sur la pile de référence (REFERENCE_IP)
  upstreams            variables UP_* des routes de l'accueil (lit config/rescue.env)
  routes               noms des routes de l'accueil (pour ./bin/farci rescue)
  room [--json]        sonde la salle : équipes, référence, pipeline
  check-network        cohérence services.yaml <-> config/network.env
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

from miniyaml import MiniYamlError, load  # noqa: E402

REGISTRY = os.path.join(
    os.environ.get("FARCI_ROOT", os.getcwd()), "config", "services.yaml"
)


def registry() -> dict:
    try:
        data = load(REGISTRY)
    except (OSError, MiniYamlError) as exc:
        print(f"registre des services illisible : {exc}", file=sys.stderr)
        raise SystemExit(1)
    if not isinstance(data, dict) or not data.get("services"):
        print(f"{REGISTRY} ne contient aucune liste 'services'", file=sys.stderr)
        raise SystemExit(1)
    return data


def services() -> list[dict]:
    return [s for s in registry().get("services", []) if isinstance(s, dict)]


def by_id(service_id: str) -> dict | None:
    for service in services():
        if service.get("id") == service_id:
            return service
    return None


def base_url(service: dict) -> str | None:
    """http://<ip>:<port>, résolu depuis l'environnement."""
    ip_var, port_var = service.get("ip_var"), service.get("port_var")
    ip = os.environ.get(ip_var or "", "")
    port = os.environ.get(port_var or "", "")
    if not ip or not port:
        return None
    return f"http://{ip}:{port}"


def reference_url(service: dict) -> str | None:
    """Le même service sur la pile de référence, ou None s'il n'y en a pas."""
    port_var = service.get("reference_port_var")
    ip = os.environ.get("REFERENCE_IP", "")
    port = os.environ.get(str(port_var or ""), "")
    if not port_var or not ip or not port:
        return None
    return f"http://{ip}:{port}"


def host_port(url: str | None) -> str | None:
    return url.removeprefix("http://") if url else None


def _route_list(key: str, relative_path: str) -> set[str]:
    """Liste de routes « a,b » lue dans un fichier d'état (KEY=a,b) ou l'environnement."""
    raw = os.environ.get(key, "")
    path = os.path.join(os.environ.get("FARCI_ROOT", os.getcwd()), relative_path)
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith(f"{key}="):
                    raw = line.split("=", 1)[1].strip()
    return {name.strip() for name in raw.split(",") if name.strip()}


def rescued_routes() -> set[str]:
    """Routes servies par la référence seule : bascule du formateur
    (config/rescue.env) ou panne du runtime/passerelle d'équipe simulée par
    le chaos (.chaos/routes.env)."""
    return _route_list("FARCI_RESCUE", "config/rescue.env") | _route_list(
        "FARCI_CHAOS_EXCLUDE", ".chaos/routes.env")


def blocked_routes() -> set[str]:
    """Routes coupées entièrement à l'accueil par un scénario de chaos."""
    return _route_list("FARCI_CHAOS_BLOCK", ".chaos/routes.env")


def upstreams() -> dict[str, str]:
    """Variables UP_* pour Caddy : « hôte:port hôte:port … » dans l'ordre
    d'essai. Une route sans aucun amont reçoit une adresse qui refuse la
    connexion (Caddy répond alors 502 au lieu de refuser de démarrer)."""
    rescued, blocked = rescued_routes(), blocked_routes()
    result = {}
    for route in registry().get("routes", []):
        if route["name"] in blocked:
            result[str(route["var"])] = "127.0.0.1:9"  # panne simulée : personne ne répond
            continue
        hosts: list[str] = []
        if route["name"] not in rescued:
            for sid in route.get("services", []):
                service = by_id(sid)
                address = host_port(base_url(service)) if service else None
                if address and address not in hosts:
                    hosts.append(address)
        reference = by_id(str(route.get("reference", "")))
        address = host_port(reference_url(reference)) if reference else None
        if address and address not in hosts:
            hosts.append(address)
        result[str(route["var"])] = " ".join(hosts) or "127.0.0.1:9"
    return result


def network_prefix(cidr: str) -> tuple[str, int]:
    """Réseau et nombre d'octets significatifs d'un CIDR.

    '192.168.50.0/24' -> ('192.168.50', 3)
    '10.0.0.0/8'      -> ('10', 1)

    Comparer « adresse commence par le réseau + point » serait faux : sur un
    /24, l'adresse réseau est 192.168.50.0 alors que les hôtes sont
    192.168.50.X — aucun hôte ne commence par « 192.168.50.0. ».
    """
    address, _, bits = cidr.partition("/")
    octets = address.split(".")
    try:
        mask_bits = int(bits) if bits else 32
    except ValueError:
        mask_bits = 32
    significant = max(1, min(4, -(-mask_bits // 8)))  # arrondi supérieur
    return ".".join(octets[:significant]), mask_bits


def cmd_list() -> int:
    rows = services()
    width = max((len(str(s.get("label", ""))) for s in rows), default=10)
    ipw = max((len(str(s.get("ip_var", ""))) for s in rows), default=3)
    vpw = max((len(os.environ.get(str(s.get("ip_var", "")), "") or "-") for s in rows), default=3)
    print(f"{'ID':<22} {'SERVICE':<{width}}  {'VARIABLE':<{ipw}}  {'ADRESSE':<{vpw}}  GROUPE")
    for service in rows:
        ip_var = str(service.get("ip_var", "?"))
        resolved = os.environ.get(ip_var, "") or "non définie"
        print(
            f"{str(service.get('id', '')):<22} {str(service.get('label', '')):<{width}}  "
            f"{ip_var:<{ipw}}  {resolved:<{vpw}}  {service.get('group', '')}"
        )
    print()
    print(f"{len(rows)} services, {len(registry().get('groups', {}))} groupes, "
          f"{sum(1 for s in rows if s.get('tier') == 'core')} cœur, "
          f"{sum(1 for s in rows if s.get('critical'))} critiques + 1 runtime")
    return 0


def cmd_groups() -> int:
    groups = registry().get("groups", {})
    counts: dict[str, int] = {key: 0 for key in groups}
    for service in services():
        key = str(service.get("group", ""))
        counts[key] = counts.get(key, 0) + 1
    for key, label in groups.items():
        print(f"{key:<22} {counts.get(key, 0):>2}  {label}")
    return 0


def cmd_get(service_id: str) -> int:
    service = by_id(service_id)
    if service is None:
        print(f"service inconnu : {service_id}", file=sys.stderr)
        return 1
    enriched = dict(service)
    enriched["base_url"] = base_url(service)
    print(json.dumps(enriched, indent=2, ensure_ascii=False))
    return 0


def cmd_url(service_id: str, path: str = "") -> int:
    service = by_id(service_id)
    if service is None:
        print(f"service inconnu : {service_id}", file=sys.stderr)
        return 1
    base = base_url(service)
    if base is None:
        missing = service.get("ip_var") if not os.environ.get(str(service.get("ip_var"))) else service.get("port_var")
        print(f"adresse non résolue pour {service_id} (variable {missing} absente)", file=sys.stderr)
        return 1
    print(f"{base}{path}")
    return 0


def cmd_health(service_id: str) -> int:
    service = by_id(service_id)
    if service is None:
        return 1
    for path in service.get("health_paths") or []:
        print(path)
    return 0


def cmd_critical() -> int:
    for service in services():
        if service.get("critical"):
            print(service["id"])
    return 0


TIERS = ("core", "bonus")


# Libellé d'un critical_group sur le tableau (« Un runtime », « Une passerelle »).
GROUP_NAMES = {"runtime": "Un runtime", "passerelle": "Une passerelle"}


def pipeline_state(states: dict[str, bool]) -> dict:
    """Règle unique de CLINICAL PIPELINE READY (tableau ET health-aggregator).

    states : id de service -> True s'il répond. Renvoie
      {"state": "READY" | "DEGRADED" | "NOT READY",
       "missing": [ce qui manque, dans l'ordre de montage conseillé],
       "met": n, "required": m,
       "exigences": [{"nom": libellé lisible, "ok": bool}, ...]}  (tableau de la salle)
    Un service `critical: true` est une exigence ; un `critical_group` est UNE
    exigence satisfaite dès qu'un de ses membres répond.
    """
    # Exigences dans l'ordre du registre, qui est l'ordre de montage conseillé.
    members_of: dict[str, list[str]] = {}
    for service in services():
        if service.get("critical_group"):
            members_of.setdefault(str(service["critical_group"]), []).append(str(service["id"]))
    requirements: list[tuple[str, list[str]]] = []
    names: dict[str, str] = {}
    for service in services():
        group = service.get("critical_group")
        if service.get("critical") is True:
            requirements.append((str(service["id"]), [str(service["id"])]))
            names[str(service["id"])] = str(service.get("label") or service["id"])
        elif group and not any(label.startswith(f"1 {group} ") for label, _ in requirements):
            members = members_of[str(group)]
            label = f"1 {group} ({' | '.join(members)})"
            requirements.append((label, members))
            names[label] = GROUP_NAMES.get(str(group), f"Un {group}")

    missing = [label for label, members in requirements
               if not any(states.get(m, False) for m in members)]
    met = len(requirements) - len(missing)
    if not missing:
        state = "READY"
    elif met:
        state = "DEGRADED"
    else:
        state = "NOT READY"
    return {"state": state, "missing": missing, "met": met, "required": len(requirements),
            "exigences": [{"nom": names[label], "ok": label not in missing} for label, _ in requirements]}


def probe(url: str | None, paths: list, timeout: float) -> str:
    """'up' au premier chemin qui répond 200, 'down' sinon, 'unknown' sans URL.
    Les services de l'atelier sont sur le réseau local : aucun proxy."""
    if not url:
        return "unknown"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for path in paths or ["/"]:
        try:
            with opener.open(url + path, timeout=timeout) as response:
                if response.status == 200:
                    return "up"
        except (urllib.error.URLError, OSError, ValueError):
            continue
    return "down"


def room_state(timeout: float = 3.0, with_probe: bool = True) -> dict:
    """État de la salle : chaque service d'équipe, sa doublure de référence,
    et le pipeline vu des ÉQUIPES et vu du SERVICE RENDU (équipe ou référence).
    Utilisé par ./bin/farci status ET par le health-aggregator."""
    rows = services()
    # Ce que l'ACCUEIL fait de chaque brique : la servir normalement, la
    # sauter au profit de la référence (rescue, chaos « exclude »), ou couper
    # toute la route (chaos « block »). Le tableau montre ce qui est servi,
    # pas seulement ce qui répond.
    rescued, blocked = rescued_routes(), blocked_routes()
    route_of = {sid: str(route["name"]) for route in registry().get("routes", [])
                for sid in route.get("services", [])}

    def check(service: dict) -> dict:
        paths = service.get("health_paths") or []
        route = route_of.get(service["id"])
        switch = "coupee" if route in blocked else ("reference" if route in rescued else "normal")
        team = probe(base_url(service), paths, timeout) if with_probe else "unknown"
        reference = None
        if service.get("reference_port_var") and with_probe and (team != "up" or switch == "reference"):
            reference = probe(reference_url(service), paths, timeout)
        if switch == "coupee":
            served = None
        elif team == "up" and switch == "normal":
            served = "equipe"
        else:
            served = "reference" if reference == "up" else None
        return {
            "id": service["id"], "label": service.get("label"), "tier": service.get("tier"),
            "critical": service.get("critical") is True, "team": team,
            "reference": reference, "aiguillage": switch, "served_by": served,
        }

    started = time.monotonic()
    with ThreadPoolExecutor(max_workers=max(1, len(rows))) as pool:
        results = list(pool.map(check, rows))
    team_up = {r["id"]: r["served_by"] == "equipe" for r in results}
    served = {r["id"]: r["served_by"] is not None for r in results}
    return {
        "services": results,
        "pipeline": pipeline_state(team_up),
        "service_rendu": pipeline_state(served),
        "rescue": sorted(_route_list("FARCI_RESCUE", "config/rescue.env")),
        "chaos": {"exclues": sorted(_route_list("FARCI_CHAOS_EXCLUDE", ".chaos/routes.env")),
                  "coupees": sorted(blocked_routes())},
        "duree_s": round(time.monotonic() - started, 2),
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def cmd_pipeline() -> int:
    raw = json.load(sys.stdin)
    states = {key: str(value).upper().startswith("UP") for key, value in raw.items()}
    print(json.dumps(pipeline_state(states), ensure_ascii=False))
    return 0


def row_members(row: dict, members: list[dict]) -> list[dict]:
    """Les états qui font la couleur d'une ligne du tableau. Ligne
    `une_parmi` : la meilleure de ses briques (équipe, puis référence) ;
    sinon toutes. Même règle dans health-aggregator/tableau.py."""
    if row.get("une_parmi") and members:
        rank = {"equipe": 0, "reference": 1}
        return [min(members, key=lambda s: rank.get(s.get("served_by") or "", 2))]
    return members


def validate_registry() -> list[str]:
    """Erreurs de cohérence du registre (vide = cohérent)."""
    problems = []
    ids = {str(s.get("id")) for s in services()}
    for service in services():
        sid = service.get("id")
        if service.get("tier") not in TIERS:
            problems.append(f"{sid} : tier {service.get('tier')!r} (attendu : {', '.join(TIERS)})")
        if service.get("critical") not in (True, False):
            problems.append(f"{sid} : critical doit valoir true ou false")
        if service.get("critical") is True and service.get("tier") != "core":
            problems.append(f"{sid} : un service critique doit être de tier core")
    for row in registry().get("status_rows", []):
        if row.get("tier") not in TIERS:
            problems.append(f"ligne {row.get('label')!r} : tier {row.get('tier')!r}")
        for sid in row.get("check", []):
            if sid not in ids:
                problems.append(f"ligne {row.get('label')!r} : service inconnu {sid}")
    return problems


def cmd_validate() -> int:
    problems = validate_registry()
    for problem in problems:
        print(f"KO   {problem}", file=sys.stderr)
    if problems:
        return 1
    print(f"registre cohérent : {len(services())} services, "
          f"{sum(1 for s in services() if s.get('tier') == 'core')} cœur")
    return 0


def cmd_reference_url(service_id: str) -> int:
    service = by_id(service_id)
    url = reference_url(service) if service else None
    if url is None:
        return 1
    print(url)
    return 0


def cmd_upstreams() -> int:
    for key, value in upstreams().items():
        print(f"{key}={value}")
    return 0


def cmd_routes() -> int:
    rescued = _route_list("FARCI_RESCUE", "config/rescue.env")
    chaos, blocked = _route_list("FARCI_CHAOS_EXCLUDE", ".chaos/routes.env"), blocked_routes()
    for route in registry().get("routes", []):
        name = route["name"]
        if name in blocked:
            state = "coupée (chaos)"
        elif name in rescued:
            state = "référence forcée"
        elif name in chaos:
            state = "équipe coupée (chaos)"
        else:
            state = "équipe puis référence"
        print(f"{route['name']}\t{state}")
    return 0


def cmd_room(as_json: bool) -> int:
    state = room_state(float(os.environ.get("FARCI_HEALTH_TIMEOUT", "3")))
    print(json.dumps(state, ensure_ascii=False, indent=2 if as_json else None))
    return 0


def cmd_ids() -> int:
    for service in services():
        print(service["id"])
    return 0


def cmd_status_rows() -> int:
    for row in registry().get("status_rows", []):
        print(f"{row.get('label','')}\t{row.get('tier', 'core')}\t{','.join(row.get('check', []))}")
    return 0


def cmd_check_network() -> int:
    """Vérifie que chaque ip_var du registre est définie et cohérente."""
    subnet = os.environ.get("FARCI_SUBNET", "")
    prefix, mask_bits = network_prefix(subnet) if subnet else ("", 32)
    failures = 0
    # Une place réseau = (adresse, port). Deux services peuvent partager une
    # adresse s'ils n'écoutent pas sur le même port ; en revanche deux services
    # sur le même couple (ip, port) ne peuvent pas coexister.
    seen: dict[tuple[str, str], str] = {}

    reference = os.environ.get("REFERENCE_IP", "")
    octets = reference.split(".")
    if len(octets) != 4 or not all(o.isdigit() and 0 <= int(o) <= 255 for o in octets):
        print(f"KO   REFERENCE_IP={reference!r} : adresse du Pi (accueil + référence) invalide ou absente")
        failures += 1

    # La référence héberge toutes les briques cœur sur une seule machine :
    # deux services ne peuvent donc jamais partager un port publié.
    port_vars = {str(s.get("port_var")) for s in services()} | {
        str(s.get("reference_port_var")) for s in services() if s.get("reference_port_var")
    } | {"ENTRY_PORT"}
    owners: dict[str, list[str]] = {}
    for var in sorted(port_vars):
        value = os.environ.get(var, "")
        if value:
            owners.setdefault(value, []).append(var)
    for value, names in owners.items():
        distinct = sorted(set(names))
        if len(distinct) > 1:
            print(f"KO   port {value} partagé par {', '.join(distinct)} : un port par service")
            failures += 1

    for service in services():
        ip_var = str(service.get("ip_var", ""))
        port_var = str(service.get("port_var", ""))
        if not ip_var:
            print(f"KO   {service.get('id')}: aucun ip_var déclaré")
            failures += 1
            continue
        if not port_var:
            print(f"KO   {service.get('id')}: aucun port_var déclaré")
            failures += 1
        ip = os.environ.get(ip_var, "")
        if not ip:
            # Brique pas encore montée : la référence la sert. Ce n'est pas une erreur.
            continue
        port = os.environ.get(port_var, "")
        if not port:
            print(f"KO   {service.get('id')}: variable {port_var} non définie")
            failures += 1
            continue
        # Le masque est-il cohérent avec ce que la configuration déclare ?
        octets = ip.split(".")
        if len(octets) != 4 or not all(o.isdigit() and 0 <= int(o) <= 255 for o in octets):
            print(f"KO   {service.get('id')}: {ip} n'est pas une adresse IPv4 valide")
            failures += 1
            continue
        if prefix and ".".join(octets[: len(prefix.split("."))]) != prefix:
            print(f"KO   {service.get('id')}: {ip} hors du réseau {subnet}")
            failures += 1
            continue
        host = int(octets[-1])
        if not 1 <= host <= 254:
            print(f"KO   {service.get('id')}: {ip} n'est pas une adresse d'hôte "
                  f"(.0 est l'adresse du réseau, .255 la diffusion)")
            failures += 1
            continue
        if not port.isdigit() or not 1 <= int(port) <= 65535:
            print(f"KO   {service.get('id')}: port {port} invalide")
            failures += 1
            continue
        key = (ip, port)
        if key in seen:
            print(
                f"KO   {service.get('id')}: {ip}:{port} est déjà occupé par "
                f"{seen[key]} — deux services ne peuvent pas écouter sur le même couple"
            )
            failures += 1
            continue
        seen[key] = str(service.get("id"))
    if failures:
        print(f"\n{failures} problème(s) d'adressage.")
        print("Corriger config/network.env (et non services.yaml : le registre ne")
        print("contient que des NOMS de variables, jamais des adresses).")
        return 1
    print(f"OK   référence {reference}, {len(seen)} brique(s) d'équipe déclarée(s) "
          f"dans {subnet}, un port par service.")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 64
    command, args = argv[1], argv[2:]
    if command == "list":
        return cmd_list()
    if command == "groups":
        return cmd_groups()
    if command == "get" and args:
        return cmd_get(args[0])
    if command == "url" and args:
        return cmd_url(args[0], args[1] if len(args) > 1 else "")
    if command == "health" and args:
        return cmd_health(args[0])
    if command == "critical":
        return cmd_critical()
    if command == "ids":
        return cmd_ids()
    if command == "reference-url" and args:
        return cmd_reference_url(args[0])
    if command == "upstreams":
        return cmd_upstreams()
    if command == "routes":
        return cmd_routes()
    if command == "room":
        return cmd_room("--json" in args)
    if command == "pipeline":
        return cmd_pipeline()
    if command == "validate":
        return cmd_validate()
    if command == "status-rows":
        return cmd_status_rows()
    if command == "check-network":
        return cmd_check_network()
    print(f"commande inconnue : {command}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
