#!/usr/bin/env python3
"""FARCI — client du service EDS-NLP (stdlib seulement : rien à installer).

    ./bin/farci eds pseudo   datasets/raw/patient_1234567890123_cro.txt
    ./bin/farci eds pseudo   <fichier> --sans-contexte     ce que les règles seules trouvent
    ./bin/farci eds entites  <fichier>                     pseudonymise, puis le LLM balise
    ./bin/farci eds compare  [--subset quick|full] [--limit N]   entités trouvées contre le gold

Le service est joint par l'accueil de la salle (FARCI_EDS_URL, …/eds) : celui
de l'équipe 4 s'il répond, sinon la doublure du Pi. Le contexte patient (nom,
IPP, NIR…) vient du registre du jeu de données synthétique, comme il
viendrait du dossier informatisé à l'hôpital.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "datasets" / "tools"))

from cases import CASES, get_case, quick_set  # noqa: E402

RAW = ROOT / "datasets" / "raw"
LABELS = ("diagnostic", "intervention", "complication", "stade")


def service_url() -> str:
    url = os.environ.get("FARCI_EDS_URL", "")
    if not url:
        sys.exit("FARCI_EDS_URL absente : REFERENCE_IP dans config/network.env (./bin/farci env)")
    return url.rstrip("/")


def post(path: str, payload: dict, timeout: float = 300) -> dict:
    request = urllib.request.Request(
        service_url() + path, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}, method="POST")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))  # réseau de salle : pas de proxy
    try:
        with opener.open(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        sys.exit(f"EDS-NLP : HTTP {exc.code} — {detail}")
    except (urllib.error.URLError, TimeoutError) as exc:
        sys.exit(f"EDS-NLP injoignable ({service_url()}) : {exc} — ./bin/farci status")


def patient_id(path: Path) -> str | None:
    match = re.match(r"patient_(\d+)_", path.name)
    return match.group(1) if match else None


def context_for(pid: str | None) -> dict[str, list[str]]:
    """Ce que le dossier informatisé sait déjà du patient."""
    case = get_case(pid) if pid else None
    if case is None:
        return {}
    return {"NOM": [case.nom], "PRENOM": [case.prenom], "IPP": [case.patient_id],
            "SECU": [case.nir], "DATE_NAISSANCE": [case.date_naissance],
            "ADRESSE": [case.adresse], "TEL": [case.telephone], "MAIL": [case.email]}


def show_entities(entities: list[dict]) -> None:
    if not entities:
        print("  (aucune entité)")
    for e in entities:
        print(f"  {e['label']:<15} {e['texte']!r}  [{e['debut']}:{e['fin']}]")


def cmd_pseudo(args) -> int:
    path = Path(args.fichier)
    context = {} if args.sans_contexte else context_for(patient_id(path))
    result = post("/v1/pseudonymiser", {"texte": path.read_text(encoding="utf-8"), "contexte": context})
    print(result["texte"])
    print(f"── {len(result['entites'])} identifiant(s) remplacé(s)"
          f"{' (règles seules, sans contexte)' if args.sans_contexte else ''} :")
    show_entities(result["entites"])
    return 0


def cmd_entites(args) -> int:
    path = Path(args.fichier)
    result = post("/v1/entites", {"texte": path.read_text(encoding="utf-8"),
                                  "contexte": context_for(patient_id(path)),
                                  "pseudonymiser": not args.sans_pseudo})
    print(f"── texte envoyé au modèle ({result['modele']}) :")
    print(result["texte_envoye"])
    print("── entités :")
    show_entities(result["entites"])
    return 0


def normalize(text: str) -> str:
    return " ".join(text.lower().split())


def expected(case) -> dict[str, set[str]]:
    """Ce qu'un annotateur devrait baliser, d'après le registre (le gold)."""
    complications = {name for name, flag in (("fistule pancréatique", case.pancreatic_fistula),
                                             ("dge", case.delayed_gastrojejunostomy),
                                             ("hémorragie", case.hemorrhage)) if flag}
    return {
        "diagnostic": {normalize(case.histology), normalize(case.diagnosis)},
        "intervention": {normalize(case.procedure_type)},
        "complication": complications,
        "stade": {normalize(s) for s in (case.pT, case.pN) if s},
    }


def cmd_compare(args) -> int:
    cases = quick_set() if args.subset == "quick" else CASES
    if args.limit:
        cases = cases[: args.limit]
    found = {label: 0 for label in LABELS}
    total = {label: 0 for label in LABELS}
    extra = {label: 0 for label in LABELS}
    for case in cases:
        entities: list[dict] = []
        for path in sorted(RAW.glob(f"patient_{case.patient_id}_*.txt")):
            entities += post("/v1/entites", {"texte": path.read_text(encoding="utf-8"),
                                             "contexte": context_for(case.patient_id)})["entites"]
        got = {label: {normalize(e["texte"]) for e in entities if e["label"] == label} for label in LABELS}
        for label, wanted in expected(case).items():
            total[label] += len(wanted)
            hits = {w for w in wanted if any(w in g for g in got[label])}
            found[label] += len(hits)
            extra[label] += len([g for g in got[label] if not any(w in g for w in wanted)])
        print(f"  patient {case.patient_id} : {len(entities)} entité(s)", file=sys.stderr)
    print(f"\nEDS-NLP contre le gold ({len(cases)} dossiers, sous-ensemble {args.subset})\n")
    print(f"| Entité | Attendues | Retrouvées | Rappel | Balisées en trop |")
    print("|---|---|---|---|---|")
    for label in LABELS:
        recall = f"{found[label] / total[label]:.0%}" if total[label] else "—"
        print(f"| {label} | {total[label]} | {found[label]} | {recall} | {extra[label]} |")
    print("\n« En trop » : balisé sans être attendu. Une complication marquée « Non » "
          "dans le dossier et balisée quand même, c'est une négation manquée.")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="./bin/farci eds", description="Client du service EDS-NLP")
    sub = parser.add_subparsers(dest="commande", required=True)
    p = sub.add_parser("pseudo", help="pseudonymiser un fichier")
    p.add_argument("fichier")
    p.add_argument("--sans-contexte", action="store_true", help="règles seules, sans données du patient")
    p.set_defaults(run=cmd_pseudo)
    p = sub.add_parser("entites", help="extraire les entités d'un fichier (LLM)")
    p.add_argument("fichier")
    p.add_argument("--sans-pseudo", action="store_true", help="envoyer le texte NON pseudonymisé (démonstration)")
    p.set_defaults(run=cmd_entites)
    p = sub.add_parser("compare", help="entités trouvées contre le gold")
    p.add_argument("--subset", choices=["quick", "full"], default="quick")
    p.add_argument("--limit", type=int, default=None,
                   help="n premiers patients (4 documents chacun) : avec un modèle sur processeur, --limit 2")
    p.set_defaults(run=cmd_compare)
    args = parser.parse_args(argv)
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
