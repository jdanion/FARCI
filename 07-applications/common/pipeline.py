"""FARCI — pipeline d'extraction complet.

PDF → Docling → pseudonymisation → LLM → Pydantic → JSON
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from .farci_client import chat_completion
from .schemas import ClinicalExtraction


def extract_from_text(
    text: str,
    model: str = "med-extraction",
    prompt_version: str = "v1",
) -> ClinicalExtraction:
    """Extrait les données cliniques d'un texte."""
    prompt_path = Path(__file__).parent / "prompts" / f"extraction_{prompt_version}.md"
    system_prompt = prompt_path.read_text(encoding="utf-8")

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text},
    ]

    response = chat_completion(messages, model=model)

    # Parser et valider
    data = json.loads(response)
    return ClinicalExtraction(**data)


def process_pdf(
    pdf_path: Path,
    output_dir: Path,
    model: str = "med-extraction",
    prompt_version: str = "v1",
) -> Path:
    """Traite un PDF et écrit le JSON de sortie."""
    # Lire le PDF (via Docling ou directement)
    text = pdf_path.read_text(encoding="utf-8", errors="ignore")

    # Extraire
    extraction = extract_from_text(text, model=model, prompt_version=prompt_version)

    # Écrire le JSON
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{pdf_path.stem}.json"
    output_path.write_text(
        extraction.model_dump_json(indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    return output_path


def main():
    import argparse

    parser = argparse.ArgumentParser(description="FARCI — pipeline d'extraction")
    parser.add_argument("input", type=Path, help="PDF ou dossier")
    parser.add_argument("--output", type=Path, default=Path("datasets/extracted"))
    parser.add_argument("--model", default="med-extraction")
    parser.add_argument("--prompt", default="v1")
    args = parser.parse_args()

    if args.input.is_dir():
        for pdf in args.input.glob("*.pdf"):
            output = process_pdf(pdf, args.output, args.model, args.prompt)
            print(f"OK {output}")
    else:
        output = process_pdf(args.input, args.output, args.model, args.prompt)
        print(f"OK {output}")


if __name__ == "__main__":
    main()
