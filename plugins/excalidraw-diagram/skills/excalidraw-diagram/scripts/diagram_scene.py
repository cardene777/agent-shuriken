"""Build Excalidraw elements, and read and write `.excalidraw` files.

An `.excalidraw` file is JSON: {"type": "excalidraw", "version": 2, "source", "elements",
"appState", "files"}. Every element here carries the fields the Excalidraw editor writes
itself, and ids, seeds, and timestamps are fixed so the same spec gives the same file.

A file written by this plugin also has a top-level "generator" entry with a digest of its
elements. The editor drops unknown entries when it saves, so a file that still has a
matching digest is known to be unchanged since this plugin wrote it.
"""
import hashlib
import json
import os
import tempfile
import zlib

NAME = "excalidraw-diagram"
SOURCE = "https://github.com/cardene777/agent-shuriken/tree/main/plugins/excalidraw-diagram"
UPDATED = 1700000000000  # a fixed timestamp keeps the output reproducible
INK = "#1e1e1e"


class SceneError(Exception):
    """The file is not a readable `.excalidraw` scene."""


def _seed(eid, salt):
    return (zlib.crc32((salt + ":" + eid).encode("utf-8")) & 0x7FFFFFFF) or 1


def base(kind, eid, x, y, w, h, stroke=INK, fill="transparent", fill_style="solid",
         stroke_width=2, stroke_style="solid", roughness=0, roundness=None, groups=()):
    return {
        "id": eid, "type": kind, "x": x, "y": y, "width": w, "height": h, "angle": 0,
        "strokeColor": stroke, "backgroundColor": fill, "fillStyle": fill_style,
        "strokeWidth": stroke_width, "strokeStyle": stroke_style, "roughness": roughness,
        "opacity": 100, "groupIds": list(groups), "frameId": None, "roundness": roundness,
        "seed": _seed(eid, "seed"), "version": 1, "versionNonce": _seed(eid, "nonce"),
        "isDeleted": False, "boundElements": None, "updated": UPDATED, "link": None,
        "locked": False,
    }


def text(eid, x, y, w, h, content, size, family, line_height, align="center", valign="middle",
         container=None, color=INK, groups=()):
    e = base("text", eid, x, y, w, h, stroke=color, groups=groups)
    e.update({
        "text": content, "originalText": content, "fontSize": size, "fontFamily": family,
        "textAlign": align, "verticalAlign": valign, "containerId": container,
        "autoResize": True, "lineHeight": line_height,
    })
    return e


def linear(kind, eid, points, stroke=INK, stroke_width=2, stroke_style="solid", roughness=0,
           start_head=None, end_head=None, groups=()):
    """An arrow or line through absolute points, stored relative to its first point."""
    x0, y0 = points[0]
    rel = [[round(px - x0, 2), round(py - y0, 2)] for px, py in points]
    xs = [p[0] for p in rel]
    ys = [p[1] for p in rel]
    e = base(kind, eid, x0, y0, round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2), stroke=stroke,
             stroke_width=stroke_width, stroke_style=stroke_style, roughness=roughness,
             groups=groups)
    e.update({
        "points": rel, "lastCommittedPoint": None, "startBinding": None, "endBinding": None,
        "startArrowhead": start_head, "endArrowhead": end_head,
    })
    if kind == "arrow":
        e["elbowed"] = False
    return e


def bind(shape, other_id, kind):
    shape["boundElements"] = (shape["boundElements"] or []) + [{"id": other_id, "type": kind}]


def scene_digest(doc):
    payload = {"elements": doc.get("elements"), "appState": doc.get("appState"),
               "files": doc.get("files")}
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def document(elements, background="#ffffff", dark=False):
    """A scene; dark=True asks the editor, the SVG, and the PNG to show it in Excalidraw's dark mode."""
    state = {"gridSize": 20, "gridStep": 5, "gridModeEnabled": False, "viewBackgroundColor": background}
    if dark:
        state["theme"] = "dark"
    doc = {
        "type": "excalidraw", "version": 2, "source": SOURCE, "elements": elements,
        "appState": state,
        "files": {},
    }
    doc["generator"] = {"name": NAME, "digest": scene_digest(doc)}
    return doc


def dumps(doc):
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def load(path):
    """Read a scene. Raises SceneError with a reason a person can act on."""
    try:
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
    except OSError as e:
        raise SceneError("cannot read %s (%s)" % (path, e.strerror or e))
    except ValueError as e:
        raise SceneError("%s is not valid JSON (%s)" % (path, e))
    if not isinstance(doc, dict) or doc.get("type") != "excalidraw":
        raise SceneError('%s is not an Excalidraw scene: it needs "type": "excalidraw"' % path)
    if not isinstance(doc.get("elements"), list):
        raise SceneError('%s has no "elements" list' % path)
    return doc


def unchanged_since_written(path):
    """True when the scene at path still carries this plugin's digest of its own content."""
    try:
        doc = load(path)
    except SceneError:
        return False
    gen = doc.get("generator")
    return isinstance(gen, dict) and gen.get("name") == NAME and gen.get("digest") == scene_digest(doc)


def write_atomic(path, data):
    """Write bytes through a temporary file in the same folder, then rename it into place."""
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=folder, prefix="." + os.path.basename(path) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        mask = os.umask(0)
        os.umask(mask)
        os.chmod(tmp, 0o666 & ~mask)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
