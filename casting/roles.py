"""FARCI — définition des rôles et de leurs exigences.

Chaque rôle a :
- un nom
- une liste d'options (la première = choix n°1, indispensable)
- des exigences matérielles (RAM, GPU, Mac, etc.)
- un nombre d'étudiants requis
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Option:
    """Une option pour un rôle (ex: Ollama, llama.cpp, oMLX)."""
    name: str
    label: str
    requires_mac: bool = False
    requires_gpu: bool = False
    min_ram_gb: int = 0
    min_vram_gb: int = 0
    description: str = ""


@dataclass
class Role:
    """Un rôle dans l'atelier."""
    name: str
    label: str
    options: list[Option]
    min_students: int = 1
    max_students: int = 1
    critical: bool = True  # True = rôle indispensable (choix n°1)
    description: str = ""

    @property
    def primary_option(self) -> Option:
        """Retourne l'option principale (choix n°1)."""
        return self.options[0] if self.options else None


# --------------------------------------------------------------------------
# Définition des rôles FARCI
# --------------------------------------------------------------------------

ROLES: list[Role] = [
    # --- Équipe 0 : GitOps ---
    Role(
        name="gitops",
        label="GitOps",
        options=[
            Option("gitea", "Gitea", min_ram_gb=2, description="Forge Git"),
            Option("gitlab", "GitLab", min_ram_gb=4, description="Alternative à Gitea"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Forge Git + CI/CD",
    ),

    # --- Équipe 1 : Réseau & Dashboard ---
    Role(
        name="network",
        label="Réseau & Dashboard",
        options=[
            Option("caddy", "Caddy", min_ram_gb=1, description="Reverse proxy"),
            Option("nginx", "Nginx", min_ram_gb=1, description="Alternative à Caddy"),
            Option("traefik", "Traefik", min_ram_gb=2, description="Alternative cloud-native"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Réverse proxy + dashboard",
    ),

    # --- Équipe 2 : Inférence ---
    Role(
        name="inference",
        label="Inférence",
        options=[
            Option("ollama", "Ollama", min_ram_gb=8, description="Runtime principal"),
            Option("llamacpp", "llama.cpp", min_ram_gb=4, description="Runtime alternatif"),
            Option("omlx", "oMLX", requires_mac=True, min_ram_gb=16, description="Mac uniquement"),
        ],
        min_students=2,
        max_students=4,
        critical=True,
        description="Runtime d'inférence LLM",
    ),

    # --- Équipe 3 : LLM Gateway ---
    Role(
        name="gateway",
        label="LLM Gateway",
        options=[
            Option("litellm", "LiteLLM", min_ram_gb=2, description="Gateway principale"),
            Option("bifrost", "Bifrost", min_ram_gb=2, description="Gateway alternative"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Gateway LLM + rate limiting",
    ),

    # --- Équipe 4 : Documents cliniques ---
    Role(
        name="documents",
        label="Documents cliniques",
        options=[
            Option("docling", "Docling", min_ram_gb=4, description="Conversion PDF"),
            Option("pymupdf", "PyMuPDF", min_ram_gb=2, description="Alternative légère"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Conversion + pseudonymisation",
    ),

    # --- Équipe 5 : Observabilité ---
    Role(
        name="observability",
        label="Observabilité",
        options=[
            Option("phoenix", "Phoenix", min_ram_gb=4, description="Backend principal"),
            Option("langfuse", "Langfuse", min_ram_gb=4, description="Backend alternatif"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Traces + métriques LLM",
    ),

    # --- Équipe 6 : Évaluation ---
    Role(
        name="evaluation",
        label="Évaluation",
        options=[
            Option("mlflow", "MLflow", min_ram_gb=4, description="Suivi des runs"),
            Option("wandb", "W&B", min_ram_gb=2, description="Alternative cloud"),
        ],
        min_students=1,
        max_students=2,
        critical=True,
        description="Métriques + comparaison",
    ),

    # --- Équipe 7 : Applications ---
    Role(
        name="applications",
        label="Applications",
        options=[
            Option("python", "Python", min_ram_gb=2, description="Parcours A"),
            Option("open-webui", "Open WebUI", min_ram_gb=4, description="Parcours B"),
            Option("flowise", "Flowise", min_ram_gb=4, description="Parcours C"),
        ],
        min_students=2,
        max_students=4,
        critical=True,
        description="Applications clientes",
    ),

    # --- Équipe 8 : Agents Arcane & GitOps ---
    Role(
        name="arcane",
        label="Agents Arcane",
        options=[
            Option("arcane", "Agents Arcane", min_ram_gb=2, description="Supervision"),
            Option("portainer", "Portainer", min_ram_gb=2, description="Gestion Docker"),
        ],
        min_students=1,
        max_students=2,
        critical=False,  # Optionnel
        description="Supervision + GitOps",
    ),

    # --- Équipe 11 : Chaos engineering ---
    Role(
        name="chaos",
        label="Chaos engineering",
        options=[
            Option("chaos", "Chaos", min_ram_gb=1, description="Tests de panne"),
        ],
        min_students=1,
        max_students=2,
        critical=False,  # Optionnel
        description="Tests de résilience",
    ),
]


def get_role(name: str) -> Optional[Role]:
    """Retourne un rôle par son nom."""
    for role in ROLES:
        if role.name == name:
            return role
    return None


def get_critical_roles() -> list[Role]:
    """Retourne les rôles critiques (indispensables)."""
    return [r for r in ROLES if r.critical]


def get_optional_roles() -> list[Role]:
    """Retourne les rôles optionnels."""
    return [r for r in ROLES if not r.critical]
