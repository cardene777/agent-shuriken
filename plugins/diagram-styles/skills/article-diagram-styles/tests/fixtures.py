#!/usr/bin/env python3
"""Writes throwaway fixtures for the diagram-styles tests: a styles folder shaped like ~/.styles,
a folder of figure records (an article, a content brief, figure specs, a review, a visual
contract, and a composition ledger), and a composition ledger of figures in named structures.
The images are small PNGs drawn here, never the user's sample images.

Usage:
  fixtures.py styles <dir> [--schema N] [--resources] [--corrupt path|original]
                           [--counts source|unique] [--stray] [--no-catalog]
                           [--retire <style>] [--user-style]
                           [--built-in-sample <style> <family>]
                           [--user-structure] [--redefine-structure <structure>]
                           [--retire-structure <structure>] [--structure-lacks <field>]
  fixtures.py work <dir> [--mode generated|deterministic] [--style <family>] [--finish <style>]
  fixtures.py ledger <dir> [--structure <structure>]... [--no-structure]
                           [--spec-structure <structure>] [--mode <mode>] [--request <words>]

The catalog always redefines the built-in styles pen-technical and handdraft. --retire writes a
style that holds only "status": "retired". --user-style adds the family my-family and its style
my-style with one sample. --built-in-sample registers one sample of <style> in <family> without
writing a finish profile for it.

The structure options write the optional "structures" object of the catalog. --user-structure adds
the structure my-structure with its whole written definition. --redefine-structure writes the
user's own shows for a built-in structure. --retire-structure writes a structure that holds only
"status": "retired". --structure-lacks writes my-structure without the named field.

ledger writes a composition ledger with one figure spec per --structure, in that order. In the
article mode each figure makes a different point; in a comparison mode every figure holds the
same content. --no-structure leaves structure out of the entries and the specs, and
--spec-structure writes another structure into the spec of the first figure than into its entry.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path


def png(width: int, height: int, shade: int) -> bytes:
    """A valid RGB PNG of one flat color; the shade makes each image's bytes differ."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    row = b"\x00" + bytes([shade % 256, (shade * 7) % 256, (shade * 13) % 256]) * width
    raw = row * height
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


MY_STRUCTURE = {
    "group": "my-group", "label": "My structure", "status": "active",
    "shows": "Which release note answers which question of a reader",
    "parts": "Questions on the left and notes on the right, joined by lines",
    "reading_order": "Read a question, then follow its line to the note",
    "fits": "Release notes read by people who upgrade",
    "misfits": "A history of releases over time",
}


def styles(args: argparse.Namespace) -> None:
    root = Path(args.dir)
    root.mkdir(parents=True, exist_ok=True)
    images = [
        ("flow-a", "illustrated", "pen-technical", "style-catalog/illustrated/pen-technical/flow-a.png",
         ["diagram-style-samples/style4/flow-a.png"], ["left-to-right-flow"], 10),
        ("map-b", "technical-sketch", "handdraft", "style-catalog/technical-sketch/handdraft/map-b.png",
         ["diagram-style-samples/style4/map-b.png"], ["role-map"], 20),
        ("pen-c", "illustrated", "pen-technical", "style-catalog/illustrated/pen-technical/pen-c.png",
         [], ["cycle"], 30),
    ]
    if args.user_style:
        images.append(("mine-e", "my-family", "my-style", "style-catalog/my-family/my-style/mine-e.png",
                       [], ["left-to-right-flow"], 60))
    if args.built_in_sample:
        name, family = args.built_in_sample
        images.append((name + "-f", family, name, f"style-catalog/{family}/{name}/{name}-f.png",
                       [], ["role-map"], 70))
    entries = []
    for ident, family, profile, path, originals, layouts, shade in images:
        data = png(4, 3, shade)
        write(root / path, data)
        for original in originals:
            write(root / original, data)
        entries.append({
            "id": ident, "family": family, "finish_profile": profile, "path": path,
            "sha256": sha(data), "original_paths": originals, "layouts": layouts,
        })
    catalog = {
        "schema_version": args.schema,
        "counts": {
            "source_registrations": sum(len(e["original_paths"]) for e in entries),
            "unique_images": len({e["sha256"] for e in entries}),
        },
        "families": {
            "illustrated": {"label": "Illustrated", "description": "Drawn objects carry the figure"},
            "technical-sketch": {"label": "Technical sketch", "description": "Tables, states, and connections carry the figure"},
        },
        "finish_profiles": {
            "pen-technical": {
                "family": "illustrated", "label": "Pen technical", "status": "active",
                "reference_id": "flow-a", "sample_ids": ["flow-a", "pen-c"],
                "line": "black pen with a light wobble", "fill": "light teal and orange pencil",
                "background": "white", "lettering": "natural handwriting",
                "specification": "references/pen-technical.md",
            },
            "handdraft": {
                "family": "technical-sketch", "label": "Hand-drafted", "status": "active",
                "reference_id": "map-b", "sample_ids": ["map-b"],
                "line": "clear black pen", "fill": "light hatching", "background": "white",
                "lettering": "round dark handwriting", "specification": "references/handdraft.md",
            },
        },
        "images": entries,
    }
    if args.retire:
        catalog["finish_profiles"][args.retire] = {"status": "retired"}
    structures = {}
    if args.user_structure or args.structure_lacks:
        mine = dict(MY_STRUCTURE)
        mine.pop(args.structure_lacks or "", None)
        structures["my-structure"] = mine
    if args.redefine_structure:
        structures[args.redefine_structure] = {"shows": "The user's own words for " + args.redefine_structure}
    if args.retire_structure:
        structures[args.retire_structure] = {"status": "retired"}
    if structures:
        catalog["structures"] = structures
    if args.user_style:
        catalog["families"]["my-family"] = {"label": "My family", "description": "A family the user added"}
        catalog["finish_profiles"]["my-style"] = {
            "family": "my-family", "label": "My style", "status": "active",
            "reference_id": "mine-e", "sample_ids": ["mine-e"],
            "line": "thick brown felt pen", "fill": "mint crayon", "background": "pale gray",
            "lettering": "narrow capitals", "suits": ["release notes"],
        }
    if args.resources:
        catalog["finish_profiles"]["pen-technical"]["resources"] = {
            "font": {"path": "assets/fonts/font.ttf", "sha256": "0" * 64},
        }
    if args.corrupt == "path":
        write(root / images[2][3], png(4, 3, 200))
    elif args.corrupt == "original":
        write(root / images[0][4][0], png(4, 3, 201))
    if args.counts == "source":
        catalog["counts"]["source_registrations"] += 1
    elif args.counts == "unique":
        catalog["counts"]["unique_images"] += 1
    if args.stray:
        write(root / "diagram-style-samples/style2/stray-sample.webp", b"RIFF\x00\x00\x00\x00WEBPVP8 ")
    if not args.no_catalog:
        (root / "style-catalog.json").write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")


def work(args: argparse.Namespace) -> None:
    root = Path(args.dir)
    root.mkdir(parents=True, exist_ok=True)
    article = root / "article.md"
    article.write_text("# Change history\nThe value goes from 7 to 9, and the next step makes it 11.\n", encoding="utf-8")
    brief = {
        "mode": "article",
        "article_context": {"path": "article.md", "heading": "Change history",
                            "excerpt": "The value goes from 7 to 9, and the next step makes it 11."},
        "reader_question": "What is the value after the first step?",
        "takeaway": "Each step keeps the value it wrote.",
        "visual_reason": "The last value alone does not show the steps in between.",
        "layout_reason": "Points in time of the same key line up with their values.",
        "elements": [{"id": "slot", "meaning": "the history of one key", "form": "values on a time line",
                      "why": "the reader can follow the values in between", "basis": "article"}],
        "relations": [{"from": "slot", "to": "slot", "meaning": "the next step changes the value",
                       "encoding": "an arrow along the time line"}],
    }
    brief_path = root / "brief.json"
    brief_path.write_text(json.dumps(brief), encoding="utf-8")
    candidate = png(528, 240, 40)
    write(root / "candidate.png", candidate)
    write(root / "preview.png", candidate)
    (root / "prompt.txt").write_text("Draw the whole figure with the exact values 9 and 11 and a directed transition.\n", encoding="utf-8")
    (root / "figure.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg"><text x="10" y="20">9</text><text x="50" y="20">11</text><path d="M20 20H45"/></svg>',
        encoding="utf-8")
    source = "article.md"
    spec = {
        "rendering_mode": args.mode, "exact_content": True,
        "source_file": "candidate.png" if args.mode == "generated" else "figure.svg",
        "purpose": brief["takeaway"], "content_brief_sha256": sha(brief_path.read_bytes()),
        "fixed_style": args.style, "finish_profile": args.finish,
        "facts": [{"text": value, "kind": "number", "source": source, "locator": "example"} for value in ("9", "11")],
        "relations": [{"from": "9", "to": "11", "kind": "state-transition", "exact": True,
                       "source": source, "locator": "example"}],
    }
    if args.mode == "generated":
        spec["generation_prompt_file"] = "prompt.txt"
    spec_path = root / "figure.figure.json"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    checks = ["article_context_fit", "reader_question_answered", "semantic_relations_visible",
              "no_unjustified_visuals", "readable_at_published_width", "exact_content_verified",
              "style_spec_applied"]
    files = {key: {"path": name, "sha256": sha((root / name).read_bytes())}
             for key, name in [("candidate", "candidate.png"), ("preview_528", "preview.png"),
                               ("content_brief", "brief.json"), ("figure_spec", "figure.figure.json")]}
    review = {
        "schema_version": 2, "status": "candidate-reviewed", "fixed_style": args.style,
        "finish_profile": args.finish, "published_width_px": 528, "files": files,
        "checks": {key: True for key in checks},
        "evidence": {key: "Read against the article excerpt and the values and arrow in the figure." for key in checks},
        "review": {"evaluator": "test-review", "write_access": False, "verdict": "pass", "findings": [],
                   "reader_answer": "After the first step the value is 9, drawn apart from the later 11."},
    }
    if args.mode == "generated":
        files["generation_prompt"] = {"path": "prompt.txt", "sha256": sha((root / "prompt.txt").read_bytes())}
        review["verified_facts"] = [{"text": f["text"], "source": source, "locator": "example",
                                     "evidence": "Read the value in the PNG."} for f in spec["facts"]]
        review["verified_relations"] = [{"from": "9", "to": "11", "kind": "state-transition", "source": source,
                                         "locator": "example", "evidence": "Followed the arrow in the PNG."}]
        review["source_checks"] = [{"source": source, "locator": "example",
                                    "evidence": "The source gives 9 after the first change and 11 after the next."}]
    (root / "review.json").write_text(json.dumps(review), encoding="utf-8")
    anchor = png(4, 3, 50)
    write(root / "anchor.png", anchor)
    contract = {
        "contract_id": "test-style", "schema_version": 2, "status": "user-delegated",
        "approval_mode": "delegated-style-selection", "approval_evidence": "Make the figures without asking.",
        "approval_scope": "Delegated production, not approval of each image.",
        "execution_mode": "sequential-one-figure", "fixed_style": args.style, "finish_profile": args.finish,
        "visual_anchor": {"path": "anchor.png", "sha256": sha(anchor)},
        "visual_profile": {"paper": "white", "line": "black pen", "palette": "black and light teal"},
        "composition_policy": {"layout_varies_by_claim": True, "prohibited_repetition": ["the same claim twice"]},
        "rejection_criteria": ["does not answer the reader question"],
    }
    contract_path = root / "contract.json"
    contract_path.write_text(json.dumps(contract), encoding="utf-8")
    signature = {"dominant_geometry": "strip", "subject_scale": "paired", "label_zone": "top",
                 "connector_strategy": "direct"}
    contract_spec = {"visual_contract_id": "test-style", "visual_contract_sha256": sha(contract_path.read_bytes()),
                     "fixed_style": args.style, "finish_profile": args.finish,
                     "layout_pattern": "custom-change-timeline", "semantic_structure": "one key over time",
                     "reading_path": "left to right", "composition_signature": signature}
    (root / "contract-spec.json").write_text(json.dumps(contract_spec), encoding="utf-8")
    entry = {key: contract_spec[key] for key in ("layout_pattern", "semantic_structure", "reading_path", "composition_signature")}
    ledger = {"visual_contract_id": "test-style", "entries": [{"figure_spec": "contract-spec.json", **entry}]}
    (root / "ledger.json").write_text(json.dumps(ledger), encoding="utf-8")


def ledger(args: argparse.Namespace) -> None:
    root = Path(args.dir)
    root.mkdir(parents=True, exist_ok=True)
    signature = {"dominant_geometry": "strip", "subject_scale": "paired", "label_zone": "top",
                 "connector_strategy": "direct"}
    comparing = args.mode in ("style-comparison", "structure-comparison")
    entries = []
    for index, name in enumerate(args.structure or ["timeline"], 1):
        spec = {"visual_contract_id": "test-style", "layout_pattern": "custom-figure-%d" % index,
                "semantic_structure": "one key over time" if comparing else "claim %d of the article" % index,
                "reading_path": "read figure %d in the order of its structure" % index,
                "composition_signature": signature}
        entry = dict(spec)
        if not args.no_structure:
            entry["structure"] = name
            spec["structure"] = args.spec_structure if index == 1 and args.spec_structure else name
        (root / ("ledger-spec-%d.json" % index)).write_text(json.dumps(spec), encoding="utf-8")
        entry.pop("visual_contract_id")
        entries.append({"figure_spec": "ledger-spec-%d.json" % index, **entry})
    data = {"visual_contract_id": "test-style", "entries": entries}
    if args.mode:
        data["mode"] = args.mode
    if args.request:
        data["comparison_request"] = args.request
    (root / "ledger.json").write_text(json.dumps(data), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="kind", required=True)
    s = sub.add_parser("styles")
    s.add_argument("dir")
    s.add_argument("--schema", type=int, default=2)
    s.add_argument("--resources", action="store_true")
    s.add_argument("--corrupt", choices=["path", "original"])
    s.add_argument("--counts", choices=["source", "unique"])
    s.add_argument("--stray", action="store_true")
    s.add_argument("--no-catalog", action="store_true")
    s.add_argument("--retire")
    s.add_argument("--user-style", action="store_true")
    s.add_argument("--built-in-sample", nargs=2, metavar=("STYLE", "FAMILY"))
    s.add_argument("--user-structure", action="store_true")
    s.add_argument("--redefine-structure")
    s.add_argument("--retire-structure")
    s.add_argument("--structure-lacks")
    w = sub.add_parser("work")
    w.add_argument("dir")
    w.add_argument("--mode", choices=["generated", "deterministic"], default="generated")
    w.add_argument("--style", default="illustrated")
    w.add_argument("--finish", default="pen-technical")
    l = sub.add_parser("ledger")
    l.add_argument("dir")
    l.add_argument("--structure", action="append")
    l.add_argument("--no-structure", action="store_true")
    l.add_argument("--spec-structure")
    l.add_argument("--mode")
    l.add_argument("--request")
    args = parser.parse_args()
    {"styles": styles, "work": work, "ledger": ledger}[args.kind](args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
