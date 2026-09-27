"""FARCI — schémas Pydantic pour l'extraction clinique (FARCI §28).

Ce schéma est la source de vérité. Il doit être identique à :
- datasets/schemas/clinical_extraction.schema.json
- Le template Flowise
- Le prompt LLM
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class ClinicalExtraction(BaseModel):
    """Schéma d'extraction clinique."""

    patient_id: str = Field(description="IPP du patient, repris du pseudonyme")
    age: int = Field(description="Âge en années", ge=0, le=120)
    sex: str = Field(description="Sexe", pattern="^(M|F)$")
    diagnosis: str = Field(description="Diagnostic principal")
    procedure_type: str = Field(
        description="Type d'intervention",
        pattern="^(DPC|Duodénopancréatectomie|Whipple modifié)$",
    )
    approach: str = Field(
        description="Voie d'abord",
        pattern="^(cœlioscopie|laparotomie|cœlioscopie convertie)$",
    )
    venous_resection: bool = Field(description="Résection veineuse associée")
    tumor_size_mm: Optional[float] = Field(
        default=None, description="Taille de la tumeur en mm", ge=0
    )
    histology: str = Field(description="Type histologique")
    pT: Optional[str] = Field(
        default=None, description="Classification pT", pattern="^(pT1|pT2|pT3|pT4)$"
    )
    pN: Optional[str] = Field(
        default=None, description="Classification pN", pattern="^(pN0|pN1|pN2)$"
    )
    nodes_examined: Optional[int] = Field(
        default=None, description="Nombre de ganglions examinés", ge=0
    )
    nodes_positive: Optional[int] = Field(
        default=None, description="Nombre de ganglions envahis", ge=0
    )
    margin_R: Optional[str] = Field(
        default=None, description="Marge d'exérèse", pattern="^(R0|R1|R2)$"
    )
    pancreatic_fistula: bool = Field(description="Fistule pancréatique")
    delayed_gastrojejunostomy: bool = Field(description="DGE")
    hemorrhage: bool = Field(description="Hémorragie post-opératoire")
    length_of_stay: int = Field(description="Durée de séjour en jours", ge=0)
    readmission: bool = Field(description="Réadmission à 30 jours")
