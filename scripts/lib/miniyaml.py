#!/usr/bin/env python3
"""FARCI — lecture d'un sous-ensemble restreint de YAML, sans dépendance externe.

Pourquoi ne pas utiliser PyYAML ? Parce qu'un atelier air-gappé ne peut pas
supposer que quoi que ce soit soit installé. Le format accepté est documenté
dans config/services.yaml et volontairement minimal :

  - indentation de 2 espaces (les tabs sont rejetés)
  - mappings        cle: valeur
  - mappings vides  cle:            puis indented
  - listes          - element
  - liste d'objets  - cle: valeur  puis clés suivantes alignées
  - scalaires       "guillemets", 'apostrophes', 123, 1.5, true/false, null/~
  - séquence courte [a, b, c]      (scalaires uniquement, un seul niveau)
  - commentaires    lignes commençant par #, ou " #" après une valeur non citée

Volontairement NON supporté (et rejeté par un message explicite) : ancres,
alias, clés complexes, valeurs multilignes, documents multiples.

Auto-test :  python3 scripts/lib/miniyaml.py --selftest
"""

from __future__ import annotations

import json
import sys
from typing import Any

__all__ = ["loads", "load", "MiniYamlError"]


class MiniYamlError(ValueError):
    """Ligne invalide dans un document du sous-ensemble accepté."""


_BOOL_TRUE = {"true", "yes", "on"}
_BOOL_FALSE = {"false", "no", "off"}
_NULL = {"null", "~", ""}


class _Line:
    __slots__ = ("no", "indent", "text")

    def __init__(self, no: int, indent: int, text: str) -> None:
        self.no = no
        self.indent = indent
        self.text = text

    def __repr__(self) -> str:  # pragma: no cover - confort de débogage
        return f"_Line(no={self.no}, indent={self.indent}, text={self.text!r})"


def _strip_comment(raw: str) -> str:
    """Retire un commentaire de fin, sans casser les valeurs citées."""
    out: list[str] = []
    quote: str | None = None
    i = 0
    while i < len(raw):
        ch = raw[i]
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#" and (i == 0 or raw[i - 1] in " \t"):
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out).rstrip()


def _flow_sequence(token: str, where: str) -> list[Any]:
    """Séquence en ligne [a, b, "c"] : uniquement des scalaires, un niveau.

    Les imbrications sont refusées volontairement : au-delà, on writes du code
    plutôt que de la configuration.
    """
    inner = token[1:-1].strip()
    if not inner:
        return []
    items: list[Any] = []
    for part in inner.split(","):
        part = part.strip()
        if not part:
            raise MiniYamlError(f"{where}: élément vide dans une séquence en ligne")
        if "[" in part or "]" in part or "{" in part or "}" in part:
            raise MiniYamlError(
                f"{where}: séquence en ligne trop imbriquée -> {part!r} "
                "(écrivez-la sur plusieurs lignes)"
            )
        items.append(_scalar(part))
    return items


def _scalar(token: str, where: str = "<yaml>") -> Any:
    token = token.strip()
    if token.startswith("[") and token.endswith("]"):
        return _flow_sequence(token, where)
    if len(token) >= 2 and token[0] == token[-1] and token[0] in "\"'":
        body = token[1:-1]
        if token[0] == '"':
            body = body.replace('\\"', '"').replace("\\\\", "\\")
        return body
    low = token.lower()
    if low in _NULL:
        return None
    if low in _BOOL_TRUE:
        return True
    if low in _BOOL_FALSE:
        return False
    try:
        return int(token)
    except ValueError:
        pass
    try:
        return float(token)
    except ValueError:
        pass
    return token


def _split_key(text: str) -> tuple[str, str] | None:
    """Sépare 'cle: valeur' en ignorant les deux-points dans du texte cité."""
    quote: str | None = None
    for i, ch in enumerate(text):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == ":" and (i + 1 == len(text) or text[i + 1] in " \t"):
            return text[:i].strip(), text[i + 1 :].strip()
    return None


class _Parser:
    def __init__(self, text: str, source: str = "<string>") -> None:
        self.source = source
        self.lines: list[_Line] = []
        for no, raw in enumerate(text.splitlines(), start=1):
            if "\t" in raw.split("#", 1)[0]:
                raise MiniYamlError(f"{source}:{no}: tabulation interdite (utiliser des espaces)")
            body = _strip_comment(raw).rstrip()
            if not body.strip():
                continue
            indent = len(body) - len(body.lstrip(" "))
            self.lines.append(_Line(no, indent, body.strip()))
        self.pos = 0

    # -- helpers ---------------------------------------------------------
    def peek(self) -> _Line | None:
        return self.lines[self.pos] if self.pos < len(self.lines) else None

    def fail(self, line: _Line, reason: str) -> None:
        raise MiniYamlError(f"{self.source}:{line.no}: {reason} -> {line.text!r}")

    @staticmethod
    def _where(line: _Line) -> str:
        return f"<ligne {line.no}>"

    # -- grammar ---------------------------------------------------------
    def parse(self) -> Any:
        first = self.peek()
        if first is None:
            return {}
        if first.text.startswith("- "):
            return self.parse_list(first.indent)
        return self.parse_map(first.indent)

    def parse_map(self, indent: int) -> dict[str, Any]:
        result: dict[str, Any] = {}
        while True:
            line = self.peek()
            if line is None or line.indent < indent:
                return result
            if line.indent > indent:
                self.fail(line, f"indentation inattendue ({line.indent} > {indent})")
            if line.text.startswith("- "):
                return result
            pair = _split_key(line.text)
            if pair is None:
                self.fail(line, "ligne attendue 'cle: valeur'")
            key, value = pair
            if not key:
                self.fail(line, "clé vide")
            if key in result:
                self.fail(line, f"clé dupliquée {key!r}")
            self.pos += 1
            if value == "":
                nxt = self.peek()
                if nxt is not None and (
                    nxt.indent > indent or (nxt.indent == indent and nxt.text.startswith("- "))
                ):
                    result[key] = (
                        self.parse_list(nxt.indent)
                        if nxt.text.startswith("- ")
                        else self.parse_map(nxt.indent)
                    )
                else:
                    result[key] = None
            else:
                result[key] = _scalar(value, self._where(line))

    def parse_list(self, indent: int) -> list[Any]:
        result: list[Any] = []
        while True:
            line = self.peek()
            if line is None or line.indent < indent:
                return result
            if line.indent > indent:
                self.fail(line, f"indentation inattendue dans une liste ({line.indent} > {indent})")
            if not line.text.startswith("- "):
                if line.text == "-":
                    self.fail(line, "élément de liste vide")
                return result
            self.pos += 1
            item_text = line.text[2:].strip()
            pair = _split_key(item_text)
            if pair is None:
                result.append(_scalar(item_text, self._where(line)))
                continue
            # Objet d'une liste : la première clé est sur la ligne du tiret,
            # les suivantes sont alignées sur cette clé.
            key, value = pair
            item: dict[str, Any] = {}
            if value == "":
                nxt = self.peek()
                if nxt is not None and nxt.indent > line.indent + 2:
                    item[key] = self.parse_map(nxt.indent)
                else:
                    item[key] = None
            else:
                item[key] = _scalar(value, self._where(line))
            key_indent = line.indent + 2
            nxt = self.peek()
            if nxt is not None and nxt.indent == key_indent and not nxt.text.startswith("- "):
                item.update(self.parse_map(key_indent))
            result.append(item)


def loads(text: str, source: str = "<string>") -> Any:
    return _Parser(text, source).parse()


def load(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return loads(handle.read(), path)


# --------------------------------------------------------------------------
# Auto-test
# --------------------------------------------------------------------------
_SAMPLE = """
# commentaire
meta:
  schema_version: 1
  network_name: farci   # commentaire de fin
groups:
  A: Alpha
  B: "Beta: avec deux-points"
services:
  - id: gitea
    label: Gitea
    critical: true
    phase: 2
    health_paths:
      - /api/healthz
      - /healthz
  - id: inference
    label: Inference A
    critical: false
    health_paths:
      - /v1/models
status_rows:
  - label: GitOps
    check: [gitea]
vides:
empty: 
quoted:
  - "0"
  - 0
  - true
  - null
"""

_EXPECTED = {
    "meta": {"schema_version": 1, "network_name": "farci"},
    "groups": {"A": "Alpha", "B": "Beta: avec deux-points"},
    "services": [
        {
            "id": "gitea",
            "label": "Gitea",
            "critical": True,
            "phase": 2,
            "health_paths": ["/api/healthz", "/healthz"],
        },
        {
            "id": "inference",
            "label": "Inference A",
            "critical": False,
            "health_paths": ["/v1/models"],
        },
    ],
    "status_rows": [{"label": "GitOps", "check": ["gitea"]}],
    "vides": None,
    "empty": None,
    "quoted": ["0", 0, True, None],
}


def _selftest() -> int:
    got = loads(_SAMPLE, "<selftest>")
    if got != _EXPECTED:
        print("ECHEC selftest miniyaml", file=sys.stderr)
        print(json.dumps(got, indent=2, ensure_ascii=False), file=sys.stderr)
        return 1
    try:
        loads("a: 1\n\tb: 2\n", "<bad>")
    except MiniYamlError:
        pass
    else:
        print("ECHEC : une tabulation devrait être refusée", file=sys.stderr)
        return 1
    try:
        loads("a: 1\na: 2\n", "<bad>")
    except MiniYamlError:
        pass
    else:
        print("ECHEC : une clé dupliquée devrait être refusée", file=sys.stderr)
        return 1
    print("selftest miniyaml : OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(64)
    data = load(sys.argv[1])
    if "--json" in sys.argv:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print(json.dumps(data, ensure_ascii=False, sort_keys=True))
