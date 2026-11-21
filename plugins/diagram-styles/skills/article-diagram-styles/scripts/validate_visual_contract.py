#!/usr/bin/env python3
"""Validate an article-level visual contract and one figure spec against it."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from diagram_sample_catalog import LEGACY_STYLES, selection_errors, profile_errors


# A contract's fixed_style is a family of the built-in styles or of the catalog, or one of these
# older styles, which need a reference image.
CONTRACT_LEGACY_STYLES = {"style1", "style3", "style4"}
REQUIRED_PROFILE_FIELDS = {"paper", "line", "palette"}
FORBIDDEN_PROFILE_FIELDS = {
    "reading_direction",
    "reading_path",
    "layout_pattern",
    "dominant_geometry",
    "subject_scale",
    "label_zone",
    "connector_strategy",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path: Path) -> dict[str, object]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: root must be an object")
    return data


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def approval_state_errors(contract: dict[str, object]) -> list[str]:
    """Keep explicit visual approval separate from delegated production."""
    status = contract.get("status")
    delegated = contract.get("approval_mode") == "delegated-style-selection"
    if status == "user-approved":
        if delegated:
            return ["delegated production must use user-delegated, not user-approved"]
        return []
    if status == "user-delegated":
        errors = []
        if not delegated:
            errors.append("user-delegated requires delegated-style-selection mode")
        for field in ("approval_evidence", "approval_scope"):
            if not nonempty(contract.get(field)):
                errors.append(f"user-delegated requires {field}")
        return errors
    return ["visual contract needs explicit user-approved or evidenced user-delegated status"]


def validate(contract_path: Path, spec_path: Path, styles: str | None = None) -> list[str]:
    errors: list[str] = []
    contract = load(contract_path)
    spec = load(spec_path)

    if not nonempty(contract.get("contract_id")):
        errors.append("contract_id must be a non-empty string")
    errors.extend(approval_state_errors(contract))
    if contract.get("execution_mode") != "sequential-one-figure":
        errors.append("execution_mode must be sequential-one-figure")

    style = contract.get("fixed_style")
    if style in LEGACY_STYLES - CONTRACT_LEGACY_STYLES:
        errors.append(f"fixed_style must be a style family or one of {sorted(CONTRACT_LEGACY_STYLES)}")

    anchor = contract.get("visual_anchor")
    if not isinstance(anchor, dict):
        errors.append("visual_anchor must be an object")
    else:
        anchor_path_value = anchor.get("path")
        anchor_sha = anchor.get("sha256")
        if not nonempty(anchor_path_value) or not nonempty(anchor_sha):
            errors.append("visual_anchor requires path and sha256")
        else:
            anchor_path = (contract_path.parent / str(anchor_path_value)).resolve()
            if not anchor_path.is_file():
                errors.append(f"visual anchor does not exist: {anchor_path_value}")
            elif sha256(anchor_path) != anchor_sha:
                errors.append("visual anchor SHA-256 does not match the approved image")

    style_reference = contract.get("style_reference")
    if style_reference is not None:
        if not nonempty(style_reference) or not Path(str(style_reference)).is_file():
            errors.append("provided style_reference must point to an existing registered sample")
        errors.extend(selection_errors(style, str(style_reference), contract.get("finish_profile"), styles=styles))
    elif style in LEGACY_STYLES:
        errors.append("legacy style requires a reference; new contracts use a family and finish_profile")
    else:
        errors.extend(profile_errors(style, contract.get("finish_profile"), styles=styles))

    profile = contract.get("visual_profile")
    if not isinstance(profile, dict):
        errors.append("visual_profile must be an object")
    else:
        missing = sorted(field for field in REQUIRED_PROFILE_FIELDS if not nonempty(profile.get(field)))
        if missing:
            errors.append(f"visual_profile missing fields: {', '.join(missing)}")
        if contract.get("schema_version", 1) == 2 and "object_density" in profile:
            errors.append("new visual profiles must not freeze object_density")
        fixed_composition = sorted(field for field in FORBIDDEN_PROFILE_FIELDS if field in profile)
        if fixed_composition:
            errors.append(
                "visual_profile must not freeze figure composition: " + ", ".join(fixed_composition)
            )

    composition_policy = contract.get("composition_policy")
    if not isinstance(composition_policy, dict):
        errors.append("composition_policy must be an object")
    else:
        if composition_policy.get("layout_varies_by_claim") is not True:
            errors.append("composition_policy.layout_varies_by_claim must be true")
        prohibited = composition_policy.get("prohibited_repetition")
        if not isinstance(prohibited, list) or not prohibited or not all(nonempty(item) for item in prohibited):
            errors.append("composition_policy.prohibited_repetition must be a non-empty string list")

    criteria = contract.get("rejection_criteria")
    if not isinstance(criteria, list) or not criteria or not all(nonempty(item) for item in criteria):
        errors.append("rejection_criteria must be a non-empty string list")

    expected_contract_sha = sha256(contract_path)
    checks = {
        "visual_contract_id": contract.get("contract_id"),
        "visual_contract_sha256": expected_contract_sha,
        "fixed_style": style,
        "style_reference": style_reference,
    }
    if style not in LEGACY_STYLES:
        checks["finish_profile"] = contract.get("finish_profile")
    for field, expected in checks.items():
        if spec.get(field) != expected:
            errors.append(f"figure spec {field} must match the approved visual contract")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--figure-spec", type=Path, required=True)
    parser.add_argument("--styles", help="the styles folder to read instead of ~/.styles")
    args = parser.parse_args()
    try:
        errors = validate(args.contract.resolve(), args.figure_spec.resolve(), args.styles)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("visual contract valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
