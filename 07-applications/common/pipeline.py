"""FARCI — pipeline d'extraction, un dossier patient à la fois.

    documents .txt du patient (datasets/raw/patient_<IPP>_*.txt)
        │  concaténés : CRO, anapath, scanner, lettre de sortie
        ▼
    pseudonymisation (04-clinical-documents/deidentification)
        ▼
    passerelle LLM via Caddy (alias med-extraction, API OpenAI)
        ▼
    validation Pydantic (ClinicalExtraction)  ── échec : RIEN n'est écrit
        ▼
    datasets/extracted/<run>/patient_<IPP>.json   (+ _meta : latence, modèle, prompt)

Le dataset versionné est en texte (.txt) : c'est le parcours assumé de
l'atelier. Les PDF (./bin/farci generate-dataset --pdf) servent à la
démonstration Docling, pas au pipeline noté.
"""

from __future__ import annotations

import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "04-clinical-documents"))

from deidentification import MappingStore, pseudonymize_text  # noqa: E402

from .schemas import ClinicalExtraction  # noqa: E402

PROMPTS_DIR = Path(__file__).parent / "prompts"
DOCUMENT_ORDER = ("cro", "crap", "crscan", "lettre")
FILE_RE = re.compile(r"^patient_(?P<key>\d+)_(?P<kind>[a-z]+)\.txt$")

Completion = Callable[[list, str], str]


class ExtractionRejected(Exception):
    """La sortie du modèle n'est pas un JSON conforme : on refuse d'écrire."""


def patient_documents(raw_dir: Path) -> dict[str, list[Path]]:
    """IPP -> documents texte du patient, dans l'ordre clinique."""
    grouped: dict[str, list[Path]] = {}
    for path in sorted(raw_dir.glob("patient_*.txt")):
        match = FILE_RE.match(path.name)
        if match:
            grouped.setdefault(match["key"], []).append(path)
    rank = {kind: i for i, kind in enumerate(DOCUMENT_ORDER)}
    for paths in grouped.values():
        paths.sort(key=lambda p: rank.get(FILE_RE.match(p.name)["kind"], 99))
    return grouped


def build_dossier(paths: list[Path], mapping: MappingStore) -> str:
    """Concatène puis pseudonymise les documents d'un patient."""
    text = "\n\n---\n\n".join(p.read_text(encoding="utf-8") for p in paths)
    return pseudonymize_text(text, mapping)


def render_prompt(prompt_version: str) -> str:
    template = (PROMPTS_DIR / f"extraction_{prompt_version}.md").read_text(encoding="utf-8")
    # Le document part dans le message utilisateur : le prompt système ne
    # contient que les règles et le schéma.
    return template.replace("{{text}}", "(le dossier est dans le message suivant)")


def parse_json(raw: str) -> dict:
    """Extrait l'objet JSON de la réponse (tolère un bloc ```json)."""
    text = raw.strip()
    fenced = re.search(r"```(?:json)?\s*(.*?)```", text, flags=re.DOTALL)
    if fenced:
        text = fenced.group(1).strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ExtractionRejected(f"JSON illisible : {exc}") from exc
    if not isinstance(data, dict):
        raise ExtractionRejected("la réponse n'est pas un objet JSON")
    return data


def extract_dossier(
    text: str,
    complete: Completion,
    model: str = "med-extraction",
    prompt_version: str = "v1",
    pseudonym: str | None = None,
) -> ClinicalExtraction:
    messages = [
        {"role": "system", "content": render_prompt(prompt_version)},
        {"role": "user", "content": text},
    ]
    data = parse_json(complete(messages, model))
    if pseudonym:
        # La clé du dossier est connue du pipeline, pas devinée par le modèle.
        data["patient_id"] = pseudonym
    try:
        return ClinicalExtraction(**data)
    except Exception as exc:  # pydantic.ValidationError
        raise ExtractionRejected(f"non conforme au schéma : {exc}") from exc


def write_extraction(extraction: ClinicalExtraction, output_dir: Path, key: str, meta: dict) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    data = extraction.model_dump()
    data["_meta"] = meta
    path = output_dir / f"patient_{key}.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def run(
    raw_dir: Path,
    output_dir: Path,
    complete: Completion,
    model: str = "med-extraction",
    prompt_version: str = "v1",
    only: set[str] | None = None,
    log: Callable[[str], None] = print,
) -> dict:
    """Traite tous les dossiers ; renvoie le bilan {écrits, rejetés, erreurs}."""
    mapping = MappingStore()
    summary = {"ecrits": 0, "rejetes": 0, "erreurs": 0}
    for key, paths in patient_documents(raw_dir).items():
        if only is not None and key not in only:
            continue
        text = build_dossier(paths, mapping)
        pseudonym = next((k for k, v in mapping.to_dict().items()
                          if k.startswith("IPP_") and v == key), None)
        started = time.monotonic()
        try:
            extraction = extract_dossier(text, complete, model, prompt_version, pseudonym)
        except ExtractionRejected as exc:
            summary["rejetes"] += 1
            log(f"REJET  patient_{key} : {exc}")
            continue
        except Exception as exc:  # réseau, passerelle, quota...
            summary["erreurs"] += 1
            log(f"ERREUR patient_{key} : {type(exc).__name__} : {exc}")
            continue
        meta = {
            "latency_s": round(time.monotonic() - started, 3),
            "model": model,
            "prompt": prompt_version,
            "documents": [p.name for p in paths],
            "date": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }
        path = write_extraction(extraction, output_dir, key, meta)
        summary["ecrits"] += 1
        log(f"OK     {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")
    return summary
