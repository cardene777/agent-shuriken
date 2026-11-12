#!/usr/bin/env python3
"""Draw a diagram as an Excalidraw file that passes layout checks, with SVG and PNG copies.

Usage:
  excalidraw_diagram.py build <spec.json | diagram.mmd> [--out DIR] [--name NAME]
                              [--png auto|skip|require] [--scale 1|2|3] [--replace]
  excalidraw_diagram.py check <file.excalidraw>
  excalidraw_diagram.py render <file.excalidraw> [--out DIR] [--name NAME]
                               [--png auto|skip|require] [--scale 1|2|3] [--replace]
  excalidraw_diagram.py mermaid <diagram.mmd | -> [--output spec.json] [--replace]

build    lays out the spec, checks the result, and writes NAME.excalidraw, NAME.svg, and
         NAME.png (the PNG only when a Chromium-based browser is installed). The files go
         next to the spec unless --out names a folder. Nothing is written when a check fails.
check    checks any .excalidraw file against the same rules.
render   writes the SVG and PNG of an .excalidraw file, for example after editing it in Excalidraw.
mermaid  turns a Mermaid flowchart or sequence diagram into a spec to edit before building.

A file that already exists is replaced only when this plugin wrote it and it has not changed
since; otherwise the command stops with exit code 3 and --replace overrides it.

Exit codes: 0 done, 1 the checks found problems (nothing written), 2 bad input,
3 an existing file would be replaced (nothing written), 4 a PNG was required but not made.
Lines starting with "Warning:" (arrows that cross or touch) and "Note:" do not change the exit code.
"""
import argparse
import json
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import diagram_check  # noqa: E402
import diagram_layout  # noqa: E402
import diagram_mermaid  # noqa: E402
import diagram_png  # noqa: E402
import diagram_scene  # noqa: E402
import diagram_spec  # noqa: E402
import diagram_svg  # noqa: E402

NAME_OK = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$")
SUFFIXES = (".diagram.json", ".json", ".mmd", ".mermaid", ".excalidraw")


def say(*lines):
    for line in lines:
        print(line)


def err(*lines):
    for line in lines:
        print(line, file=sys.stderr)


def shown(path):
    """The path relative to the current folder when it lies inside it, else absolute."""
    rel = os.path.relpath(path)
    return path if rel == os.pardir or rel.startswith(os.pardir + os.sep) else rel


def _base_name(path):
    name = os.path.basename(path)
    for suffix in SUFFIXES:
        if name.lower().endswith(suffix):
            return name[:-len(suffix)] or "diagram"
    return name or "diagram"


def _read_text(path):
    if path == "-":
        return sys.stdin.read()
    with open(path, encoding="utf-8") as f:
        return f.read()


def _print_report(report):
    say(report.summary())
    if report.problems:
        say("%d problem%s:" % (len(report.problems), "" if len(report.problems) == 1 else "s"))
        for rule, message in report.problems:
            say("  %s: %s" % (rule, message))
    else:
        say("No problems found.")
    for rule, message in report.warnings:
        say("Warning: %s: %s" % (rule, message))
    for note in report.notes:
        say("Note: " + note)


def _written_by_us(path):
    try:
        if path.endswith(".excalidraw"):
            return diagram_scene.unchanged_since_written(path)
        with open(path, "rb") as f:
            data = f.read()
        if path.endswith(".svg"):
            return diagram_svg.marker_ok(data.decode("utf-8", "replace"))
        if path.endswith(".png"):
            return diagram_png.marker_ok(data)
    except OSError:
        return False
    return False


def _blocked(paths, replace):
    """The paths that exist and may not be replaced."""
    if replace:
        return []
    return [p for p in paths if os.path.lexists(p) and not _written_by_us(p)]


def _report_blocked(blocked):
    err("These files exist and were not written by this plugin, or have changed since it wrote them:")
    for p in blocked:
        err("  " + shown(p))
    err("Nothing was written. Ask the user before replacing them, then run again with --replace,",
        "or pick another --name or --out.")
    return 3


def _outputs(args, default_dir, default_name):
    name = args.name or default_name
    if not NAME_OK.match(name):
        err("--name must be a file name of letters, digits, '.', '_', or '-', without a folder")
        return None
    folder = os.path.abspath(args.out or default_dir)
    return {ext: os.path.join(folder, name + "." + ext) for ext in ("excalidraw", "svg", "png")}


def _write_images(doc, paths, png_mode, scale):
    """Write the SVG, then the PNG unless skipped. Returns the exit code."""
    svg, width, height, skipped = diagram_svg.render(doc)
    diagram_scene.write_atomic(paths["svg"], svg.encode("utf-8"))
    say("Wrote %s (%dx%d)" % (shown(paths["svg"]), width, height))
    if skipped:
        say("Note: elements of type %s are not drawn in the SVG or PNG" % ", ".join(skipped))
    if png_mode == "skip":
        return 0
    data, browser, why = diagram_png.make(paths["svg"], width, height, scale)
    if data is None:
        say("PNG skipped: %s. The SVG holds the same drawing." % why)
        return 4 if png_mode == "require" else 0
    diagram_scene.write_atomic(paths["png"], data)
    w, h = diagram_png.size(data)
    say("Wrote %s (%dx%d) with %s" % (shown(paths["png"]), w, h, os.path.basename(browser)))
    return 0


def _load_spec(path):
    """Returns (spec, notes) or raises SystemExit(2) after printing why."""
    try:
        text = _read_text(path)
    except OSError as e:
        err("Cannot read %s (%s)" % (path, e.strerror or e))
        raise SystemExit(2)
    notes = []
    if path.lower().endswith((".mmd", ".mermaid")):
        try:
            raw, notes = diagram_mermaid.parse(text)
        except diagram_mermaid.MermaidError as e:
            err("The Mermaid text is outside the supported subset: %s" % e)
            raise SystemExit(2)
    else:
        try:
            raw = json.loads(text)
        except ValueError as e:
            err("%s is not valid JSON: %s" % (path, e))
            raise SystemExit(2)
    try:
        return diagram_spec.validate(raw), notes
    except diagram_spec.SpecError as e:
        problems = str(e).split("\n")
        err("The spec has %d problem%s:" % (len(problems), "" if len(problems) == 1 else "s"))
        for p in problems:
            err("  " + p)
        raise SystemExit(2)


def cmd_build(args):
    spec, notes = _load_spec(args.input)
    for note in notes:
        say("Note: " + note)
    doc, report, scale, error = diagram_layout.build(spec)
    if doc is None or report is None or report.problems:
        if report is not None:
            _print_report(report)
        if error is not None:
            say("layout: %s" % error)
        say("Nothing was written. Fix the spec and build again.")
        return 1
    paths = _outputs(args, os.path.dirname(os.path.abspath(args.input)) if args.input != "-" else os.getcwd(),
                     _base_name(args.input) if args.input != "-" else "diagram")
    if paths is None:
        return 2
    targets = [paths["excalidraw"], paths["svg"]] + ([paths["png"]] if args.png != "skip" else [])
    blocked = _blocked(targets, args.replace)
    if blocked:
        return _report_blocked(blocked)
    _print_report(report)
    if scale > 1:
        say("Spacing was widened %gx so that every label and arrow fits." % scale)
    diagram_scene.write_atomic(paths["excalidraw"], diagram_scene.dumps(doc).encode("utf-8"))
    say("Wrote %s" % shown(paths["excalidraw"]))
    return _write_images(doc, paths, args.png, args.scale)


def cmd_check(args):
    try:
        doc = diagram_scene.load(args.input)
    except diagram_scene.SceneError as e:
        err(str(e))
        return 2
    report = diagram_check.check(doc)
    _print_report(report)
    return 1 if report.problems else 0


def cmd_render(args):
    try:
        doc = diagram_scene.load(args.input)
    except diagram_scene.SceneError as e:
        err(str(e))
        return 2
    paths = _outputs(args, os.path.dirname(os.path.abspath(args.input)), _base_name(args.input))
    if paths is None:
        return 2
    blocked = _blocked([paths["svg"]] + ([paths["png"]] if args.png != "skip" else []), args.replace)
    if blocked:
        return _report_blocked(blocked)
    return _write_images(doc, paths, args.png, args.scale)


def cmd_mermaid(args):
    try:
        spec, notes = diagram_mermaid.parse(_read_text(args.input))
    except OSError as e:
        err("Cannot read %s (%s)" % (args.input, e.strerror or e))
        return 2
    except diagram_mermaid.MermaidError as e:
        err("The Mermaid text is outside the supported subset: %s" % e)
        return 2
    text = json.dumps(spec, indent=2, ensure_ascii=False) + "\n"
    if not args.output:
        sys.stdout.write(text)
        for note in notes:
            err("Note: " + note)
        return 0
    if os.path.lexists(args.output) and not args.replace:
        err("%s exists. Nothing was written. Ask the user before replacing it, then run again with --replace." % args.output)
        return 3
    diagram_scene.write_atomic(args.output, text.encode("utf-8"))
    say("Wrote %s" % args.output)
    for note in notes:
        say("Note: " + note)
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="excalidraw_diagram.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command")
    for name in ("build", "render"):
        p = sub.add_parser(name)
        p.add_argument("input")
        p.add_argument("--out")
        p.add_argument("--name")
        p.add_argument("--png", choices=("auto", "skip", "require"), default="auto")
        p.add_argument("--scale", type=int, choices=(1, 2, 3), default=2)
        p.add_argument("--replace", action="store_true")
    p = sub.add_parser("check")
    p.add_argument("input")
    p = sub.add_parser("mermaid")
    p.add_argument("input")
    p.add_argument("--output", "-o")
    p.add_argument("--replace", action="store_true")
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 2
    try:
        return {"build": cmd_build, "check": cmd_check, "render": cmd_render, "mermaid": cmd_mermaid}[args.command](args)
    except SystemExit as e:
        return e.code if isinstance(e.code, int) else 2
    except OSError as e:
        err("Cannot write: %s" % (e.strerror or e))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
