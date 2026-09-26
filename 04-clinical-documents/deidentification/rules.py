"""FARCI — règles de pseudonymisation.

Ordre de traitement :
1. Dates
2. Identifiants forts (IPP, NIR, SSN)
3. Téléphones et emails
4. Adresses
5. Noms et prénoms

Chaque règle est une fonction qui prend le texte et le mapping,
et retourne le texte pseudonymisé.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .mapping import MappingStore


# --------------------------------------------------------------------------
# Dates
# --------------------------------------------------------------------------

DATE_PATTERNS = [
    # JJ/MM/AAAA
    (r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b', 'DATE'),
    # JJ-MM-AAAA
    (r'\b(\d{1,2})-(\d{1,2})-(\d{4})\b', 'DATE'),
    # JJ MM AAAA (mois en lettres)
    (r'\b(\d{1,2})\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s+(\d{4})\b', 'DATE'),
]


def pseudonymize_dates(text: str, mapping: MappingStore) -> str:
    """Remplace les dates par [DATE_XXX]."""
    for pattern, tag in DATE_PATTERNS:
        def replacer(m):
            key = f"DATE_{mapping.get_counter('DATE')}"
            mapping.add(key, m.group(0))
            return f"[{key}]"
        text = re.sub(pattern, replacer, text, flags=re.IGNORECASE)
    return text


# --------------------------------------------------------------------------
# Identifiants forts (IPP, NIR, SSN)
# --------------------------------------------------------------------------

IPP_PATTERN = r'\b\d{13}\b'
NIR_PATTERN = r'\b\d{1,2}\s\d{2}\s\d{2}\s\d{3}\s\d{3}\s\d{3}\s\d{2}\b'
SSN_PATTERN = r'\b\d{3}\s\d{2}\s\d{2}\s\d{3}\s\d{3}\s\d{3}\b'


def pseudonymize_identifiers(text: str, mapping: MappingStore) -> str:
    """Remplace les IPP, NIR, SSN par [IPP_XXX], [NIR_XXX], [SSN_XXX]."""
    # IPP (13 chiffres)
    def ipp_replacer(m):
        key = f"IPP_{mapping.get_counter('IPP')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    text = re.sub(IPP_PATTERN, ipp_replacer, text)

    # NIR (1 23 45 6789 0123 456 78)
    def nir_replacer(m):
        key = f"NIR_{mapping.get_counter('NIR')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    text = re.sub(NIR_PATTERN, nir_replacer, text)

    # SSN (123 45 67890 12 345)
    def ssn_replacer(m):
        key = f"SSN_{mapping.get_counter('SSN')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    text = re.sub(SSN_PATTERN, ssn_replacer, text)

    return text


# --------------------------------------------------------------------------
# Téléphones et emails
# --------------------------------------------------------------------------

PHONE_PATTERN = r'\b0[1-9](?:[\s.-]?\d{2}){4}\b'
EMAIL_PATTERN = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'


def pseudonymize_contacts(text: str, mapping: MappingStore) -> str:
    """Remplace les téléphones et emails par [TEL_XXX], [EMAIL_XXX]."""
    def phone_replacer(m):
        key = f"TEL_{mapping.get_counter('TEL')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    text = re.sub(PHONE_PATTERN, phone_replacer, text)

    def email_replacer(m):
        key = f"EMAIL_{mapping.get_counter('EMAIL')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    text = re.sub(EMAIL_PATTERN, email_replacer, text)

    return text


# --------------------------------------------------------------------------
# Adresses
# --------------------------------------------------------------------------

ADDRESS_PATTERN = r'\b\d{1,5}\s+(?:rue|avenue|boulevard|cours|place|impasse|allée|chemin)\s+[^,\n]+'


def pseudonymize_addresses(text: str, mapping: MappingStore) -> str:
    """Remplace les adresses par [ADR_XXX]."""
    def replacer(m):
        key = f"ADR_{mapping.get_counter('ADR')}"
        mapping.add(key, m.group(0))
        return f"[{key}]"
    return re.sub(ADDRESS_PATTERN, replacer, text, flags=re.IGNORECASE)


# --------------------------------------------------------------------------
# Noms et prénoms
# --------------------------------------------------------------------------

# Dictionnaire des prénoms français fréquents
FRENCH_FIRST_NAMES = {
    "jean", "pierre", "michel", "philippe", "louis", "nicolas", "françois",
    "antoine", "julien", "thomas", "hugo", "arthur", "jules", "gabriel",
    "léo", "raphaël", "adam", "nathan", "ethan", "marie", "sophie",
    "isabelle", "catherine", "nathalie", "sylvie", "françoise", "monique",
    "christine", "martine", "anne", "claire", "juliette", "léa", "chloé",
    "manon", "emma", "alice", "jade", "louise", "rose", "anna", "jeanne",
    "lucas", "maël", "gabin", "sacha", "raphaël", "timéo", "enzo", "marius",
    "paul", "marcel", "rené", "bernard", "robert", "jacques", "georges",
    "claude", "alain", "patrick", "didier", "serge", "eric", "david",
    "laurent", "maxime", "alexandre", "vincent", "julien", "benjamin",
    "martin", "dubois", "bernard", "moreau", "laurent", "simon", "michel",
    "lefebvre", "leroy", "roux", "david", "bertrand", "morel", "fournier",
    "girard", "bonnet", "dupont", "lambert", "fontaine", "rousseau",
    "vincent", "faure", "mercier", "blanc", "guerin", "muller", "henry",
    "nicolas", "morin", "mathieu", "gauthier", "petit", "robert", "duval",
    "gautier", "leclerc", "marchand", "dupuis", "lamy", "dumont", "martin",
    "lecomte", "gros", "charles", "renaud", "barbier", "perrot", "garnier",
    "perrier", "leblanc", "leger", "millet", "marchal", "collet", "lejeune",
    "peltier", "chauvin", "duval", "brun", "langlois", "gros", "gervais",
    "pelletier", "leveque", "michaud", "caron", "letellier", "bouvet",
    "humbert", "guichard", "hamon", "mahe", "lemer", "picard", "leclercq",
    "gonzalez", "meunier", "marty", "weber", "schmitt", "jacquet", "paris",
    "perrot", "gillet", "fontaine", "bailly", "barre", "leroux", "renard",
    "millet", "charbonnier", "tessier", "dupuy", "marquet", "marty",
    "lecoq", "hugues", "guillot", "loiseau", "jacques", "bataille", "ollivier",
    "levy", "peltier", "giraud", "chauvet", "fischer", "germain", "peron",
    "vidal", "legrand", "weber", "schmitt", "jacquet", "paris", "perrot",
    "gillet", "fontaine", "bailly", "barre", "leroux", "renard", "millet",
    "charbonnier", "tessier", "dupuy", "marquet", "marty", "lecoq", "hugues",
    "guillot", "loiseau", "jacques", "bataille", "ollivier", "levy",
    "peltier", "giraud", "chauvet", "fischer", "germain", "peron", "vidal",
    "legrand",
}

# Noms de famille français fréquents
FRENCH_LAST_NAMES = {
    "martin", "bernard", "dubois", "thomas", "robert", "richard", "petit",
    "durand", "leroy", "moreau", "simon", "laurent", "lefebvre", "michel",
    "david", "bertrand", "roux", "vincent", "fournier", "morel", "girard",
    "andre", "lefebvre", "mercier", "blanc", "guerin", "muller", "henry",
    "nicolas", "morin", "mathieu", "gauthier", "petit", "robert", "duval",
    "gautier", "leclerc", "marchand", "dupuis", "lamy", "dumont", "martin",
    "lecomte", "gros", "charles", "renaud", "barbier", "perrot", "garnier",
    "perrier", "leblanc", "leger", "millet", "marchal", "collet", "lejeune",
    "peltier", "chauvin", "duval", "brun", "langlois", "gros", "gervais",
    "pelletier", "leveque", "michaud", "caron", "letellier", "bouvet",
    "humbert", "guichard", "hamon", "mahe", "lemer", "picard", "leclercq",
    "gonzalez", "meunier", "marty", "weber", "schmitt", "jacquet", "paris",
    "perrot", "gillet", "fontaine", "bailly", "barre", "leroux", "renard",
    "millet", "charbonnier", "tessier", "dupuy", "marquet", "marty",
    "lecoq", "hugues", "guillot", "loiseau", "jacques", "bataille", "ollivier",
    "levy", "peltier", "giraud", "chauvet", "fischer", "germain", "peron",
    "vidal", "legrand",
}


def pseudonymize_names(text: str, mapping: MappingStore) -> str:
    """Remplace les noms et prénoms par [PRENOM_XXX], [NOM_XXX]."""
    # Prénoms (mots en minuscules dans le dictionnaire)
    for first_name in FRENCH_FIRST_NAMES:
        pattern = rf'\b{first_name}\b'
        def replacer(m):
            key = f"PRENOM_{mapping.get_counter('PRENOM')}"
            mapping.add(key, m.group(0))
            return f"[{key}]"
        text = re.sub(pattern, replacer, text, flags=re.IGNORECASE)

    # Noms de famille (mots en minuscules dans le dictionnaire)
    for last_name in FRENCH_LAST_NAMES:
        pattern = rf'\b{last_name}\b'
        def replacer(m):
            key = f"NOM_{mapping.get_counter('NOM')}"
            mapping.add(key, m.group(0))
            return f"[{key}]"
        text = re.sub(pattern, replacer, text, flags=re.IGNORECASE)

    return text


# --------------------------------------------------------------------------
# Pipeline complet
# --------------------------------------------------------------------------

def pseudonymize_text(text: str, mapping: MappingStore) -> str:
    """Applique toutes les règles de pseudonymisation dans l'ordre."""
    text = pseudonymize_dates(text, mapping)
    text = pseudonymize_identifiers(text, mapping)
    text = pseudonymize_contacts(text, mapping)
    text = pseudonymize_addresses(text, mapping)
    text = pseudonymize_names(text, mapping)
    return text
