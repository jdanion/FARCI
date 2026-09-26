#!/usr/bin/env python3
"""FARCI — registre des cas synthétiques (source de vérité).

Ce module est la SEULE source de vérité pour le dataset. Les PDF sont rendus
à partir de ces données, et le gold standard est écrit directement depuis ce
registre — jamais via un LLM (FARCI §27).

Toutes les valeurs sont cohérentes : un pT3 avec ganglions envahis a une
taille de tumeur cohérente avec l'aspect scanographique, une fistule
pancreatique allonge le séjour, etc. Ce n'est pas du bruit aléatoire.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Optional

# --------------------------------------------------------------------------
# Registre des 20 cas
# --------------------------------------------------------------------------

@dataclass
class Case:
    """Un cas patient synthétique."""
    patient_id: str          # IPP factice (format: 1234567890123)
    nir: str                 # NIR factice (format: 1 23 45 6789 0123 456 78)
    age: int
    sex: str                 # "M" ou "F"
    diagnosis: str
    procedure_type: str      # "DPC", "Duodénopancréatectomie", "Whipple modifié"
    approach: str            # "cœlioscopie", "laparotomie", "cœlioscopie convertie"
    venous_resection: bool
    tumor_size_mm: Optional[float]
    histology: str           # "adénocarcinome canalaire", "TNE", "IPMN transformé"
    pT: Optional[str]        # "pT1", "pT2", "pT3", "pT4", None
    pN: Optional[str]        # "pN0", "pN1", "pN2", None
    nodes_examined: Optional[int]
    nodes_positive: Optional[int]
    margin_R: Optional[str]  # "R0", "R1", "R2", None
    pancreatic_fistula: bool
    delayed_gastrojejunostomy: bool
    hemorrhage: bool
    length_of_stay: int      # en jours
    readmission: bool
    # Quasi-identifiants (pour pseudonymisation)
    date_naissance: str      # "JJ/MM/AAAA"
    adresse: str
    telephone: str
    email: str
    # Métadonnées
    prenom: str
    nom: str


# Liste des 20 cas synthétiques
CASES: list[Case] = [
    Case(
        patient_id="1234567890123", nir="1 23 45 6789 0123 456 78",
        age=67, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=28.0,
        histology="adénocarcinome canalaire",
        pT="pT3", pN="pN1",
        nodes_examined=24, nodes_positive=3,
        margin_R="R0",
        pancreatic_fistula=True, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=14, readmission=False,
        date_naissance="15/03/1958",
        adresse="12 rue des Lilas, 69003 Lyon",
        telephone="06 12 34 56 78",
        email="jean.dupont@exemple.fr",
        prenom="Jean", nom="Dupont",
    ),
    Case(
        patient_id="1234567890124", nir="2 24 46 6789 0123 456 79",
        age=72, sex="F",
        diagnosis="TNE grade 2 du pancréas",
        procedure_type="Duodénopancréatectomie", approach="laparotomie",
        venous_resection=False,
        tumor_size_mm=15.0,
        histology="TNE grade 2",
        pT="pT2", pN="pN0",
        nodes_examined=18, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=9, readmission=False,
        date_naissance="22/07/1953",
        adresse="45 avenue Berthelot, 69007 Lyon",
        telephone="06 23 45 67 89",
        email="marie.martin@exemple.fr",
        prenom="Marie", nom="Martin",
    ),
    Case(
        patient_id="1234567890125", nir="1 25 47 6789 0123 456 80",
        age=55, sex="M",
        diagnosis="IPMN transformé",
        procedure_type="Whipple modifié", approach="cœlioscopie",
        venous_resection=True,
        tumor_size_mm=42.0,
        histology="IPMN transformé",
        pT="pT3", pN="pN2",
        nodes_examined=31, nodes_positive=5,
        margin_R="R1",
        pancreatic_fistula=True, delayed_gastrojejunostomy=True,
        hemorrhage=True,
        length_of_stay=21, readmission=True,
        date_naissance="10/11/1970",
        adresse="8 rue de la République, 69001 Lyon",
        telephone="06 34 56 78 90",
        email="paul.bernard@exemple.fr",
        prenom="Paul", nom="Bernard",
    ),
    Case(
        patient_id="1234567890126", nir="2 26 48 6789 0123 456 81",
        age=61, sex="F",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="laparotomie",
        venous_resection=False,
        tumor_size_mm=None,  # non précisé dans le dossier
        histology="adénocarcinome canalaire",
        pT="pT2", pN="pN0",
        nodes_examined=15, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=8, readmission=False,
        date_naissance="05/01/1964",
        adresse="23 cours Lafayette, 69006 Lyon",
        telephone="06 45 67 89 01",
        email="sophie.petit@exemple.fr",
        prenom="Sophie", nom="Petit",
    ),
    Case(
        patient_id="1234567890127", nir="1 27 49 6789 0123 456 82",
        age=78, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="cœlioscopie convertie",
        venous_resection=True,
        tumor_size_mm=35.0,
        histology="adénocarcinome canalaire",
        pT="pT4", pN="pN1",
        nodes_examined=22, nodes_positive=2,
        margin_R="R2",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=11, readmission=False,
        date_naissance="30/09/1947",
        adresse="3 place Bellecour, 69002 Lyon",
        telephone="06 56 78 90 12",
        email="jacques.moreau@exemple.fr",
        prenom="Jacques", nom="Moreau",
    ),
    Case(
        patient_id="1234567890128", nir="2 28 50 6789 0123 456 83",
        age=69, sex="F",
        diagnosis="TNE grade 1 du pancréas",
        procedure_type="Duodénopancréatectomie", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=12.0,
        histology="TNE grade 1",
        pT="pT1", pN="pN0",
        nodes_examined=12, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=7, readmission=False,
        date_naissance="14/05/1956",
        adresse="17 rue Saint-Jean, 69005 Lyon",
        telephone="06 67 89 01 23",
        email="isabelle.lemoine@exemple.fr",
        prenom="Isabelle", nom="Lemoine",
    ),
    Case(
        patient_id="1234567890129", nir="1 29 51 6789 0123 456 84",
        age=63, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="Whipple modifié", approach="laparotomie",
        venous_resection=False,
        tumor_size_mm=31.0,
        histology="adénocarcinome canalaire",
        pT="pT3", pN="pN1",
        nodes_examined=26, nodes_positive=4,
        margin_R="R0",
        pancreatic_fistula=True, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=16, readmission=False,
        date_naissance="08/12/1962",
        adresse="51 rue de Marseille, 69007 Lyon",
        telephone="06 78 90 12 34",
        email="michel.garcia@exemple.fr",
        prenom="Michel", nom="Garcia",
    ),
    Case(
        patient_id="1234567890130", nir="2 30 52 6789 0123 456 85",
        age=58, sex="F",
        diagnosis="IPMN bordeline",
        procedure_type="Duodénopancréatectomie", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=22.0,
        histology="IPMN bordeline",
        pT="pT2", pN="pN0",
        nodes_examined=14, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=10, readmission=False,
        date_naissance="25/06/1967",
        adresse="9 avenue Lacassagne, 69003 Lyon",
        telephone="06 89 01 23 45",
        email="claire.dubois@exemple.fr",
        prenom="Claire", nom="Dubois",
    ),
    Case(
        patient_id="1234567890131", nir="1 31 53 6789 0123 456 86",
        age=74, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="cœlioscopie",
        venous_resection=True,
        tumor_size_mm=38.0,
        histology="adénocarcinome canalaire",
        pT="pT3", pN="pN2",
        nodes_examined=29, nodes_positive=6,
        margin_R="R1",
        pancreatic_fistula=True, delayed_gastrojejunostomy=True,
        hemorrhage=True,
        length_of_stay=24, readmission=True,
        date_naissance="17/02/1951",
        adresse="28 rue Paul Bert, 69003 Lyon",
        telephone="06 90 12 34 56",
        email="thierry.laurent@exemple.fr",
        prenom="Thierry", nom="Laurent",
    ),
    # --- 10 cas "quick" (inclus dans les 20) ---
    Case(
        patient_id="1234567890132", nir="2 32 54 6789 0123 456 87",
        age=66, sex="F",
        diagnosis="TNE grade 3 du pancréas",
        procedure_type="DPC", approach="laparotomie",
        venous_resection=False,
        tumor_size_mm=45.0,
        histology="TNE grade 3",
        pT="pT4", pN="pN2",
        nodes_examined=33, nodes_positive=8,
        margin_R="R2",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=13, readmission=False,
        date_naissance="03/08/1959",
        adresse="14 rue de la Part-Dieu, 69003 Lyon",
        telephone="06 01 23 45 67",
        email="nathalie.roux@exemple.fr",
        prenom="Nathalie", nom="Roux",
    ),
    Case(
        patient_id="1234567890133", nir="1 33 55 6789 0123 456 88",
        age=71, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="Whipple modifié", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=26.0,
        histology="adénocarcinome canalaire",
        pT="pT2", pN="pN0",
        nodes_examined=19, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=9, readmission=False,
        date_naissance="19/04/1954",
        adresse="6 place des Terreaux, 69001 Lyon",
        telephone="06 12 34 56 78",
        email="philippe.morel@exemple.fr",
        prenom="Philippe", nom="Morel",
    ),
    Case(
        patient_id="1234567890134", nir="2 34 56 6789 0123 456 89",
        age=59, sex="F",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="Duodénopancréatectomie", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=19.0,
        histology="adénocarcinome canalaire",
        pT="pT1", pN="pN0",
        nodes_examined=11, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=6, readmission=False,
        date_naissance="11/10/1966",
        adresse="19 rue Édouard Herriot, 69002 Lyon",
        telephone="06 23 45 67 89",
        email="sylvie.girard@exemple.fr",
        prenom="Sylvie", nom="Girard",
    ),
    Case(
        patient_id="1234567890135", nir="1 35 57 6789 0123 456 90",
        age=82, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="laparotomie",
        venous_resection=True,
        tumor_size_mm=41.0,
        histology="adénocarcinome canalaire",
        pT="pT4", pN="pN1",
        nodes_examined=27, nodes_positive=3,
        margin_R="R1",
        pancreatic_fistula=True, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=18, readmission=True,
        date_naissance="27/07/1943",
        adresse="42 cours Franklin Roosevelt, 69006 Lyon",
        telephone="06 34 56 78 90",
        email="robert.mercier@exemple.fr",
        prenom="Robert", nom="Mercier",
    ),
    Case(
        patient_id="1234567890136", nir="2 36 58 6789 0123 456 91",
        age=64, sex="F",
        diagnosis="TNE grade 2 du pancréas",
        procedure_type="Duodénopancréatectomie", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=17.0,
        histology="TNE grade 2",
        pT="pT2", pN="pN0",
        nodes_examined=16, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=8, readmission=False,
        date_naissance="09/12/1961",
        adresse="11 rue de la Villette, 69003 Lyon",
        telephone="06 45 67 89 01",
        email="françoise.blanc@exemple.fr",
        prenom="Françoise", nom="Blanc",
    ),
    Case(
        patient_id="1234567890137", nir="1 37 59 6789 0123 456 92",
        age=76, sex="M",
        diagnosis="IPMN transformé",
        procedure_type="Whipple modifié", approach="cœlioscopie convertie",
        venous_resection=True,
        tumor_size_mm=50.0,
        histology="IPMN transformé",
        pT="pT3", pN="pN2",
        nodes_examined=35, nodes_positive=7,
        margin_R="R2",
        pancreatic_fistula=True, delayed_gastrojejunostomy=True,
        hemorrhage=True,
        length_of_stay=28, readmission=True,
        date_naissance="21/03/1949",
        adresse="16 rue de Sèze, 69006 Lyon",
        telephone="06 56 78 90 12",
        email="bernard.fournier@exemple.fr",
        prenom="Bernard", nom="Fournier",
    ),
    Case(
        patient_id="1234567890138", nir="2 38 60 6789 0123 456 93",
        age=57, sex="F",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=23.0,
        histology="adénocarcinome canalaire",
        pT="pT2", pN="pN0",
        nodes_examined=17, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=7, readmission=False,
        date_naissance="13/05/1968",
        adresse="22 rue Garibaldi, 69007 Lyon",
        telephone="06 67 89 01 23",
        email="virginie.perrot@exemple.fr",
        prenom="Virginie", nom="Perrot",
    ),
    Case(
        patient_id="1234567890139", nir="1 39 61 6789 0123 456 94",
        age=70, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="Duodénopancréatectomie", approach="laparotomie",
        venous_resection=False,
        tumor_size_mm=29.0,
        histology="adénocarcinome canalaire",
        pT="pT3", pN="pN1",
        nodes_examined=23, nodes_positive=2,
        margin_R="R0",
        pancreatic_fistula=True, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=15, readmission=False,
        date_naissance="07/11/1955",
        adresse="31 rue de Créqui, 69006 Lyon",
        telephone="06 78 90 12 34",
        email="lambert@exemple.fr",
        prenom="Georges", nom="Lambert",
    ),
    Case(
        patient_id="1234567890140", nir="2 40 62 6789 0123 456 95",
        age=62, sex="F",
        diagnosis="TNE grade 1 du pancréas",
        procedure_type="Duodénopancréatectomie", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=14.0,
        histology="TNE grade 1",
        pT="pT1", pN="pN0",
        nodes_examined=10, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=6, readmission=False,
        date_naissance="30/01/1963",
        adresse="7 avenue Rockefeller, 69008 Lyon",
        telephone="06 89 01 23 45",
        email="martine.faure@exemple.fr",
        prenom="Martine", nom="Faure",
    ),
    Case(
        patient_id="1234567890141", nir="1 41 63 6789 0123 456 96",
        age=68, sex="M",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="DPC", approach="cœlioscopie",
        venous_resection=False,
        tumor_size_mm=27.0,
        histology="adénocarcinome canalaire",
        pT="pT2", pN="pN0",
        nodes_examined=20, nodes_positive=0,
        margin_R="R0",
        pancreatic_fistula=False, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=8, readmission=False,
        date_naissance="16/06/1957",
        adresse="13 rue de la Guillotière, 69007 Lyon",
        telephone="06 90 12 34 56",
        email="pierre.renard@exemple.fr",
        prenom="Pierre", nom="Renard",
    ),
    Case(
        patient_id="1234567890142", nir="2 42 64 6789 0123 456 97",
        age=73, sex="F",
        diagnosis="adénocarcinome canalaire du pancréas",
        procedure_type="Whipple modifié", approach="laparotomie",
        venous_resection=True,
        tumor_size_mm=39.0,
        histology="adénocarcinome canalaire",
        pT="pT3", pN="pN1",
        nodes_examined=25, nodes_positive=3,
        margin_R="R1",
        pancreatic_fistula=True, delayed_gastrojejunostomy=False,
        hemorrhage=False,
        length_of_stay=17, readmission=False,
        date_naissance="04/09/1952",
        adresse="26 rue de l'Université, 69007 Lyon",
        telephone="06 01 23 45 67",
        email="monique.barbier@exemple.fr",
        prenom="Monique", nom="Barbier",
    ),
]


def get_case(patient_id: str) -> Optional[Case]:
    """Retourne un cas par son IPP."""
    for case in CASES:
        if case.patient_id == patient_id:
            return case
    return None


def case_count() -> int:
    """Nombre total de cas."""
    return len(CASES)


def quick_set() -> list[Case]:
    """Retourne les 10 premiers cas (sous-ensemble quick)."""
    return CASES[:10]


def compute_seed() -> int:
    """Graine déterministe pour le générateur."""
    return 20260926


def compute_checksum() -> str:
    """Empreinte SHA256 du registre (pour vérification d'intégrité)."""
    h = hashlib.sha256()
    for case in CASES:
        h.update(f"{case.patient_id}:{case.age}:{case.sex}:{case.diagnosis}".encode())
    return h.hexdigest()
