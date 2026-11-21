#!/usr/bin/env python3
"""Look up the drawing styles and the figure structures and check them: the built-in styles this
skill ships as written specifications in data/built-in-styles.json, the built-in figure structures
it ships as written definitions in data/built-in-structures.json, and the style catalog of a styles
folder, style-catalog.json version 2, which names every sample image with its SHA-256.

A style of the catalog sits beside the built-in styles. A style with a built-in name is laid over
the built-in one: the fields the catalog writes replace the built-in fields, so it replaces the
built-in style of the same name, and "status": "retired" alone takes that built-in style out of use.
The optional "structures" object of the catalog follows the same rules for the figure structures.

The styles folder is ~/.styles unless --styles <dir> names another one. The script only reads it.
Without ~/.styles/style-catalog.json the built-in styles are used alone; a folder named with
--styles must hold a catalog.
Exit codes: 0 when the check passes or a lookup succeeds, 1 when the catalog, a sample, or a
named style is wrong or missing, 2 on an unexpected error.
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
BUILT_IN_FILE = Path(__file__).resolve().parent.parent / "data" / "built-in-styles.json"
BUILT_IN_VERSION = 1
WRITTEN_FIELDS = ("label", "line", "fill", "background", "lettering")
STRUCTURES_FILE = Path(__file__).resolve().parent.parent / "data" / "built-in-structures.json"
STRUCTURES_VERSION = 1
STRUCTURE_FIELDS = ("group", "label", "shows", "parts", "reading_order", "fits", "misfits")
STRUCTURES_HINT = "--structures prints the structures in use"


class CatalogError(ValueError):
    """The styles or the structures cannot be used: the catalog is missing, unreadable, or not
    version 2, its structures lack their written definition, or the built-in files cannot be read."""


def styles_dir(value: str | os.PathLike | None = None) -> Path:
    """The styles folder: the --styles value when given, otherwise ~/.styles."""
    return Path(value).expanduser() if value else Path.home() / ".styles"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def built_in() -> dict:
    """The built-in styles as the skill ships them: their families and their finish profiles."""
    try:
        data = json.loads(BUILT_IN_FILE.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CatalogError(f"cannot read the built-in styles {BUILT_IN_FILE}: {error}") from error
    if not isinstance(data, dict) or data.get("version") != BUILT_IN_VERSION \
            or not isinstance(data.get("families"), dict) or not isinstance(data.get("finish_profiles"), dict):
        raise CatalogError(f"{BUILT_IN_FILE} is not version {BUILT_IN_VERSION} with families and finish_profiles")
    return data


def built_in_errors(data: dict) -> list[str]:
    """Every built-in style is active, belongs to a built-in family, and has its written specification."""
    errors = []
    for name, profile in data["finish_profiles"].items():
        if profile.get("family") not in data["families"]:
            errors.append(f"built-in style {name} names an unknown family")
        if profile.get("status") != "active":
            errors.append(f"built-in style {name} is not active")
        for key in WRITTEN_FIELDS:
            if not isinstance(profile.get(key), str) or not profile[key].strip():
                errors.append(f"built-in style {name} has no {key}")
        suits = profile.get("suits")
        if not isinstance(suits, list) or not suits:
            errors.append(f"built-in style {name} has no suits")
    return errors


def written(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def built_in_structures() -> dict:
    """The built-in figure structures as the skill ships them: their groups and their structures."""
    try:
        data = json.loads(STRUCTURES_FILE.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CatalogError(f"cannot read the built-in structures {STRUCTURES_FILE}: {error}") from error
    if not isinstance(data, dict) or data.get("version") != STRUCTURES_VERSION \
            or not isinstance(data.get("groups"), dict) or not isinstance(data.get("structures"), dict):
        raise CatalogError(f"{STRUCTURES_FILE} is not version {STRUCTURES_VERSION} with groups and structures")
    return data


def built_in_structure_errors(data: dict) -> list[str]:
    """Every built-in structure is active, belongs to a built-in group, and has its written definition."""
    errors = []
    for name, structure in data["structures"].items():
        if not isinstance(structure, dict):
            errors.append(f"built-in structure {name} is not an object")
            continue
        if structure.get("group") not in data["groups"]:
            errors.append(f"built-in structure {name} names an unknown group")
        if structure.get("status") != "active":
            errors.append(f"built-in structure {name} is not active")
        for key in STRUCTURE_FIELDS:
            if not written(structure.get(key)):
                errors.append(f"built-in structure {name} has no {key}")
    return errors


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


def user_catalog(styles=None) -> dict | None:
    """The catalog of the styles folder, or None when no folder is named and ~/.styles holds none."""
    if styles is None and not (styles_dir() / CATALOG_NAME).is_file():
        return None
    return read_catalog(styles)


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


def merge(data: dict | None) -> dict:
    """The built-in styles with a version 2 catalog laid over them. Each family and finish profile
    carries its source, built-in or user; the images are the catalog's."""
    base = built_in()
    families = {name: {**family, "source": "built-in"} for name, family in base["families"].items()}
    profiles = {name: {**profile, "source": "built-in"} for name, profile in base["finish_profiles"].items()}
    images = []
    if data is not None:
        for name, family in data["families"].items():
            if isinstance(family, dict):
                families[name] = {**family, "source": "user"}
        for name, profile in data["finish_profiles"].items():
            if isinstance(profile, dict):
                profiles[name] = {**profiles.get(name, {}), **profile, "source": "user"}
        images = data["images"]
    return {"families": families, "finish_profiles": profiles, "images": images}


def view(styles=None) -> dict:
    """The styles in use: the built-in styles alone without a catalog in ~/.styles, otherwise the
    catalog laid over them. A broken catalog is refused, never replaced by the built-in styles."""
    data = user_catalog(styles)
    if data is not None:
        errors = schema_errors(data)
        if errors:
            raise CatalogError("; ".join(errors))
    return merge(data)


def merge_structures(data: dict | None) -> dict:
    """The built-in structures with the structures of a catalog laid over them, each carrying its
    source, built-in or user."""
    structures = {name: {**structure, "source": "built-in"}
                  for name, structure in built_in_structures()["structures"].items()}
    written_structures = data.get("structures") if data is not None else None
    if isinstance(written_structures, dict):
        for name, structure in written_structures.items():
            if isinstance(structure, dict):
                structures[name] = {**structures.get(name, {}), **structure, "source": "user"}
    return structures


def structure_catalog_errors(data: dict) -> list[str]:
    """The optional structures object of a catalog. A structure in use has its whole written
    definition once laid over the built-in one; a retired one needs only its status."""
    if "structures" not in data:
        return []
    if not isinstance(data["structures"], dict):
        return ["structures must be an object"]
    merged = merge_structures(data)
    errors = []
    for name, structure in data["structures"].items():
        if not isinstance(structure, dict):
            errors.append(f"structure {name} must be an object")
            continue
        status = merged[name].get("status")
        if status == "retired":
            continue
        if status is None:
            errors.append(f"structure {name} has no status")
        elif status != "active":
            errors.append(f"structure {name} has the status {status!r}, not active or retired")
        for key in STRUCTURE_FIELDS:
            if not written(merged[name].get(key)):
                errors.append(f"structure {name} has no {key}")
    return errors


def structures_view(styles=None) -> dict:
    """The structures in use: the built-in structures alone without a catalog in ~/.styles,
    otherwise the catalog's structures laid over them. A broken catalog is refused, never replaced
    by the built-in structures."""
    data = user_catalog(styles)
    if data is not None:
        errors = schema_errors(data) + structure_catalog_errors(data)
        if errors:
            raise CatalogError("; ".join(errors))
    return merge_structures(data)


def structure_errors(name, structures: dict) -> list[str]:
    """A structure a figure names is one of the structures in use, as structures_view returns them,
    and not retired."""
    if not written(name):
        return ["structure is missing; " + STRUCTURES_HINT]
    if name not in structures:
        return [f"structure {name} is neither a built-in structure nor in the catalog; {STRUCTURES_HINT}"]
    if structures[name].get("status") == "retired":
        return [f"structure {name} is retired by the catalog"]
    return []


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
        data = view(styles)
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
        data = view(styles)
    except CatalogError as error:
        return [str(error)]
    if finish_profile is not None and finish_profile not in data["finish_profiles"]:
        return ["unsupported finish_profile: " + str(finish_profile)]
    try:
        item = lookup(reference, data, styles)
    except (OSError, ValueError) as error:
        return [str(error)]
    profile = data["finish_profiles"].get(item["finish_profile"])
    if profile is None:
        return ["unsupported finish_profile of the registered sample: " + str(item["finish_profile"])]
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
    """Check a catalog as it is written, together with the built-in styles it is laid over."""
    errors = schema_errors(data)
    if errors:
        return errors
    try:
        base = built_in()
    except CatalogError as error:
        return [str(error)]
    errors = built_in_errors(base)
    try:
        errors += built_in_structure_errors(built_in_structures()) + structure_catalog_errors(data)
    except CatalogError as error:
        errors.append(str(error))
    merged = merge(data)
    profiles = merged["finish_profiles"]
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
        profile = profiles.get(item.get("finish_profile"))
        if profile is None:
            errors.append(f"image {ident} names the finish_profile {item.get('finish_profile')!r}, "
                          "which is neither a built-in style nor in the catalog")
        elif profile.get("family") != item.get("family"):
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
    images = [i for i in data["images"] if isinstance(i, dict)]
    for name, profile in data["finish_profiles"].items():
        if not isinstance(profile, dict):
            errors.append("finish profile must be an object: " + name)
            continue
        if profiles[name].get("family") not in merged["families"]:
            errors.append("finish profile names an unknown family: " + name)
        for sample_id in profile.get("sample_ids", []):
            if not any(i.get("id") == sample_id and i.get("finish_profile") == name for i in images):
                errors.append("invalid profile sample: " + str(sample_id))
        # A style of the catalog names one of its images; a built-in style needs none.
        if name in base["finish_profiles"] and "reference_id" not in profile:
            continue
        if not any(i.get("id") == profile.get("reference_id") and i.get("finish_profile") == name for i in images):
            errors.append("invalid profile reference: " + name)
    return errors


def samples(name: str, data: dict, styles=None) -> list[str]:
    """The absolute paths of the catalog's images of one style; the ones its sample_ids name when it
    has sample_ids."""
    root = styles_dir(styles)
    chosen = data["finish_profiles"][name].get("sample_ids")
    return [str((root / item["path"]).resolve()) for item in data["images"]
            if isinstance(item, dict) and item.get("finish_profile") == name
            and (chosen is None or item.get("id") in chosen)]


def show(name: str, data: dict, styles=None) -> dict:
    """One style in use: its source, family, written specification, and the user's samples of it."""
    profile = data["finish_profiles"].get(name)
    if profile is None:
        raise CatalogError(f"no style is named {name} among the built-in styles and the catalog; "
                           "--list prints the styles in use")
    if profile.get("status") == "retired":
        raise CatalogError(f"the style {name} is retired by the catalog; --list prints the styles in use")
    shown = {"name": name, "source": profile["source"]}
    for key in ("family", "status", *WRITTEN_FIELDS, "suits", "specification"):
        if key in profile:
            shown[key] = profile[key]
    shown["samples"] = samples(name, data, styles)
    return shown


def show_structure(name: str, structures: dict) -> dict:
    """One structure in use: its source and its written definition."""
    structure = structures.get(name)
    if structure is None:
        raise CatalogError(f"no structure is named {name} among the built-in structures and the catalog; "
                           + STRUCTURES_HINT)
    if structure.get("status") == "retired":
        raise CatalogError(f"the structure {name} is retired by the catalog; {STRUCTURES_HINT}")
    shown = {"name": name, "source": structure["source"]}
    for key in (*STRUCTURE_FIELDS, "status"):
        if key in structure:
            shown[key] = structure[key]
    return shown


def structure_lines(structures: dict) -> list[str]:
    """One line per structure in use: name, source, group, label, and what it shows, separated by
    tabs. Tabs and line breaks the user wrote in a field become spaces."""
    return ["\t".join([name, structure["source"]] + [" ".join(str(structure.get(key, "")).split())
                                                       for key in ("group", "label", "shows")])
            for name, structure in structures.items() if structure.get("status") == "active"]


def list_lines(data: dict) -> list[str]:
    """One line per active style: name, source, family, label, and suits, separated by tabs."""
    return ["\t".join([name, profile["source"], str(profile.get("family", "")), str(profile.get("label", "")),
                       "; ".join(profile.get("suits") or [])])
            for name, profile in data["finish_profiles"].items() if profile.get("status") == "active"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--styles", help="the styles folder to read instead of ~/.styles")
    parser.add_argument("--validate", action="store_true",
                        help="check the built-in styles, and the catalog against every image in the folder")
    parser.add_argument("--list", action="store_true", help="print every style in use, one per line")
    parser.add_argument("--show", metavar="STYLE", help="print one style in use with the user's samples of it")
    parser.add_argument("--structures", action="store_true", help="print every figure structure in use, one per line")
    parser.add_argument("--show-structure", metavar="STRUCTURE", help="print one figure structure in use")
    parser.add_argument("--sample", type=Path, help="print the catalog entry of one sample image")
    parser.add_argument("--family")
    parser.add_argument("--profile")
    parser.add_argument("--layout")
    args = parser.parse_args()
    root = styles_dir(args.styles)
    try:
        if args.validate:
            data = user_catalog(args.styles)
            base = built_in()
            structures = built_in_structures()
            if data is None:
                errors = built_in_errors(base) + built_in_structure_errors(structures)
                if errors:
                    print("\n".join("ERROR: " + e for e in errors))
                    return 1
                print(f"PASS: {len(base['finish_profiles'])} built-in styles and {len(structures['structures'])} "
                      f"built-in structures; {root / CATALOG_NAME} is missing, "
                      "so only the built-in styles and structures are used")
                return 0
            errors = validate(data, args.styles)
            if errors:
                print(f"ERROR: {root}/{CATALOG_NAME}")
                print("\n".join("ERROR: " + e for e in errors))
                return 1
            candidates = sum(p.get("status") == "candidate" for p in data["finish_profiles"].values())
            retired = sum(data["finish_profiles"].get(name, {}).get("status") == "retired" for name in base["finish_profiles"])
            written_structures = data.get("structures", {})
            retired_structures = sum(written_structures.get(name, {}).get("status") == "retired"
                                     for name in structures["structures"])
            print(f"PASS: {root}: {len(data['images'])} unique images, {data['counts']['source_registrations']} originals, "
                  f"{len(data['finish_profiles'])} finishes ({candidates} candidate); "
                  f"{len(base['finish_profiles'])} built-in styles ({retired} retired by the catalog); "
                  f"{len(written_structures)} structures in the catalog, "
                  f"{len(structures['structures'])} built-in structures ({retired_structures} retired by the catalog)")
            return 0
        if args.structures or args.show_structure:
            structures = structures_view(args.styles)
            if args.structures:
                print("\n".join(structure_lines(structures)))
                return 0
            print(json.dumps(show_structure(args.show_structure, structures), ensure_ascii=False, indent=2))
            return 0
        data = view(args.styles)
        if args.list:
            print("\n".join(list_lines(data)))
            return 0
        if args.show:
            print(json.dumps(show(args.show, data, args.styles), ensure_ascii=False, indent=2))
            return 0
        if args.sample:
            print(json.dumps(lookup(args.sample, data, args.styles), ensure_ascii=False, indent=2))
            return 0
        matches = [i for i in data["images"]
                   if data["finish_profiles"].get(i["finish_profile"], {}).get("status") == "active"
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
