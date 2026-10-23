#!/usr/bin/env python3
"""FARCI — moteur de casting des équipes.

Principe :
1. Les rôles critiques sont assignés en premier (choix n°1 garanti)
2. Les redondances sont assignées ensuite (stacks alternatives)
3. La stratification se fait par puissance machine (RAM, GPU, Mac)

Le système est agnostique du nombre d'étudiant et des possibilités de chaque brique.
"""

from __future__ import annotations

import json
import random
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from roles import ROLES, Role, Option, get_critical_roles, get_optional_roles


@dataclass
class Student:
    """Un étudiant avec ses specs machine."""
    name: str
    ram_gb: int = 8
    has_gpu: bool = False
    vram_gb: int = 0
    has_mac: bool = False
    is_mac_studio: bool = False  # Mac avec beaucoup de RAM

    def can_run(self, option: Option) -> bool:
        """Vérifie si l'étudiant peut exécuter cette option."""
        if option.requires_mac and not self.has_mac:
            return False
        if self.ram_gb < option.min_ram_gb:
            return False
        if option.requires_gpu and not self.has_gpu:
            return False
        if option.min_vram_gb > 0 and self.vram_gb < option.min_vram_gb:
            return False
        return True

    @property
    def power_score(self) -> int:
        """Score de puissance machine (pour stratification)."""
        score = self.ram_gb
        if self.has_gpu:
            score += self.vram_gb * 2
        if self.has_mac:
            score += 4  # Bonus Mac (oMLX possible)
        return score


@dataclass
class Assignment:
    """Une assignation étudiant → rôle → option."""
    student: Student
    role: Role
    option: Option
    is_primary: bool = False  # True = choix n°1

    def to_dict(self) -> dict:
        return {
            "student": self.student.name,
            "role": self.role.name,
            "role_label": self.role.label,
            "option": self.option.name,
            "option_label": self.option.label,
            "is_primary": self.is_primary,
        }


@dataclass
class CastingResult:
    """Résultat du casting."""
    assignments: list[Assignment] = field(default_factory=list)
    unassigned: list[Student] = field(default_factory=list)
    # Rôles cœur sans aucun étudiant : le formateur les sert depuis sa pile
    # de référence. Le dire AVANT la séance évite de le découvrir à 0:45.
    uncovered: list[Role] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "assignments": [a.to_dict() for a in self.assignments],
            "unassigned": [s.name for s in self.unassigned],
            "uncovered": [r.name for r in self.uncovered],
        }

    def summary(self) -> str:
        """Résumé lisible du casting."""
        lines = ["# FARCI — Casting des équipes", ""]

        # Grouper par rôle
        by_role: dict[str, list[Assignment]] = {}
        for a in self.assignments:
            by_role.setdefault(a.role.name, []).append(a)

        for role_name, role_assignments in by_role.items():
            role = role_assignments[0].role
            lines.append(f"## {role.label}")
            for a in role_assignments:
                primary = "⭐" if a.is_primary else "  "
                lines.append(f"  {primary} {a.student.name} → {a.option.label}")
            lines.append("")

        if self.uncovered:
            lines.append("## Briques cœur sans équipe (servies par le formateur)")
            for role in self.uncovered:
                lines.append(f"  ! {role.label}")
            lines.append("")

        if self.unassigned:
            lines.append("## Non assignés")
            for s in self.unassigned:
                lines.append(f"  - {s.name}")
            lines.append("")

        return "\n".join(lines)


def cast_teams(
    students: list[Student],
    seed: Optional[int] = None,
    include_optional: bool = True,
) -> CastingResult:
    """Effectue le casting des équipes.

    Args:
        students: liste des étudiants avec leurs specs
        seed: graine aléatoire (pour reproductibilité)
        include_optional: inclure les rôles optionnels

    Returns:
        CastingResult avec les assignations
    """
    if seed is not None:
        random.seed(seed)

    # Trier les étudiants par puissance (décroissant)
    sorted_students = sorted(students, key=lambda s: s.power_score, reverse=True)

    result = CastingResult()
    assigned_students: set[str] = set()

    # 1. Assigner les rôles critiques (choix n°1)
    for role in get_critical_roles():
        # Trouver les étudiants qui peuvent exécuter l'option principale
        eligible = [
            s for s in sorted_students
            if s.name not in assigned_students and s.can_run(role.primary_option)
        ]

        # Assigner le nombre requis
        for student in eligible[:role.min_students]:
            result.assignments.append(Assignment(
                student=student,
                role=role,
                option=role.primary_option,
                is_primary=True,
            ))
            assigned_students.add(student.name)

    # 2. Assigner les redondances (stacks alternatives)
    for role in get_critical_roles():
        primary_count = sum(1 for a in result.assignments if a.role.name == role.name)
        needed = role.max_students - primary_count

        if needed <= 0:
            continue

        # Trouver les étudiants non assignés
        eligible = [
            s for s in sorted_students
            if s.name not in assigned_students
        ]

        # Assigner les options alternatives d'abord, puis l'option principale
        for option in role.options[1:] + [role.primary_option]:
            for student in eligible:
                if student.name in assigned_students:
                    continue
                if not student.can_run(option):
                    continue

                result.assignments.append(Assignment(
                    student=student,
                    role=role,
                    option=option,
                    is_primary=(option == role.primary_option),
                ))
                assigned_students.add(student.name)
                needed -= 1

                if needed <= 0:
                    break
            if needed <= 0:
                break

    # 3. Assigner les rôles optionnels (si demandé)
    if include_optional:
        for role in get_optional_roles():
            eligible = [
                s for s in sorted_students
                if s.name not in assigned_students and s.can_run(role.primary_option)
            ]

            for student in eligible[:role.min_students]:
                result.assignments.append(Assignment(
                    student=student,
                    role=role,
                    option=role.primary_option,
                    is_primary=True,
                ))
                assigned_students.add(student.name)

    # 4. Étudiants non assignés, rôles cœur non couverts
    result.unassigned = [s for s in students if s.name not in assigned_students]
    covered = {a.role.name for a in result.assignments}
    result.uncovered = [r for r in get_critical_roles() if r.name not in covered]

    return result


def main():
    import argparse

    parser = argparse.ArgumentParser(description="FARCI — casting des équipes")
    parser.add_argument("--students", type=Path, help="Fichier JSON des étudiants")
    parser.add_argument("--seed", type=int, default=None, help="Graine aléatoire")
    parser.add_argument("--output", type=Path, default=None, help="Fichier de sortie")
    parser.add_argument("--no-optional", action="store_true", help="Exclure les rôles optionnels")
    args = parser.parse_args()

    # Charger les étudiants
    if args.students:
        with open(args.students, "r", encoding="utf-8") as f:
            data = json.load(f)
        students = [Student(**s) for s in data]
    else:
        # Exemple par défaut
        students = [
            Student("Alice", ram_gb=32, has_mac=True, is_mac_studio=True),
            Student("Bob", ram_gb=16, has_gpu=True, vram_gb=24),
            Student("Charlie", ram_gb=16, has_gpu=True, vram_gb=12),
            Student("Diana", ram_gb=8),
            Student("Eve", ram_gb=8),
            Student("Frank", ram_gb=4),
        ]

    # Effectuer le casting
    result = cast_teams(students, seed=args.seed, include_optional=not args.no_optional)

    # Afficher le résultat
    print(result.summary())

    # Sauvegarder
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(result.to_dict(), f, ensure_ascii=False, indent=2)
        print(f"\nRésultat sauvegardé : {args.output}")


if __name__ == "__main__":
    main()
