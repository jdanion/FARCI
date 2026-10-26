"""FARCI — la page « Extraction » du tableau : le travail de l'étape 2, sur
des exemples concrets du jeu rapide.

Pour un dossier : les documents bruts, ce que reçoit vraiment le modèle
(pseudonymisé), la consigne (prompts v1 / v2), la réponse attendue (gold),
les extractions déjà faites sur cette machine (datasets/extracted/<run>/),
et une extraction EN DIRECT par l'accueil de la salle (/v1, l'équipe 3 ou la
référence), comparée champ par champ au gold.

Mêmes briques que le parcours Python, sans dépendance : la pseudonymisation
de l'équipe 4 (04-clinical-documents/deidentification), les prompts de
07-applications/common/prompts, la comparaison de 06-evaluation/metrics.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(os.environ.get("FARCI_ROOT", Path(__file__).resolve().parents[2]))
for sub in ("04-clinical-documents", "06-evaluation/metrics", "datasets/tools"):
    if str(ROOT / sub) not in sys.path:
        sys.path.insert(0, str(ROOT / sub))

from deidentification import MappingStore, pseudonymize_text  # noqa: E402
from metrics import SCORED_FIELDS, compare_field  # noqa: E402

RAW = ROOT / "datasets" / "raw"
GOLD = ROOT / "datasets" / "gold"
EXTRACTED = ROOT / "datasets" / "extracted"
PROMPTS = ROOT / "07-applications" / "common" / "prompts"
DOCUMENTS = (("cro", "Compte rendu opératoire"), ("crap", "Anatomopathologie"),
             ("crscan", "Scanner"), ("lettre", "Lettre de sortie"))
IPP_RE = re.compile(r"^\d{13}$")
TIMEOUT = float(os.environ.get("FARCI_EXTRACTION_TIMEOUT", "180"))


def cas_rapides() -> list[str]:
    """Les 10 dossiers du jeu rapide (datasets/tools/cases.py : quick_set)."""
    try:
        from cases import quick_set
        ids = [c.patient_id for c in quick_set()]
    except Exception:  # registre absent : les premiers gold
        ids = sorted(p.stem.removeprefix("patient_") for p in GOLD.glob("patient_*.json"))[:10]
    return [i for i in ids if (GOLD / f"patient_{i}.json").is_file()]


def _gold(ipp: str) -> dict:
    data = json.loads((GOLD / f"patient_{ipp}.json").read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def _documents(ipp: str) -> list[dict]:
    docs = []
    for kind, titre in DOCUMENTS:
        path = RAW / f"patient_{ipp}_{kind}.txt"
        if path.is_file():
            docs.append({"type": kind, "titre": titre, "texte": path.read_text(encoding="utf-8")})
    return docs


def _dossier(docs: list[dict]) -> tuple[str, str | None]:
    """Comme le pipeline : documents concaténés puis pseudonymisés.
    Renvoie (texte, pseudonyme de l'IPP)."""
    mapping = MappingStore()
    texte = pseudonymize_text("\n\n---\n\n".join(d["texte"] for d in docs), mapping)
    ipp_tag = next((k for k in mapping.to_dict() if k.startswith("IPP_")), None)
    return texte, ipp_tag


def prompt(version: str) -> str:
    template = (PROMPTS / f"extraction_{version}.md").read_text(encoding="utf-8")
    return template.replace("{{text}}", "(le dossier est dans le message suivant)")


def _runs(ipp: str) -> list[dict]:
    runs = []
    for path in sorted(EXTRACTED.glob(f"*/patient_{ipp}.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        meta = data.pop("_meta", {}) if isinstance(data, dict) else {}
        runs.append({"run": path.parent.name, "meta": meta, "comparaison": comparer(_gold(ipp), data)})
    return runs


def liste() -> list[dict]:
    resultat = []
    for ipp in cas_rapides():
        gold = _gold(ipp)
        resultat.append({"ipp": ipp, "resume": f"{gold.get('age', '?')} ans · {gold.get('procedure_type', '')}",
                         "documents": len(_documents(ipp))})
    return resultat


def exemple(ipp: str) -> dict | None:
    if not IPP_RE.match(ipp) or not (GOLD / f"patient_{ipp}.json").is_file():
        return None
    docs = _documents(ipp)
    dossier, tag = _dossier(docs)
    return {"ipp": ipp, "documents": docs, "dossier": dossier, "pseudonyme": tag, "gold": _gold(ipp),
            "prompts": {v: prompt(v) for v in ("v1", "v2") if (PROMPTS / f"extraction_{v}.md").is_file()},
            "runs": _runs(ipp), "champs": SCORED_FIELDS}


def comparer(gold: dict, extrait: dict) -> dict:
    lignes = []
    for champ in SCORED_FIELDS:
        r = compare_field(champ, gold.get(champ), extrait.get(champ) if isinstance(extrait, dict) else None)
        lignes.append({"champ": champ, "attendu": r["gold"], "extrait": r["predicted"],
                       "resultat": r["outcome"], "juste": r["correct"]})
    justes = sum(1 for ligne in lignes if ligne["juste"])
    return {"lignes": lignes, "justes": justes, "total": len(lignes)}


def _json_de(texte: str) -> dict | None:
    texte = texte.strip()
    bloc = re.search(r"```(?:json)?\s*(.*?)```", texte, flags=re.DOTALL)
    if bloc:
        texte = bloc.group(1).strip()
    try:
        data = json.loads(texte)
    except ValueError:
        debut, fin = texte.find("{"), texte.rfind("}")
        if debut < 0 or fin <= debut:
            return None
        try:
            data = json.loads(texte[debut:fin + 1])
        except ValueError:
            return None
    return data if isinstance(data, dict) else None


def extraire(ipp: str, version: str) -> tuple[int, dict]:
    """Une extraction en direct par l'accueil de la salle (/v1)."""
    ex = exemple(ipp)
    if ex is None:
        return 404, {"ok": False, "erreur": f"dossier inconnu : {ipp}"}
    if version not in ex["prompts"]:
        return 400, {"ok": False, "erreur": f"prompt inconnu : {version}"}
    url = os.environ.get("FARCI_EXTRACTION_URL", "").rstrip("/")
    if not url:
        return 503, {"ok": False, "erreur": "FARCI_EXTRACTION_URL absente (compose de l'accueil)"}
    corps = {"model": "med-extraction", "temperature": 0, "max_tokens": 1200,
             "messages": [{"role": "system", "content": ex["prompts"][version]},
                          {"role": "user", "content": ex["dossier"]}]}
    entetes = {"Content-Type": "application/json"}
    if os.environ.get("FARCI_API_KEY"):
        entetes["Authorization"] = f"Bearer {os.environ['FARCI_API_KEY']}"
    debut = time.monotonic()
    requete = urllib.request.Request(f"{url}/chat/completions", data=json.dumps(corps).encode(), headers=entetes)
    try:
        with urllib.request.urlopen(requete, timeout=TIMEOUT) as reponse:
            data = json.loads(reponse.read())
    except urllib.error.HTTPError as exc:
        return 502, {"ok": False, "erreur": f"la passerelle répond {exc.code} : "
                                            f"{exc.read()[:300].decode(errors='replace')}"}
    except (OSError, ValueError) as exc:
        return 502, {"ok": False, "erreur": f"passerelle injoignable : {exc}"}
    duree = round(time.monotonic() - debut, 2)
    brut = (((data.get("choices") or [{}])[0].get("message") or {}).get("content")) or ""
    extrait = _json_de(brut)
    if extrait is None:
        return 200, {"ok": False, "brut": brut, "duree": duree, "modele": data.get("model"),
                     "erreur": "la réponse n'est pas un JSON : le pipeline la REJETTERAIT (rien n'est écrit)"}
    return 200, {"ok": True, "brut": brut, "extrait": extrait, "duree": duree, "modele": data.get("model"),
                 "comparaison": comparer(ex["gold"], extrait)}
