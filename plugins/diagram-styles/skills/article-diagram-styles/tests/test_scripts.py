#!/usr/bin/env python3
"""Unit tests of the scripts of article-diagram-styles: the catalog lookups, the structures, the
figure spec, the visual contract states, the content brief, the review records, and the
composition ledger.

Every test reads a throwaway styles folder that tests/fixtures.py draws under a throwaway HOME, so
nothing reads the user's ~/.styles. Run: python3 tests/test_scripts.py
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True

import diagram_sample_catalog as catalog  # noqa: E402
import fixtures  # noqa: E402
import validate_anchor_candidate as anchor  # noqa: E402
import validate_composition_ledger as ledger  # noqa: E402
import validate_content_brief as content  # noqa: E402
import validate_visual_contract as visual  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Styles(unittest.TestCase):
    """A throwaway HOME with a version 2 styles folder."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        fixtures.styles(argparse.Namespace(dir=str(self.home / ".styles"), schema=2, resources=False,
                                           corrupt=None, counts=None, stray=False, no_catalog=False,
                                           retire=None, user_style=False, built_in_sample=None,
                                           user_structure=False, redefine_structure=None,
                                           retire_structure=None, structure_lacks=None))
        home = patch.dict(os.environ, {"HOME": str(self.home)})
        home.start()
        self.addCleanup(home.stop)
        self.root = self.home / ".styles"
        self.d = catalog.load()

    def write(self, data):
        (self.root / "style-catalog.json").write_text(json.dumps(data), encoding="utf-8")


class CatalogTests(Styles):
    def test_inventory_and_hashes(self):
        self.assertEqual(catalog.validate(self.d), [])

    def test_only_active_finishes_are_selectable(self):
        self.assertEqual({n for n, p in self.d["finish_profiles"].items() if p["status"] == "active"}, {"pen-technical", "handdraft"})

    def test_reference_and_text_selection_agree(self):
        for name in ["pen-technical", "handdraft"]:
            p = self.d["finish_profiles"][name]
            i = next(i for i in self.d["images"] if i["id"] == p["reference_id"])
            self.assertEqual(catalog.profile_errors(p["family"], name), [])
            self.assertEqual(catalog.selection_errors(p["family"], self.root / i["path"], name), [])
            self.assertTrue(catalog.profile_errors("wrong-family", name))

    def test_retired_samples_remain_readable_but_unselectable(self):
        d = copy.deepcopy(self.d)
        d["finish_profiles"]["handdraft"]["status"] = "retired"
        self.write(d)
        i = next(i for i in d["images"] if i["id"] == "map-b")
        r = self.root / i["path"]
        self.assertEqual(catalog.lookup(r)["id"], "map-b")
        self.assertTrue(catalog.profile_errors("technical-sketch", "handdraft"))
        self.assertTrue(catalog.selection_errors("technical-sketch", r, "handdraft", allow_candidate=True))

    def test_changed_and_duplicate_asset_rejected(self):
        d = copy.deepcopy(self.d)
        d["images"][-1]["sha256"] = "0" * 64
        self.assertTrue(catalog.validate(d))
        d = copy.deepcopy(self.d)
        d["images"][-1]["sha256"] = d["images"][0]["sha256"]
        self.assertTrue(catalog.validate(d))

    def test_mixed_profiles_rejected(self):
        i = next(i for i in self.d["images"] if i["id"] == "flow-a")
        self.assertTrue(catalog.selection_errors("technical-sketch", self.root / i["path"], "handdraft"))

    def test_candidate_requires_selection(self):
        d = copy.deepcopy(self.d)
        d["finish_profiles"]["pen-technical"]["status"] = "candidate"
        self.write(d)
        self.assertTrue(catalog.profile_errors("illustrated", "pen-technical"))
        self.assertEqual(catalog.profile_errors("illustrated", "pen-technical", allow_candidate=True), [])

    def test_version_1_is_refused_by_every_lookup(self):
        d = copy.deepcopy(self.d)
        d["schema_version"] = 1
        self.write(d)
        self.assertIn("schema_version", " ".join(catalog.profile_errors("illustrated", "pen-technical")))
        with self.assertRaises(catalog.CatalogError):
            catalog.load()

    def test_profile_selection_without_image(self):
        self.assertEqual(catalog.profile_errors("illustrated", "pen-technical"), [])
        self.assertTrue(catalog.profile_errors("technical-sketch", "pen-technical"))
        self.assertTrue(catalog.profile_errors("illustrated", "missing"))


class StructureTests(Styles):
    """The structures in use: the built-in ones with the catalog's structures laid over them."""

    def test_built_in_structures_without_catalog_structures(self):
        structures = catalog.structures_view()
        self.assertEqual(len(structures), 16)
        self.assertEqual({s["source"] for s in structures.values()}, {"built-in"})

    def test_catalog_adds_replaces_and_retires(self):
        d = copy.deepcopy(self.d)
        d["structures"] = {"my-structure": dict(fixtures.MY_STRUCTURE), "timeline": {"shows": "Mine"},
                           "cycle": {"status": "retired"}}
        self.write(d)
        structures = catalog.structures_view()
        self.assertEqual(structures["my-structure"]["source"], "user")
        self.assertEqual((structures["timeline"]["shows"], structures["timeline"]["source"]), ("Mine", "user"))
        self.assertEqual(structures["timeline"]["parts"], catalog.built_in_structures()["structures"]["timeline"]["parts"])
        self.assertEqual(catalog.structure_errors("cycle", structures), ["structure cycle is retired by the catalog"])
        self.assertEqual(catalog.structure_errors("my-structure", structures), [])
        self.assertTrue(catalog.structure_errors("no-such-structure", structures))
        self.assertEqual(catalog.validate(d), [])

    def test_catalog_structure_needs_its_written_definition(self):
        for field in ("group", "label", "shows", "parts", "reading_order", "fits", "misfits", "status"):
            d = copy.deepcopy(self.d)
            mine = dict(fixtures.MY_STRUCTURE)
            mine.pop(field)
            d["structures"] = {"my-structure": mine}
            self.assertIn(f"structure my-structure has no {field}", catalog.validate(d), field)
        d = copy.deepcopy(self.d)
        d["structures"] = ["timeline"]
        self.assertTrue(catalog.validate(d))

    def test_figure_spec_names_a_structure_in_use(self):
        spec = self.home / "figure.figure.json"
        data = {"rendering_mode": "deterministic", "exact_content": False, "source_file": "figure.svg",
                "facts": [{"text": "a step", "kind": "prose", "source": "a.md", "locator": "Flow"}],
                "relations": [{"from": "a", "to": "b", "kind": "call", "source": "a.md", "locator": "Flow", "exact": False}]}
        (self.home / "figure.svg").write_text("<svg xmlns='http://www.w3.org/2000/svg'/>", encoding="utf-8")
        for structure, code in ((None, 0), ("process-flow", 0), ("no-such-structure", 1)):
            if structure:
                data["structure"] = structure
            spec.write_text(json.dumps(data), encoding="utf-8")
            result = run_spec(spec)
            self.assertEqual(result.returncode, code, structure)
            if code:
                self.assertIn("structure", result.stderr)


def run_spec(spec: Path, *arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPTS / "validate_figure_spec.py"), str(spec), *arguments],
                          capture_output=True, text=True, check=False, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})


class FigureSpecTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_source_labels_bind_every_fact(self):
        root = self.root
        (root / "figure.svg").write_text("<svg xmlns='http://www.w3.org/2000/svg'/>", encoding="utf-8")
        valid = root / "valid.figure.json"
        valid.write_text(json.dumps({
            "rendering_mode": "deterministic", "exact_content": True, "source_file": "figure.svg",
            "facts": [{"text": "getRegistries", "kind": "identifier", "source": "spec.md", "locator": "Interface"}],
            "relations": [{"from": "candidates", "to": "check", "kind": "call", "source": "spec.md", "locator": "Flow", "exact": True}],
        }), encoding="utf-8")
        self.assertEqual(run_spec(valid).returncode, 0)
        # An empty source passes the schema check; the source-binding check refuses it.
        result = run_spec(valid, "--require-source-labels")
        self.assertTrue(result.returncode == 1 and "no source text/glyph label binding" in result.stderr)
        for body, code in [("<g aria-label='getRegistries'/>", 1), ("<text>wrongName</text>", 1), ("<text>getRegistries</text>", 0),
                           ("<g aria-label='getRegistries'><path d='M1 1L10 1L10 10Z'/></g>", 0),
                           ("<g aria-label='getRegistries'><text>wrongName</text><path d='M1 1L10 1L10 10Z'/></g>", 1)]:
            (root / "figure.svg").write_text(f"<svg xmlns='http://www.w3.org/2000/svg'>{body}</svg>", encoding="utf-8")
            self.assertEqual(run_spec(valid, "--require-source-labels").returncode, code, body)
        html = json.loads(valid.read_text())
        html["source_file"] = "figure.html"
        html_spec = root / "html.figure.json"
        html_spec.write_text(json.dumps(html), encoding="utf-8")
        for body in ["<p>getRegistriesWrong</p>", "<script>getRegistries</script><style>getRegistries</style>"]:
            (root / "figure.html").write_text(body, encoding="utf-8")
            self.assertEqual(run_spec(html_spec, "--require-source-labels").returncode, 1, body)
        (root / "figure.html").write_text("<div><span>get</span><span>Registries</span></div>", encoding="utf-8")
        self.assertEqual(run_spec(html_spec, "--require-source-labels").returncode, 0)

    def test_generated_figures_need_the_image_and_the_instructions(self):
        root = self.root
        spec = root / "generated.figure.json"
        data = {
            "rendering_mode": "generated", "exact_content": True,
            "facts": [{"text": "uint64", "kind": "type", "source": "spec.md", "locator": "Type"}],
            "relations": [{"from": "candidate", "to": "check", "kind": "state-transition", "source": "spec.md", "locator": "Flow", "exact": True}],
        }
        spec.write_text(json.dumps(data))
        result = run_spec(spec)
        self.assertTrue(result.returncode == 1 and "raster source_file" in result.stderr)
        data.update(source_file="figure.png", generation_prompt_file="prompt.txt")
        (root / "figure.png").write_bytes(b"existing image fixture; not a visual quality test")
        (root / "prompt.txt").write_text("Draw the full figure, exact uint64 and directed transition.")
        spec.write_text(json.dumps(data))
        self.assertEqual(run_spec(spec, "--require-source-labels").returncode, 0)
        data["exact_content"] = False
        spec.write_text(json.dumps(data))
        result = run_spec(spec)
        self.assertTrue(result.returncode == 1 and "exact_content must be true" in result.stderr)
        data["exact_content"] = True
        spec.write_text(json.dumps(data))
        (root / "prompt.txt").write_text("")
        result = run_spec(spec)
        self.assertTrue(result.returncode == 1 and "must not be empty" in result.stderr)
        (root / "prompt.txt").unlink()
        result = run_spec(spec)
        self.assertTrue(result.returncode == 1 and "generation_prompt_file" in result.stderr)
        (root / "prompt.txt").write_text("Full diagram prompt")
        (root / "figure.png").unlink()
        result = run_spec(spec)
        self.assertTrue(result.returncode == 1 and "source_file does not exist" in result.stderr)


class VisualContractStateTests(unittest.TestCase):
    def test_approval_and_delegation_states(self):
        states = visual.approval_state_errors
        self.assertEqual(states({"status": "user-approved"}), [])
        delegated = {"status": "user-delegated", "approval_mode": "delegated-style-selection",
                     "approval_evidence": "Make them without asking in between.",
                     "approval_scope": "Delegated production; no image was approved by eye."}
        self.assertEqual(states(delegated), [])
        for change in ({"status": "user-approved"}, {"approval_evidence": ""}, {"approval_scope": ""},
                       {"approval_mode": "automatic"}, {"status": "pending"}):
            self.assertTrue(states({**delegated, **change}), change)
        self.assertTrue(states({}))


class ContentFirstTests(Styles):
    def setUp(self):
        super().setUp()
        self.d = Path(self.tmp.name) / "work"
        self.d.mkdir()
        (self.d / "article.md").write_text("# Change history\nThe value goes from 7 to 9, and the next step makes it 11.\n")

    def brief(self):
        return dict(mode="article", article_context=dict(path="article.md", heading="Change history",
                    excerpt="The value goes from 7 to 9, and the next step makes it 11."),
                    reader_question="What is the value after the first step?", takeaway="Each step keeps the value it wrote.",
                    visual_reason="The last value alone does not show the steps in between.",
                    layout_reason="Points in time of the same key line up with their values.",
                    elements=[dict(id="slot", meaning="the history of one key", form="values on a time line",
                                   why="the reader can follow the values in between", basis="article")],
                    relations=[dict(**{"from": "slot", "to": "slot"}, meaning="the next step changes the value", encoding="an arrow on the time line")])

    def write_json(self, name, data):
        p = self.d / name
        p.write_text(json.dumps(data))
        return p

    def test_article_plan_without_any_sample_or_style(self):
        self.assertEqual(content.validate(self.brief(), self.d / "brief.json"), [])

    def test_excerpt_must_occur_in_article(self):
        b = self.brief()
        b["article_context"]["excerpt"] = "A robot at a workbench"
        self.assertTrue(content.validate(b, self.d / "brief.json"))

    def test_style_fields_cannot_drive_content_brief(self):
        for key in ("style_reference", "reference_samples", "style_spec"):
            b = self.brief()
            b[key] = "sample.png"
            self.assertTrue(content.validate(b, self.d / "brief.json"))

    def test_sample_cannot_justify_subject(self):
        b = self.brief()
        b["elements"][0]["basis"] = "sample"
        self.assertTrue(content.validate(b, self.d / "brief.json"))

    def test_relation_cannot_refer_to_undefined_subject(self):
        b = self.brief()
        b["relations"][0]["to"] = "machine"
        self.assertTrue(content.validate(b, self.d / "brief.json"))

    def test_comparison_requires_explicit_same_content_request(self):
        b = self.brief()
        b["mode"] = "style-comparison"
        self.assertTrue(content.validate(b, self.d / "brief.json"))
        b.update(comparison_request="Compare the styles on the same content and layout.", same_content_requested=True)
        self.assertEqual(content.validate(b, self.d / "brief.json"), [])

    def review(self):
        b = self.brief()
        bp = self.write_json("brief.json", b)
        (self.d / "figure.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"><text x="10" y="20">9</text><text x="50" y="20">11</text><path d="M20 20H45"/></svg>')
        spec = dict(rendering_mode="deterministic", exact_content=True, source_file="figure.svg", purpose=b["takeaway"],
                    content_brief_sha256=sha(bp), fixed_style="illustrated", finish_profile="pen-technical",
                    facts=[dict(text=s, kind="number", source="spec.md", locator="example") for s in ("9", "11")],
                    relations=[dict(**{"from": "9", "to": "11"}, kind="state-transition", exact=True, source="spec.md", locator="example")])
        self.write_json("figure.figure.json", spec)
        # Header fixtures test metadata binding, not raster quality or valid image pixels.
        for name in ("candidate.png", "preview.png"):
            (self.d / name).write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 528, 240))
        files = {k: dict(path=n, sha256=sha(self.d / n)) for k, n in
                 [("candidate", "candidate.png"), ("preview_528", "preview.png"), ("content_brief", "brief.json"), ("figure_spec", "figure.figure.json")]}
        return dict(schema_version=2, status="candidate-reviewed", fixed_style="illustrated", finish_profile="pen-technical", files=files,
                    checks={k: True for k in anchor.REQUIRED_CHECKS},
                    evidence={k: "Read against the article excerpt and the values and connections in the figure." for k in anchor.REQUIRED_CHECKS},
                    review=dict(evaluator="independent-test-review", write_access=False, verdict="pass", findings=[],
                                reader_answer="After the first step the value is 9, drawn at another point in time than 11."))

    def generated_review(self):
        r = self.review()
        sp = self.d / "figure.figure.json"
        s = json.loads(sp.read_text())
        (self.d / "prompt.txt").write_text("Complete image with exact 9 and 11 and a directed transition.")
        s.update(rendering_mode="generated", source_file="candidate.png", generation_prompt_file="prompt.txt")
        sp.write_text(json.dumps(s))
        r["files"]["figure_spec"]["sha256"] = sha(sp)
        r["files"]["generation_prompt"] = dict(path="prompt.txt", sha256=sha(self.d / "prompt.txt"))
        r["verified_facts"] = [dict(**{k: v[k] for k in ("text", "source", "locator")}, evidence="Read the value in the PNG.") for v in s["facts"]]
        r["verified_relations"] = [dict(**{k: v[k] for k in ("from", "to", "kind", "source", "locator")}, evidence="Followed the arrowhead in the PNG.") for v in s["relations"]]
        r["source_checks"] = [dict(source="spec.md", locator="example", evidence="The source gives 9 after the first change and 11 after the next.")]
        return r

    def test_article_bound_review_without_sample_image(self):
        self.assertEqual(anchor.validate(self.review(), self.d / "review.json"), [])

    def test_whole_generated_exact_figure_can_pass_with_visual_evidence(self):
        self.assertEqual(anchor.validate(self.generated_review(), self.d / "review.json"), [])

    def test_generated_image_cannot_reuse_source_only_accuracy_claim(self):
        r = self.generated_review()
        r["checks"]["exact_content_kept_deterministic"] = r["checks"].pop("exact_content_verified")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_generated_image_requires_each_fact_and_relation_review(self):
        r = self.generated_review()
        r["verified_facts"].pop()
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        r["verified_relations"][0]["to"] = "wrong"
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        r["verified_facts"][0]["evidence"] = ""
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_generated_image_review_is_invalid_after_raster_change(self):
        r = self.generated_review()
        (self.d / "candidate.png").write_bytes(b"changed")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_generated_review_binds_prompt_and_candidate(self):
        r = self.generated_review()
        (self.d / "prompt.txt").write_text("unreviewed replacement")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        sp = self.d / "figure.figure.json"
        s = json.loads(sp.read_text())
        (self.d / "other.png").write_bytes((self.d / "candidate.png").read_bytes())
        s["source_file"] = "other.png"
        sp.write_text(json.dumps(s))
        r["files"]["figure_spec"]["sha256"] = sha(sp)
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        r["verified_facts"][0]["source"] = "other.md"
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_image_review_requires_primary_source_observations(self):
        r = self.generated_review()
        r.pop("source_checks")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        r["source_checks"][0]["evidence"] = ""
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.generated_review()
        r["source_checks"][0]["locator"] = "wrong"
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_old_style_only_pass_cannot_approve_article_figure(self):
        r = self.review()
        r.pop("schema_version")
        r["checks"] = {"fixed_style_matches_reference": True}
        r["files"].pop("content_brief")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_review_requires_answer_and_evidence(self):
        r = self.review()
        r["review"].pop("reader_answer")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.review()
        r["evidence"].pop("article_context_fit")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_altered_article_or_brief_invalidates_review(self):
        r = self.review()
        (self.d / "article.md").write_text("Another explanation")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))
        r = self.review()
        (self.d / "brief.json").write_text("{}")
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_spec_must_preserve_content_and_profile(self):
        r = self.review()
        p = self.d / "figure.figure.json"
        s = json.loads(p.read_text())
        s["purpose"] = "Another claim"
        p.write_text(json.dumps(s))
        r["files"]["figure_spec"]["sha256"] = sha(p)
        self.assertTrue(anchor.validate(r, self.d / "review.json"))

    def test_repeated_geometry_can_explain_different_article_claims(self):
        signature = dict(dominant_geometry="strip", subject_scale="paired", label_zone="top", connector_strategy="direct")
        entries = []
        for i in range(8):
            s = dict(visual_contract_id="example", layout_pattern="custom-change-timeline", semantic_structure=f"a different object {i}",
                     reading_path=f"follow object {i}", composition_signature=signature, structure="timeline")
            self.write_json(f"f{i}.json", s)
            entries.append(dict(figure_spec=f"f{i}.json", **{k: s[k] for k in ("layout_pattern", "semantic_structure", "reading_path", "composition_signature", "structure")}))
        self.assertEqual(ledger.validate(self.write_json("ledger.json", dict(visual_contract_id="example", entries=entries))), [])
        entries[1]["semantic_structure"] = entries[0]["semantic_structure"]
        entries[1]["reading_path"] = entries[0]["reading_path"]
        s = json.loads((self.d / "f1.json").read_text())
        s.update(semantic_structure=entries[1]["semantic_structure"], reading_path=entries[1]["reading_path"])
        self.write_json("f1.json", s)
        self.assertTrue(ledger.validate(self.write_json("ledger.json", dict(visual_contract_id="example", entries=entries))))
        self.assertTrue(ledger.validate(self.write_json("ledger.json", dict(visual_contract_id="example", entries=entries, mode="style-comparison",
                                                                            comparison_request="Three figures for the article."))))
        self.assertEqual(ledger.validate(self.write_json("ledger.json", dict(visual_contract_id="example", entries=entries, mode="style-comparison",
                                                                             comparison_request="Compare the same content and layout in three styles.",
                                                                             same_content_requested=True))), [])

    def test_multiple_requested_finishes_can_have_separate_contracts(self):
        signature = dict(dominant_geometry="strip", subject_scale="paired", label_zone="top", connector_strategy="direct")
        entries = []
        for i, contract in enumerate(("ink-contract", "news-contract")):
            s = dict(visual_contract_id=contract, layout_pattern="custom-change-timeline", semantic_structure=f"object {i}",
                     reading_path=f"follow object {i}", composition_signature=signature, structure="layers")
            self.write_json(f"m{i}.json", s)
            entries.append(dict(figure_spec=f"m{i}.json", **s))
        self.assertEqual(ledger.validate(self.write_json("mixed.json", dict(visual_contract_ids=["ink-contract", "news-contract"], entries=entries))), [])
        self.assertTrue(ledger.validate(self.write_json("mixed.json", dict(visual_contract_ids=["ink-contract"], entries=entries))))

    def test_structure_comparison_draws_each_structure_once(self):
        signature = dict(dominant_geometry="strip", subject_scale="paired", label_zone="top", connector_strategy="direct")
        entries = []
        for i, structure in enumerate(("timeline", "before-after", "quantity-trend", "cycle")):
            s = dict(visual_contract_id="example", layout_pattern=f"custom-{structure}", semantic_structure="one key over time",
                     reading_path=f"the reading order of {structure}", composition_signature=signature, structure=structure)
            self.write_json(f"c{i}.json", s)
            entries.append(dict(figure_spec=f"c{i}.json", **{k: v for k, v in s.items() if k != "visual_contract_id"}))
        comparison = dict(visual_contract_id="example", mode="structure-comparison", comparison_request="Show it in four structures.")
        self.assertEqual(ledger.validate(self.write_json("ledger.json", dict(comparison, entries=entries))), [])
        # The same content without the comparison mode makes the same point four times.
        same_path = [dict(e, reading_path="one path") for e in entries]
        for i, e in enumerate(same_path):
            s = json.loads((self.d / f"c{i}.json").read_text())
            s["reading_path"] = "one path"
            self.write_json(f"c{i}.json", s)
        self.assertTrue(ledger.validate(self.write_json("ledger.json", dict(visual_contract_id="example", entries=same_path))))
        self.assertEqual(ledger.validate(self.write_json("ledger.json", dict(comparison, entries=same_path))), [])
        self.assertTrue(ledger.validate(self.write_json("ledger.json", dict(comparison, entries=same_path[:1]))))
        self.assertTrue(ledger.validate(self.write_json("ledger.json", dict(comparison, entries=same_path + same_path[:1]))))

    def test_sample_free_visual_contract(self):
        (self.d / "anchor.png").write_bytes(b"existing reviewed image")
        c = dict(contract_id="test-style", schema_version=2, status="user-delegated", approval_mode="delegated-style-selection",
                 approval_evidence="Make them without asking in between.", approval_scope="Delegated production, not approval of each image.",
                 execution_mode="sequential-one-figure", fixed_style="illustrated", finish_profile="pen-technical",
                 visual_anchor=dict(path="anchor.png", sha256=sha(self.d / "anchor.png")),
                 visual_profile=dict(paper="white", line="black pen", palette="black and light teal", lettering="handwriting"),
                 composition_policy=dict(layout_varies_by_claim=True, prohibited_repetition=["the same claim twice"]),
                 rejection_criteria=["does not answer the reader question"])
        cp = self.write_json("contract.json", c)
        sp = self.write_json("spec.json", dict(visual_contract_id="test-style", visual_contract_sha256=sha(cp),
                                               fixed_style="illustrated", finish_profile="pen-technical"))
        self.assertEqual(visual.validate(cp, sp), [])


if __name__ == "__main__":
    unittest.main()
