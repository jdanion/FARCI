#!/usr/bin/env python3
"""FARCI — quatre façons d'écrire le même dossier (datasets/tools/styles.py).

Un formulaire « champ : valeur » s'extrait sans effort : n'importe quel modèle
et n'importe quelle consigne y réussissent, et l'on n'apprend rien. Les vingt
dossiers sont donc rédigés dans quatre styles, de difficulté croissante. Les
VALEURS ne changent pas (datasets/tools/cases.py reste la source de vérité, le
gold est inchangé) : seule l'écriture change.

  formulaire      champ : valeur                  la ligne de base : tout le monde réussit
  narratif        prose dictée, phrases           négations, synonymes, centimètres,
                                                  sexe et âge à déduire du texte
  telegraphique   abréviations de service         « T3 N1 », « 3N+/24 », « FP grade B »,
                                                  « ADK », « H 71 a. »
  pieges          prose + distracteurs            antécédents, mesure du scanner différente
                                                  de l'anatomopathologie, événement suspecté
                                                  puis écarté, fuite biochimique

Chaque piège a une réponse défendable cliniquement, écrite dans
07-applications/common/prompts/extraction_clinique.md : c'est ce que l'on
compare aux autres consignes.

Tout est déterministe : la variante d'une phrase dépend du rang du dossier,
jamais du hasard. Le texte évite les mots que la pseudonymisation par
dictionnaire prendrait pour un nom (tests/test_dataset_styles.py le vérifie).
"""

from __future__ import annotations

from cases import CASES

STYLES = ("formulaire", "narratif", "telegraphique", "pieges")
# Cinq dossiers par style, dans l'ordre du registre.
STYLE_BY_RANK = {rank: STYLES[rank // 5] for rank in range(20)}

UNITES = ("zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "onze", "douze",
          "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf")
DIZAINES = {20: "vingt", 30: "trente", 40: "quarante", 50: "cinquante", 60: "soixante"}


def en_lettres(n: int) -> str:
    """Un entier de 0 à 99, en toutes lettres."""
    if n < 20:
        return UNITES[n]
    if n < 70:
        dizaine, unite = n - n % 10, n % 10
        if unite == 0:
            return DIZAINES[dizaine]
        return f"{DIZAINES[dizaine]} et un" if unite == 1 else f"{DIZAINES[dizaine]}-{UNITES[unite]}"
    if n < 80:
        return "soixante et onze" if n == 71 else f"soixante-{UNITES[n - 60]}"
    if n == 80:
        return "quatre-vingts"
    return f"quatre-vingt-{UNITES[n - 80]}"


def rank_of(case) -> int:
    return next(i for i, c in enumerate(CASES) if c.patient_id == case.patient_id)


def style_of(patient_id: str) -> str:
    """Le style d'écriture d'un dossier (« formulaire » pour un IPP inconnu)."""
    for rank, case in enumerate(CASES):
        if case.patient_id == patient_id:
            return STYLE_BY_RANK[rank]
    return "formulaire"


# --------------------------------------------------------------------------
# Briques de phrase communes
# --------------------------------------------------------------------------

def _f(case) -> bool:
    return case.sex == "F"


def _entete(titre: str, case, complet: bool = False) -> str:
    lignes = [titre, "", f"Patient : {case.prenom} {case.nom}", f"IPP : {case.patient_id}"]
    if complet:
        lignes += [f"NIR : {case.nir}", f"Date de naissance : {case.date_naissance}"]
    return "\n".join(lignes) + "\n"


def _un(nom: str) -> str:
    """L'article indéfini devant un diagnostic du registre."""
    return "une" if nom.startswith("TNE") else "un"


def _geste(case) -> str:
    return {"DPC": "une DPC", "Duodénopancréatectomie": "une duodénopancréatectomie",
            "Whipple modifié": "une intervention de type Whipple modifié"}[case.procedure_type]


def _cm(mm: float) -> str:
    return f"{mm / 10:.1f}".replace(".", ",")


def _taille_scanner(case, rank: int) -> int:
    """La mesure du scanner diffère de celle de la pièce : c'est la règle, pas l'exception."""
    return int(case.tumor_size_mm) + (3, -2, 4, 2, -3)[rank % 5]


def _ganglions(case) -> str:
    if case.nodes_positive:
        return (f"{en_lettres(case.nodes_positive).capitalize()} ganglions métastatiques "
                f"sur {case.nodes_examined} examinés.")
    return f"Les {case.nodes_examined} ganglions examinés sont indemnes."


# --------------------------------------------------------------------------
# Style narratif
# --------------------------------------------------------------------------

def _narratif(case, rank: int) -> dict[str, str]:
    f = _f(case)
    voie = {
        "cœlioscopie": ("par voie cœlioscopique", "par abord laparoscopique")[rank % 2],
        "laparotomie": ("par laparotomie médiane", "par voie ouverte, incision bi-sous-costale")[rank % 2],
        "cœlioscopie convertie": "débutée par cœlioscopie puis convertie en laparotomie devant des adhérences serrées",
    }[case.approach]
    veine = (("Une résection-anastomose de la veine porte est nécessaire.",
              "Résection latérale de la veine mésentérique supérieure, suture directe.")[rank % 2]
             if case.venous_resection else
             ("Aucun geste vasculaire associé.",
              "La dissection est menée au contact de la veine mésentérique supérieure, sans résection veineuse.")[rank % 2])
    cro = _entete("COMPTE RENDU OPÉRATOIRE", case, complet=True) + f"""
Il s'agit d'{'une patiente âgée' if f else 'un patient âgé'} de {case.age} ans, pris{'e' if f else ''} en charge pour {_un(case.diagnosis)} {case.diagnosis}.

Il est réalisé {_geste(case)} {voie}. {veine}
Reconstruction par anastomoses pancréatico-jéjunale, hépatico-jéjunale et gastro-jéjunale. Mise en place de deux drains.
"""

    marge = {"R0": "Les limites d'exérèse sont saines (R0).",
             "R1": "La marge rétroporte est envahie microscopiquement (R1).",
             "R2": "Un résidu tumoral macroscopique a été laissé en place (R2)."}[case.margin_R]
    crap = _entete("COMPTE RENDU ANATOMOPATHOLOGIQUE", case) + f"""
Pièce opératoire adressée à l'état frais. La tumeur siège dans la tête du pancréas et mesure {_cm(case.tumor_size_mm)} cm de grand axe.
Il s'agit d'{_un(case.histology)} {case.histology}.
{_ganglions(case)}
{marge}
Classification pTNM (8e édition) : {case.pT} {case.pN}.
"""

    crscan = _entete("COMPTE RENDU SCANNER", case) + f"""
Scanner thoraco-abdomino-pelvien avec injection.
Masse de la tête du pancréas mesurée à {_taille_scanner(case, rank)} mm, avec dilatation bicanalaire.
{'Contact étendu avec l axe veineux mésentérico-porte.' if case.venous_resection else 'Absence de contact vasculaire.'}
Absence de lésion secondaire hépatique ou pulmonaire.
""".replace("l axe", "l'axe")

    suites = []
    if case.pancreatic_fistula:
        suites.append("une fistule pancréatique de grade B, traitée par maintien du drainage et antibiothérapie")
    if case.delayed_gastrojejunostomy:
        suites.append("une gastroparésie ayant imposé le maintien de la sonde nasogastrique jusqu'à J9")
    if case.hemorrhage:
        suites.append("une hémorragie post-opératoire à J6, contrôlée par embolisation")
    phrases = [f"Les suites ont été marquées par {' et '.join(suites)}." if suites else "Les suites opératoires ont été simples."]
    if not case.pancreatic_fistula:
        phrases.append(("L'amylase dosée sur le drain à J3 était normale, le drain a été retiré à J5.",
                        "Aucune fistule pancréatique n'a été constatée.")[rank % 2])
    if not case.delayed_gastrojejunostomy:
        phrases.append("L'alimentation orale a été reprise à J4 sans difficulté.")
    if not case.hemorrhage:
        phrases.append("Aucune complication hémorragique.")
    sortie = ((f"La sortie a été autorisée à J{case.length_of_stay}.",
               f"La durée d'hospitalisation a été de {en_lettres(case.length_of_stay)} jours.")[rank % 2])
    retour = ("Une réhospitalisation a été nécessaire huit jours après la sortie pour une collection abdominale, "
              "drainée par voie radiologique." if case.readmission
              else "Aucune réhospitalisation dans le mois qui a suivi la sortie.")
    lettre = _entete("LETTRE DE SORTIE", case) + f"""
{'Madame' if f else 'Monsieur'} a été hospitalisé{'e' if f else ''} dans le service pour {_geste(case)}.
{' '.join(phrases)}
{sortie} {retour}
Consultation de contrôle prévue à un mois.
"""
    return {"cro": cro, "crap": crap, "crscan": crscan, "lettre": lettre}


# --------------------------------------------------------------------------
# Style télégraphique
# --------------------------------------------------------------------------

ABREGE = {"adénocarcinome canalaire du pancréas": "ADK canalaire pancréas", "adénocarcinome canalaire": "ADK canalaire",
          "IPMN transformé": "IPMN transformé", "IPMN bordeline": "IPMN bordeline"}


def _abrege(nom: str) -> str:
    if nom.startswith("TNE grade"):
        return nom.replace("TNE grade ", "TNE G").replace(" du pancréas", " pancréas")
    return ABREGE[nom]


def _telegraphique(case, rank: int) -> dict[str, str]:
    voie = {"cœlioscopie": "coelio", "laparotomie": "laparotomie",
            "cœlioscopie convertie": "coelio puis conversion laparotomie"}[case.approach]
    geste = {"DPC": "DPC", "Duodénopancréatectomie": "duodénopancréatectomie",
             "Whipple modifié": "Whipple modifié"}[case.procedure_type]
    cro = _entete("CRO", case, complet=True) + f"""
{'F' if _f(case) else 'H'} {case.age} a. - {_abrege(case.diagnosis)}
Geste : {geste}
Voie : {voie}
Veine : {'résection VP + anastomose termino-terminale' if case.venous_resection else 'RAS, pas de résection'}
Durée 6 h, pertes {250 + 20 * (rank % 5)} mL, 2 drains.
"""
    stade = (f"{case.pT}{case.pN[1:]}", f"{case.pT[1:]} {case.pN[1:]}")[rank % 2]   # pT3N1 ou T3 N1
    marge = {"R0": "R0", "R1": "R1 (rétroporte)", "R2": "R2"}[case.margin_R]
    crap = _entete("ANAPATH", case) + f"""
Pièce : {geste}
{_abrege(case.histology)}, {int(case.tumor_size_mm)} mm
{stade} - {case.nodes_positive}N+/{case.nodes_examined}
Marges : {marge}
"""
    crscan = _entete("TDM TAP", case) + f"""
Masse tête pancréas {_taille_scanner(case, rank)} mm.
{'Engainement VP.' if case.venous_resection else 'Pas de contact vasc.'}
Pas de méta.
"""
    lettre = _entete("CRH - SORTIE", case) + f"""
FP : {'grade B, drain maintenu' if case.pancreatic_fistula else '0'}
DGE : {'+ (SNG jusqu à J9)' if case.delayed_gastrojejunostomy else '0'}
Hgie : {'+ J6, embolisation' if case.hemorrhage else '0'}
Sortie J{case.length_of_stay}.
Réadm : {'+ (J+8, collection drainée)' if case.readmission else '0'}
""".replace("jusqu à", "jusqu'à")
    return {"cro": cro, "crap": crap, "crscan": crscan, "lettre": lettre}


# --------------------------------------------------------------------------
# Style « pièges »
# --------------------------------------------------------------------------

def _pieges(case, rank: int) -> dict[str, str]:
    f = _f(case)
    # Antécédent opéré par la voie OPPOSÉE à celle de l'intervention : un
    # modèle distrait y lit la voie d'abord.
    autre_voie = "par laparotomie" if case.approach == "cœlioscopie" else "par cœlioscopie"
    antecedents = (
        f"Antécédents : cholécystectomie {autre_voie} en 2011 ; kyste rénal gauche de 12 mm, surveillé.",
        f"Antécédents : appendicectomie {autre_voie} dans l'enfance ; père décédé à 71 ans d'un adénocarcinome colique.",
        f"Antécédents : cure de hernie inguinale {autre_voie} en 2015 ; nodule thyroïdien de 9 mm, stable.",
        f"Antécédents : cholécystectomie {autre_voie} en 2008 ; frère suivi pour une TNE grade 2 du grêle.",
        f"Antécédents : hystérectomie {autre_voie} en 2004 ; mère âgée de 94 ans, suivie pour un adénocarcinome mammaire."
        if f else
        f"Antécédents : prostatectomie {autre_voie} en 2016 ; père décédé à 79 ans d'un adénocarcinome gastrique.",
    )[rank % 5]
    veine = ("L'envahissement de la veine mésentérique supérieure sur 2 cm impose une résection-anastomose veineuse."
             if case.venous_resection else
             "La dissection au contact de la veine porte est laborieuse ; la veine est finalement libérée sans résection.")
    voie = {
        "cœlioscopie": "par voie cœlioscopique exclusive",
        "laparotomie": "par laparotomie bi-sous-costale",
        "cœlioscopie convertie": "débutée par cœlioscopie puis convertie en laparotomie devant un saignement veineux",
    }[case.approach]
    cro = _entete("COMPTE RENDU OPÉRATOIRE", case, complet=True) + f"""
Il s'agit d'{'une patiente âgée' if f else 'un patient âgé'} de {case.age} ans, pris{'e' if f else ''} en charge pour {_un(case.diagnosis)} {case.diagnosis}.
{antecedents}

Il est réalisé {_geste(case)} {voie}. {veine}
Pertes sanguines peropératoires estimées à {300 + 10 * (rank % 5)} mL, sans transfusion.
Examen extemporané de la tranche pancréatique : sain.
"""

    grand = int(case.tumor_size_mm)
    marge = {"R0": "Limites chirurgicales en tissu sain ; la tumeur reste à 3 mm de la marge rétroporte.",
             "R1": "La tranche de section rétroporte est envahie microscopiquement par la tumeur.",
             "R2": "Persistance d'un résidu tumoral macroscopique au contact de l'artère mésentérique supérieure."}[case.margin_R]
    ancien = {"pT1": "pT1", "pT2": "pT3", "pT3": "pT3", "pT4": "pT4"}[case.pT]
    crap = _entete("COMPTE RENDU ANATOMOPATHOLOGIQUE", case) + f"""
Pièce opératoire adressée à l'état frais. Tumeur de la tête du pancréas mesurant {grand - 6} x {grand} x {grand - 9} mm.
Il s'agit d'{_un(case.histology)} {case.histology}. Index de prolifération estimé à {3 + rank % 5} %.
Un nodule de 6 mm de la graisse péripancréatique correspond à un foyer de cytostéatonécrose, sans cellule tumorale.
Curage : {case.nodes_examined} ganglions prélevés, dont {en_lettres(case.nodes_positive) if case.nodes_positive else 'aucun'} métastatique{'s' if (case.nodes_positive or 0) > 1 else ''}.
{marge}
Stade {case.pT} {case.pN} selon la 8e édition (ancienne classification, 7e édition : {ancien}).
"""

    crscan = _entete("COMPTE RENDU SCANNER", case) + f"""
Scanner thoraco-abdomino-pelvien avec injection.
Masse de la tête du pancréas mesurée à {_taille_scanner(case, rank)} mm, avec dilatation bicanalaire.
{'Engainement de la veine mésentérique supérieure sur plus de 180 degrés.' if case.venous_resection else 'Contact limité, inférieur à 90 degrés, avec la veine mésentérique supérieure.'}
Micronodule pulmonaire lobaire inférieur droit de 4 mm, non spécifique, à contrôler.
"""

    phrases = []
    if case.pancreatic_fistula:
        phrases.append("Les suites ont été marquées par une fistule pancréatique de grade B, traitée par maintien du drainage.")
    else:
        phrases.append("Élévation isolée de l'amylase sur le drain à J3 (fuite biochimique), sans retentissement clinique ; "
                       "le drain a été retiré à J5.")
    if not case.hemorrhage:
        phrases.append("Une déglobulisation à J4 a fait suspecter une hémorragie, écartée par l'angioscanner.")
    else:
        phrases.append("Hémorragie post-opératoire à J6, contrôlée par embolisation.")
    if not case.delayed_gastrojejunostomy:
        phrases.append("Iléus réflexe résolutif à J3, alimentation reprise à J4 sans gastroparésie.")
    else:
        phrases.append("Gastroparésie ayant imposé le maintien de la sonde nasogastrique jusqu'à J9.")
    retour = ("Une réhospitalisation a été nécessaire huit jours après la sortie pour une collection abdominale."
              if case.readmission else
              f"Consultation non programmée à J{case.length_of_stay + 6} pour douleurs abdominales : bilan rassurant, "
              "retour à domicile le jour même.")
    lettre = _entete("LETTRE DE SORTIE", case) + f"""
{'Madame' if f else 'Monsieur'} a été hospitalisé{'e' if f else ''} dans le service pour {_geste(case)}.
{' '.join(phrases)}
Sortie à J{case.length_of_stay}, suivie de trois semaines en soins de suite et de réadaptation.
{retour}
"""
    return {"cro": cro, "crap": crap, "crscan": crscan, "lettre": lettre}


RENDERERS = {"narratif": _narratif, "telegraphique": _telegraphique, "pieges": _pieges}


def render_documents(case) -> dict[str, str] | None:
    """Les quatre documents d'un dossier dans son style, ou None pour le formulaire
    (rendu par les gabarits historiques de render_pdf.py)."""
    rank = rank_of(case)
    renderer = RENDERERS.get(STYLE_BY_RANK[rank])
    return renderer(case, rank) if renderer else None
