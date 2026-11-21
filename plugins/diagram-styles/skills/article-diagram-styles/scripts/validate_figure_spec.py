#!/usr/bin/env python3
"""Validate an article figure specification, drawn from source (deterministic) or by the image
generation of the agent (generated)."""

from __future__ import annotations

import argparse
import json
import sys
import re
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path


RENDERING_MODES = {"deterministic", "generated"}
EXACT_KINDS = {"identifier", "type", "field", "state", "number", "code", "structured-data"}
ALLOWED_KINDS = EXACT_KINDS | {"prose"}
ALLOWED_RELATION_KINDS = {
    "data-flow",
    "state-transition",
    "authorization",
    "call",
    "return",
    "dependency",
    "containment",
    "comparison",
    "illustrative-handoff",
    "visual-association",
}


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(spec: object, spec_path: Path) -> list[str]:
    if not isinstance(spec, dict):
        return ["figure spec root must be an object"]

    errors: list[str] = []
    mode = spec.get("rendering_mode")
    exact = spec.get("exact_content")
    if mode not in RENDERING_MODES:
        errors.append(f"rendering_mode must be deterministic or generated, not {mode!r}")
    if not isinstance(exact, bool):
        errors.append("exact_content must be a boolean")

    source_file = spec.get("source_file")
    if mode == "deterministic":
        if not nonempty(source_file) or Path(str(source_file)).suffix.lower() not in {".html", ".svg"}:
            errors.append("deterministic figures require an HTML or SVG source_file")
        elif not (spec_path.parent / str(source_file)).is_file():
            errors.append(f"source_file does not exist: {source_file}")

    if mode == "generated" and exact is True:
        if not nonempty(source_file) or Path(str(source_file)).suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            errors.append("exact generated figures require a raster source_file")
        elif not (spec_path.parent / str(source_file)).is_file():
            errors.append(f"source_file does not exist: {source_file}")
        prompt = spec.get("generation_prompt_file")
        if not nonempty(prompt) or not (spec_path.parent / str(prompt)).is_file():
            errors.append("generated figures require an existing generation_prompt_file")
        elif not (spec_path.parent / str(prompt)).read_text(encoding="utf-8").strip():
            errors.append("generation_prompt_file must not be empty")

    facts = spec.get("facts")
    if not isinstance(facts, list) or not facts:
        errors.append("facts must be a non-empty list")
        return errors

    has_exact_fact = False
    for index, fact in enumerate(facts, start=1):
        if not isinstance(fact, dict):
            errors.append(f"fact {index} must be an object")
            continue
        for field in ("text", "kind", "source", "locator"):
            if not nonempty(fact.get(field)):
                errors.append(f"fact {index} missing {field}")
        kind = fact.get("kind")
        if kind not in ALLOWED_KINDS:
            errors.append(f"fact {index} kind must be one of {sorted(ALLOWED_KINDS)}")
        if kind in EXACT_KINDS:
            has_exact_fact = True

    relations = spec.get("relations")
    has_exact_relation = False
    if not isinstance(relations, list) or not relations:
        errors.append("relations must be a non-empty list")
    else:
        for index, relation in enumerate(relations, start=1):
            if not isinstance(relation, dict):
                errors.append(f"relation {index} must be an object")
                continue
            for field in ("from", "to", "kind", "source", "locator"):
                if not nonempty(relation.get(field)):
                    errors.append(f"relation {index} missing {field}")
            if not isinstance(relation.get("exact"), bool):
                errors.append(f"relation {index} exact must be a boolean")
            kind = relation.get("kind")
            if kind not in ALLOWED_RELATION_KINDS:
                errors.append(f"relation {index} kind must be one of {sorted(ALLOWED_RELATION_KINDS)}")
            if relation.get("exact") is True:
                has_exact_relation = True

    if (has_exact_fact or has_exact_relation) and exact is not True:
        errors.append("exact_content must be true when exact facts or relations are present")

    return errors


def source_label_errors(spec: object, spec_path: Path) -> list[str]:
    """Check source bindings, not raster visibility or visual quality."""
    if not isinstance(spec, dict) or spec.get("rendering_mode") != "deterministic":
        return []
    value = spec.get("source_file")
    if not isinstance(value, str):
        return []  # The schema validator reports this error.
    source = spec_path.parent / value
    if not source.is_file():
        return []
    labels: set[str] = set()
    normalize = lambda value: re.sub(r"\s+", " ", value).strip()
    try:
        if source.suffix.lower() == ".svg":
            tree = ET.fromstring(source.read_text(encoding="utf-8"))
            for element in tree.iter():
                kind = element.tag.rsplit("}", 1)[-1]
                if kind in {"text", "tspan"}:
                    text = normalize("".join(element.itertext()))
                    if text:
                        labels.add(text)
                name = element.get("aria-label")
                children = list(element.iter())
                literal_text = any(
                    child.tag.rsplit("}", 1)[-1] in {"text", "tspan"}
                    and "".join(child.itertext()).strip()
                    for child in children
                )
                glyph_shapes = any(
                    child.tag.rsplit("}", 1)[-1] in {"path", "use", "image"}
                    and (child.get("d", "").strip() or child.get("href"))
                    for child in children
                )
                # A glyph-only group may declare its text binding. Literal
                # text takes priority: aria-label must never hide wrong text.
                if name and glyph_shapes and not literal_text:
                    labels.add(normalize(name))
        else:
            class SourceText(HTMLParser):
                voids = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
                def __init__(self):
                    super().__init__(); self.ignore = 0; self.stack = []
                def handle_starttag(self, tag, attrs):
                    if tag in {"script", "style"}:
                        self.ignore += 1
                    if not self.ignore and tag not in self.voids:
                        self.stack.append((tag, []))
                def handle_endtag(self, tag):
                    if tag in {"script", "style"}:
                        self.ignore = max(0, self.ignore - 1)
                        return
                    if self.ignore:
                        return
                    for index in range(len(self.stack) - 1, -1, -1):
                        if self.stack[index][0] == tag:
                            for _, chunks in self.stack[index:]:
                                labels.add(normalize("".join(chunks)))
                            del self.stack[index:]
                            break
                def handle_data(self, data):
                    if not self.ignore:
                        labels.add(normalize(data))
                        for _, chunks in self.stack:
                            chunks.append(data)
            parser = SourceText(); parser.feed(source.read_text(encoding="utf-8")); parser.close()
            for _, chunks in parser.stack:
                labels.add(normalize("".join(chunks)))
    except (OSError, ET.ParseError, UnicodeError) as error:
        return [f"cannot inspect source labels: {error}"]
    errors = []
    for index, fact in enumerate(spec.get("facts", []), start=1):
        if not isinstance(fact, dict) or not isinstance(fact.get("text"), str):
            continue
        text = normalize(fact["text"])
        if not text or text not in labels:
            errors.append(f"fact {index} has no source text/glyph label binding: {fact['text']}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", type=Path)
    parser.add_argument("--require-source-labels", action="store_true", help="Require source text or glyph-group bindings for every fact; does not judge visual quality")
    args = parser.parse_args()
    try:
        data = json.loads(args.spec.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"error: cannot read figure spec: {error}", file=sys.stderr)
        return 1

    errors = validate(data, args.spec)
    if args.require_source_labels:
        errors.extend(source_label_errors(data, args.spec))
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1
    print("figure spec valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
