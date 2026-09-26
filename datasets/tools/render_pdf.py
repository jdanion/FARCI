#!/usr/bin/env python3
"""FARCI — rendu des documents synthétiques en PDF.

Utilise fpdf2 (pur Python, aucune dépendance système). Si fpdf2 n'est pas
disponible, génère des fichiers .txt à la place (pour les tests).

Chaque cas produit 4 documents :
  - compte rendu opératoire (CRO)
  - compte rendu anatomopathologique (CRAP)
  - compte rendu scanner (CRSCAN)
  - lettre de sortie (LS)
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from cases import Case

try:
    from fpdf import FPDF
    HAS_FPDF = True
except ImportError:
    HAS_FPDF = False


# --------------------------------------------------------------------------
# Templates de documents
# --------------------------------------------------------------------------

TEMPLATE_CRO = """COMPTE RENDU OPÉRATOIRE

Patient : {prenom} {nom}
IPP : {patient_id}
NIR : {nir}
Date de naissance : {date_naissance}
Âge : {age} ans
Sexe : {sexe}

Diagnostic préopératoire : {diagnosis}

Intervention : {procedure_type}
Voie d'abord : {approach}
Résection veineuse : {venous_resection}

Taille tumorale : {tumor_size_mm} mm
Histologie : {histology}

Complications :
- Fistule pancréatique : {pancreatic_fistula}
- DGE : {delayed_gastrojejunostomy}
- Hémorragie : {hemorrhage}

Durée de séjour : {length_of_stay} jours
Réadmission : {readmission}
"""

TEMPLATE_CRAP = """COMPTE RENDU ANATOMOPATHOLOGIQUE

Patient : {prenom} {nom}
IPP : {patient_id}

Pièce opératoire : {procedure_type}

Résultats :
- pT : {pT}
- pN : {pN}
- Ganglions examinés : {nodes_examined}
- Ganglions envahis : {nodes_positive}
- Marge : {margin_R}
- Histologie : {histology}
- Taille : {tumor_size_mm} mm
"""

TEMPLATE_CRSCAN = """COMPTE RENDU SCANNER

Patient : {prenom} {nom}
IPP : {patient_id}

Indication : {diagnosis}

Résultat :
Tumeur du pancréas de {tumor_size_mm} mm.
{venous_resection_text}

Conclusion : {diagnosis}
"""

TEMPLATE_LETTRE = """LETTRE DE SORTIE

Patient : {prenom} {nom}
IPP : {patient_id}

Intervention : {procedure_type}
Date de sortie : jour {length_of_stay} post-opératoire

Complications :
- Fistule pancréatique : {pancreatic_fistula}
- DGE : {delayed_gastrojejunostomy}
- Hémorragie : {hemorrhage}

Réadmission à 30 jours : {readmission}

Suivi : consultation chirurgicale à 1 mois.
"""


def _format_case(case) -> dict:
    """Formate les valeurs d'un cas pour les templates."""
    return {
        "prenom": case.prenom,
        "nom": case.nom,
        "patient_id": case.patient_id,
        "nir": case.nir,
        "date_naissance": case.date_naissance,
        "age": case.age,
        "sexe": case.sex,
        "diagnosis": case.diagnosis,
        "procedure_type": case.procedure_type,
        "approach": case.approach,
        "venous_resection": "Oui" if case.venous_resection else "Non",
        "venous_resection_text": (
            "Envahissement veineux constaté." if case.venous_resection
            else "Pas d'envahissement veineux."
        ),
        "tumor_size_mm": case.tumor_size_mm if case.tumor_size_mm else "Non précisé",
        "histology": case.histology,
        "pT": case.pT if case.pT else "Non précisé",
        "pN": case.pN if case.pN else "Non précisé",
        "nodes_examined": case.nodes_examined if case.nodes_examined else "Non précisé",
        "nodes_positive": case.nodes_positive if case.nodes_positive is not None else "Non précisé",
        "margin_R": case.margin_R if case.margin_R else "Non précisé",
        "pancreatic_fistula": "Oui" if case.pancreatic_fistula else "Non",
        "delayed_gastrojejunostomy": "Oui" if case.delayed_gastrojejunostomy else "Non",
        "hemorrhage": "Oui" if case.hemorrhage else "Non",
        "length_of_stay": case.length_of_stay,
        "readmission": "Oui" if case.readmission else "Non",
    }


def _render_pdf(text: str, output_path: Path) -> None:
    """Génère un PDF à partir de texte."""
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", size=11)
    pdf.multi_cell(0, 6, text)
    pdf.output(str(output_path))


def _render_txt(text: str, output_path: Path) -> None:
    """Génère un fichier texte (fallback si fpdf2 absent)."""
    output_path.write_text(text, encoding="utf-8")


def render_case_pdfs(case, output_dir: Path) -> list[Path]:
    """Génère les 4 documents d'un cas. Retourne les chemins créés."""
    data = _format_case(case)
    base = f"patient_{case.patient_id}"

    documents = {
        "cro": TEMPLATE_CRO.format(**data),
        "crap": TEMPLATE_CRAP.format(**data),
        "crscan": TEMPLATE_CRSCAN.format(**data),
        "lettre": TEMPLATE_LETTRE.format(**data),
    }

    created = []
    for suffix, text in documents.items():
        if HAS_FPDF:
            path = output_dir / f"{base}_{suffix}.pdf"
            _render_pdf(text, path)
        else:
            path = output_dir / f"{base}_{suffix}.txt"
            _render_txt(text, path)
        created.append(path)

    return created
