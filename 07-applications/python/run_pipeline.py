#!/usr/bin/env python3
"""FARCI — parcours A (Python) : extraire tout le dataset en une commande.

Usage :
    ./bin/farci extract                          20 dossiers, run « python »
    ./bin/farci extract --subset quick           10 dossiers (jeu rapide)
    ./bin/farci extract --run equipe-3 --prompt v2
    ./bin/farci extract --replay                 plan C : runtime rejoué local, sans réseau

La passerelle est lue dans FARCI_GATEWAY_URL (dérivée de config/network.env).
Le résultat est évalué par : ./bin/farci evaluate
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "07-applications"))
sys.path.insert(0, str(ROOT / "datasets" / "tools"))


def main() -> int:
    parser = argparse.ArgumentParser(description="FARCI — pipeline d'extraction (parcours Python)")
    parser.add_argument("--input", type=Path, default=ROOT / "datasets" / "raw")
    parser.add_argument("--run", default="python", help="nom de la run : datasets/extracted/<run>/")
    parser.add_argument("--output", type=Path, default=None, help="dossier de sortie (prioritaire sur --run)")
    parser.add_argument("--model", default="med-extraction")
    parser.add_argument("--prompt", default="v1", choices=["v1", "v2"])
    parser.add_argument("--subset", choices=["full", "quick"], default="full")
    parser.add_argument("--limit", type=int, default=None, help="n premiers dossiers seulement")
    parser.add_argument("--replay", action="store_true",
                        help="plan C : runtime rejoué dans ce processus, sans réseau ni modèle")
    args = parser.parse_args()

    if args.replay:
        # Plan C : ni accueil, ni passerelle, ni modèle. Le runtime rejoué
        # tourne dans ce processus ; le reste du pipeline est inchangé.
        import os
        import threading

        sys.path.insert(0, str(ROOT / "reference" / "replay"))
        import server

        httpd = server.make_server(0, delay=0, host="127.0.0.1")
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        os.environ["FARCI_GATEWAY_URL"] = f"http://127.0.0.1:{httpd.server_address[1]}/v1"
        os.environ.setdefault("FARCI_TRACE", "off")
        os.environ["no_proxy"] = os.environ["NO_PROXY"] = "127.0.0.1"
        print("mode rejoué (plan C) : réponses enregistrées, aucun modèle\n")

    # Imports après l'analyse des arguments : --help fonctionne sans pydantic
    # ni openai (machine pas encore équipée, runner de CI).
    from common.farci_client import chat_completion
    from common.pipeline import run

    only = None
    if args.subset == "quick":
        from cases import quick_set

        only = {case.patient_id for case in quick_set()}
    if args.limit:
        from common.pipeline import patient_documents

        keys = [k for k in sorted(patient_documents(args.input)) if only is None or k in only]
        only = set(keys[: args.limit])

    output = args.output or ROOT / "datasets" / "extracted" / args.run
    summary = run(
        args.input,
        output,
        complete=lambda messages, model: chat_completion(messages, model=model),
        model=args.model,
        prompt_version=args.prompt,
        only=only,
    )
    print(
        f"\n{summary['ecrits']} dossier(s) écrit(s), {summary['rejetes']} rejeté(s) "
        f"par la validation, {summary['erreurs']} erreur(s) d'appel"
    )
    if summary["ecrits"] == 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
