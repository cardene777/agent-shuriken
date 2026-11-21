#!/usr/bin/env python3
"""Validate article-level composition diversity and figure-spec alignment.

Every figure of the ledger and its figure spec name the same figure structure in `structure`, one
of the structures in use: built in, or in the catalog of the styles folder (~/.styles unless
--styles names another one), and not retired. The `structure-comparison` mode draws the same
content in two or more different structures at the user's request. Exit codes: 0 when the ledger
passes, 1 when it does not, 2 when a file cannot be read.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from diagram_sample_catalog import CatalogError, structure_errors, structures_view


SIGNATURE_FIELDS = {
    "dominant_geometry",
    "subject_scale",
    "label_zone",
    "connector_strategy",
}
ALLOWED_GEOMETRIES = {
    "strip",
    "radial",
    "cycle",
    "staircase",
    "layered",
    "split",
    "convergence",
    "matrix",
    "boundary",
    "cutaway",
}
ALLOWED_SCALES = {"single-dominant", "paired", "ensemble", "overview"}
ALLOWED_LABEL_ZONES = {"embedded", "side", "top", "bottom", "mixed"}
ALLOWED_CONNECTORS = {
    "none",
    "direct",
    "branching",
    "loop",
    "converging",
    "boundary-crossing",
    "annotated",
}


def load(path: Path) -> dict[str, object]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: root must be an object")
    return data


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def allowed_or_custom(value: object, allowed: set[str]) -> bool:
    return nonempty(value) and (value in allowed or str(value).startswith("custom-"))


def comparison_errors(ledger: dict, entries: list) -> list[str]:
    """A structure comparison is asked for, holds two or more figures, and draws each structure once."""
    errors = []
    if not nonempty(ledger.get("comparison_request")):
        errors.append("structure-comparison requires the user's words that asked for it in comparison_request")
    if len(entries) < 2:
        errors.append(f"structure-comparison compares two or more figures of the same content, not {len(entries)}")
    first: dict[str, int] = {}
    for index, entry in enumerate(entries, 1):
        name = entry.get("structure") if isinstance(entry, dict) else None
        if not nonempty(name):
            continue
        if name in first:
            errors.append(f"structure-comparison draws each structure once, but entries {first[name]} and {index} both use {name}")
        first.setdefault(name, index)
    return errors


def validate(ledger_path: Path, styles: str | None = None) -> list[str]:
    errors: list[str] = []
    ledger = load(ledger_path)
    try:
        structures = structures_view(styles)
    except CatalogError as error:
        errors.append(str(error))
        structures = None
    contract_id = ledger.get("visual_contract_id")
    contract_ids = ledger.get("visual_contract_ids", [contract_id] if nonempty(contract_id) else [])
    if not isinstance(contract_ids, list) or not contract_ids or not all(nonempty(value) for value in contract_ids):
        errors.append("visual_contract_id or a non-empty visual_contract_ids list is required")
        contract_ids = []
    elif len(contract_ids) != len(set(contract_ids)):
        errors.append("visual_contract_ids must be unique")

    entries = ledger.get("entries")
    if not isinstance(entries, list) or not entries:
        return errors + ["entries must be a non-empty list"]

    signatures: list[dict[str, str]] = []
    geometries: set[str] = set()
    label_zones: set[str] = set()
    connectors: set[str] = set()

    for index, entry in enumerate(entries, start=1):
        prefix = f"entry {index}"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        spec_value = entry.get("figure_spec")
        for field in ("layout_pattern", "semantic_structure", "reading_path"):
            if not nonempty(entry.get(field)):
                errors.append(f"{prefix} {field} must be a non-empty string")
        if structures is not None:
            errors.extend(f"{prefix} {error}" for error in structure_errors(entry.get("structure"), structures))

        signature = entry.get("composition_signature")
        if not isinstance(signature, dict):
            errors.append(f"{prefix} composition_signature must be an object")
            continue
        missing = sorted(field for field in SIGNATURE_FIELDS if not nonempty(signature.get(field)))
        if missing:
            errors.append(f"{prefix} composition_signature missing: {', '.join(missing)}")
            continue

        normalized = {field: str(signature[field]) for field in SIGNATURE_FIELDS}
        if not allowed_or_custom(normalized["dominant_geometry"], ALLOWED_GEOMETRIES):
            errors.append(f"{prefix} has an unsupported dominant_geometry")
        if normalized["subject_scale"] not in ALLOWED_SCALES:
            errors.append(f"{prefix} has an unsupported subject_scale")
        if normalized["label_zone"] not in ALLOWED_LABEL_ZONES:
            errors.append(f"{prefix} has an unsupported label_zone")
        if normalized["connector_strategy"] not in ALLOWED_CONNECTORS:
            errors.append(f"{prefix} has an unsupported connector_strategy")
        signatures.append(normalized)
        geometries.add(normalized["dominant_geometry"])
        label_zones.add(normalized["label_zone"])
        connectors.add(normalized["connector_strategy"])

        if not nonempty(spec_value):
            errors.append(f"{prefix} figure_spec must be a non-empty string")
            continue
        spec_path = (ledger_path.parent / str(spec_value)).resolve()
        if not spec_path.is_file():
            errors.append(f"{prefix} figure_spec does not exist: {spec_value}")
            continue
        spec = load(spec_path)
        if spec.get("visual_contract_id") not in contract_ids:
            errors.append(f"{prefix} figure spec visual_contract_id does not match ledger")
        if "visual_contract_id" in entry and entry["visual_contract_id"] != spec.get("visual_contract_id"):
            errors.append(f"{prefix} entry contract must match its figure spec")
        for field in ("layout_pattern", "semantic_structure", "reading_path", "composition_signature", "structure"):
            if spec.get(field) != entry.get(field):
                errors.append(f"{prefix} figure spec {field} does not match ledger")

    # Repeated geometry can be the clearest representation of different claims.
    # Reject duplicated content, not a failure to meet an arbitrary shape quota.
    # A comparison draws the same content on purpose: in other styles or in other structures.
    seen = set()
    mode = ledger.get("mode")
    comparison = mode in ("style-comparison", "structure-comparison")
    if mode == "style-comparison" and (not nonempty(ledger.get("comparison_request")) or ledger.get("same_content_requested") is not True):
        errors.append("style-comparison requires the explicit comparison request and same_content_requested=true")
    if mode == "structure-comparison":
        errors.extend(comparison_errors(ledger, entries))
    for index, entry in enumerate(entries, 1):
        if not isinstance(entry, dict):
            continue
        meaning = (entry.get("semantic_structure"), entry.get("reading_path"))
        if all(nonempty(value) for value in meaning):
            if meaning in seen and not comparison:
                errors.append(f"entry {index} duplicates an existing article figure's meaning and reading path")
            seen.add(meaning)

    return errors


def summary(ledger: dict) -> str:
    """The line printed when the ledger passes: how many figures, and the structures they use."""
    entries = ledger["entries"]
    names = ", ".join(dict.fromkeys(str(entry["structure"]) for entry in entries))
    if ledger.get("mode") == "structure-comparison":
        return f"composition ledger valid: structure-comparison of {len(entries)} structures: {names}"
    return f"composition ledger valid: {len(entries)} figure(s); structures used: {names}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--styles", help="the styles folder to read instead of ~/.styles")
    args = parser.parse_args()
    try:
        errors = validate(args.ledger.resolve(), args.styles)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(summary(load(args.ledger.resolve())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
