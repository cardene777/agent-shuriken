#!/usr/bin/env python3
"""Look up the style samples of a styles folder and check that its catalog, style-catalog.json
version 2, names every sample image with its SHA-256.

The styles folder is ~/.styles unless --styles <dir> names another one. The script only reads it.
Exit codes: 0 when the check passes or a lookup succeeds, 1 when the catalog or a sample is wrong
or missing, 2 on an unexpected error.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

CATALOG_NAME = "style-catalog.json"
SCHEMA_VERSION = 2
IMAGE_SUFFIXES = {".png", ".webp", ".jpg", ".jpeg"}
LEGACY_STYLES = {"style1", "style2", "style3", "style4"}


class CatalogError(ValueError):
    """The catalog cannot be used: it is missing, unreadable, or not version 2."""


def styles_dir(value: str | os.PathLike | None = None) -> Path:
    """The styles folder: the --styles value when given, otherwise ~/.styles."""
    return Path(value).expanduser() if value else Path.home() / ".styles"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_catalog(styles=None) -> dict:
    """The catalog as it is written, without checking its version."""
    root = styles_dir(styles)
    path = root / CATALOG_NAME
    if not path.is_file():
        raise CatalogError(
            f"{CATALOG_NAME} is missing from {root}; put the catalog and the sample images under ~/.styles/, "
            "or pass --styles <dir> for another styles folder")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CatalogError(f"cannot read {path}: {error}") from error
    if not isinstance(data, dict):
        raise CatalogError(f"{path} must hold one JSON object")
    return data


def schema_errors(data: dict) -> list[str]:
    """Version 2 has schema_version 2 and no resources anywhere."""
    version = data.get("schema_version")
    if version != SCHEMA_VERSION:
        return [f"schema_version is {version!r}; this skill reads only catalogs with schema_version 2, "
                "and a version 1 catalog is not converted (see references/style-catalog.md)"]
    errors = []
    if "resources" in data:
        errors.append("the catalog holds resources; version 2 catalogs have no resources")
    profiles = data.get("finish_profiles")
    if not isinstance(profiles, dict):
        return errors + ["finish_profiles must be an object"]
    for name, profile in profiles.items():
        if isinstance(profile, dict) and "resources" in profile:
            errors.append(f"finish_profiles.{name} holds resources; version 2 catalogs have no resources")
    if not isinstance(data.get("families"), dict):
        errors.append("families must be an object")
    if not isinstance(data.get("images"), list):
        errors.append("images must be a list")
    if not isinstance(data.get("counts"), dict):
        errors.append("counts must be an object")
    return errors


def load(styles=None) -> dict:
    """The catalog of the styles folder, refused unless it is version 2."""
    data = read_catalog(styles)
    errors = schema_errors(data)
    if errors:
        raise CatalogError("; ".join(errors))
    return data


def normalize_reference(path, styles=None) -> Path:
    value = Path(path).expanduser()
    if value.is_absolute():
        return value.resolve()
    return (styles_dir(styles) / value).resolve()


def lookup(path, data=None, styles=None) -> dict:
    data = data or load(styles)
    root = styles_dir(styles)
    resolved = normalize_reference(path, styles)
    for item in data["images"]:
        candidates = [item["path"], *item["original_paths"]]
        if resolved in [(root / value).resolve() for value in candidates]:
            if not resolved.is_file() or digest(resolved) != item["sha256"]:
                raise CatalogError("registered image changed: " + str(resolved))
            return item
    raise CatalogError("unregistered style sample: " + str(resolved))


def profile_errors(style, finish_profile, *, allow_candidate=False, styles=None) -> list[str]:
    """Check a written finish selection without requiring a sample image."""
    try:
        data = load(styles)
    except CatalogError as error:
        return [str(error)]
    if not isinstance(style, str) or style not in data["families"]:
        return ["unsupported style family: " + str(style)]
    if not isinstance(finish_profile, str) or finish_profile not in data["finish_profiles"]:
        return ["unsupported finish_profile: " + str(finish_profile)]
    profile = data["finish_profiles"][finish_profile]
    if profile.get("status") == "retired":
        return ["retired finish is unavailable for new production: " + finish_profile]
    errors = []
    if profile.get("family") != style:
        errors.append("finish_profile does not belong to the selected family")
    if profile.get("status") == "candidate" and not allow_candidate:
        errors.append("candidate finish requires user selection before production use")
    return errors


def selection_errors(style, reference, finish_profile=None, *, allow_candidate=False, styles=None) -> list[str]:
    try:
        data = load(styles)
    except CatalogError as error:
        return [str(error)]
    if finish_profile is not None and finish_profile not in data["finish_profiles"]:
        return ["unsupported finish_profile: " + str(finish_profile)]
    try:
        item = lookup(reference, data, styles)
    except (OSError, ValueError) as error:
        return [str(error)]
    profile = data["finish_profiles"][item["finish_profile"]]
    if profile.get("status") == "retired":
        return ["retired finish is unavailable for new production: " + str(finish_profile or item["finish_profile"])]
    if profile.get("status") == "candidate" and not allow_candidate:
        return ["candidate finish requires user selection before production use: " + item["finish_profile"]]
    if style not in data["families"]:
        if style not in LEGACY_STYLES:
            return ["unsupported style family: " + str(style)]
        if finish_profile and finish_profile != item["finish_profile"]:
            return ["finish_profile does not match the registered sample"]
        return []
    errors = []
    if item["family"] != style:
        errors.append(f"sample family is {item['family']}, not {style}")
    if not finish_profile or finish_profile != item["finish_profile"]:
        errors.append(f"finish_profile must match sample: {item['finish_profile']}")
    return errors


def image_files(root: Path) -> set[str]:
    """Every image file under the styles folder, as a path relative to it."""
    found = set()
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in files:
            if Path(name).suffix.lower() in IMAGE_SUFFIXES:
                found.add(Path(base, name).relative_to(root).as_posix())
    return found


def validate(data: dict, styles=None) -> list[str]:
    errors = schema_errors(data)
    if errors:
        return errors
    root = styles_dir(styles)
    real_root = root.resolve()
    hashes, paths, ids = set(), set(), set()
    originals = []
    for index, item in enumerate(data["images"], 1):
        if not isinstance(item, dict):
            errors.append(f"image {index} must be an object")
            continue
        ident = str(item.get("id", f"image {index}"))
        if item.get("sha256") in hashes:
            errors.append("duplicate image hash: " + ident)
        hashes.add(item.get("sha256"))
        if ident in ids:
            errors.append("duplicate image id: " + ident)
        ids.add(ident)
        profile = data["finish_profiles"].get(item.get("finish_profile"), {})
        if profile.get("family") != item.get("family"):
            errors.append("family/profile mismatch: " + ident)
        if not item.get("layouts"):
            errors.append("missing independent layout: " + ident)
        item_originals = item.get("original_paths", [])
        if not isinstance(item_originals, list):
            errors.append("original_paths must be a list: " + ident)
            item_originals = []
        originals.extend(item_originals)
        for value in [item.get("path", ""), *item_originals]:
            if not isinstance(value, str) or not value:
                errors.append("empty image path: " + ident)
                continue
            p = (root / value).resolve()
            if not p.is_relative_to(real_root):
                errors.append("path escapes the styles folder: " + value)
                continue
            if value in paths:
                errors.append("path registered twice: " + value)
            paths.add(value)
            if not p.is_file():
                errors.append("missing image: " + value)
            elif digest(p) != item.get("sha256"):
                errors.append("sha256 differs from the catalog: " + value)
    for value in sorted(image_files(root) - paths):
        errors.append("image not named by the catalog: " + value)
    counts = data["counts"]
    if counts.get("source_registrations") != len(originals):
        errors.append(f"counts.source_registrations is {counts.get('source_registrations')!r}, "
                      f"but the catalog names {len(originals)} original paths")
    if counts.get("unique_images") != len(hashes):
        errors.append(f"counts.unique_images is {counts.get('unique_images')!r}, "
                      f"but the catalog holds {len(hashes)} different images")
    for name, profile in data["finish_profiles"].items():
        if not isinstance(profile, dict):
            errors.append("finish profile must be an object: " + name)
            continue
        if profile.get("family") not in data["families"]:
            errors.append("finish profile names an unknown family: " + name)
        for sample_id in profile.get("sample_ids", []):
            if not any(i.get("id") == sample_id and i.get("finish_profile") == name for i in data["images"] if isinstance(i, dict)):
                errors.append("invalid profile sample: " + str(sample_id))
        if not any(i.get("id") == profile.get("reference_id") and i.get("finish_profile") == name for i in data["images"] if isinstance(i, dict)):
            errors.append("invalid profile reference: " + name)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--styles", help="the styles folder to read instead of ~/.styles")
    parser.add_argument("--validate", action="store_true", help="check the catalog against every image in the folder")
    parser.add_argument("--sample", type=Path, help="print the catalog entry of one sample image")
    parser.add_argument("--family")
    parser.add_argument("--profile")
    parser.add_argument("--layout")
    args = parser.parse_args()
    root = styles_dir(args.styles)
    try:
        if args.validate:
            data = read_catalog(args.styles)
            errors = validate(data, args.styles)
            if errors:
                print(f"ERROR: {root}/{CATALOG_NAME}")
                print("\n".join("ERROR: " + e for e in errors))
                return 1
            candidates = sum(p.get("status") == "candidate" for p in data["finish_profiles"].values())
            print(f"PASS: {root}: {len(data['images'])} unique images, {data['counts']['source_registrations']} originals, "
                  f"{len(data['finish_profiles'])} finishes ({candidates} candidate)")
            return 0
        data = load(args.styles)
        if args.sample:
            print(json.dumps(lookup(args.sample, data, args.styles), ensure_ascii=False, indent=2))
            return 0
        matches = [i for i in data["images"]
                   if data["finish_profiles"][i["finish_profile"]].get("status") == "active"
                   and (not args.family or i["family"] == args.family)
                   and (not args.profile or i["finish_profile"] == args.profile)
                   and (not args.layout or args.layout in i["layouts"])]
        if not matches:
            print("ERROR: no matching samples")
            return 1
        for i in matches:
            print(f"{i['family']} / {i['finish_profile']} / {i.get('approval', 'existing-reference')} / {','.join(i['layouts'])}\n{root / i['path']}")
        return 0
    except CatalogError as error:
        print(f"ERROR: {error}")
        return 1
    except (OSError, ValueError, KeyError) as error:
        print(f"ERROR: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
