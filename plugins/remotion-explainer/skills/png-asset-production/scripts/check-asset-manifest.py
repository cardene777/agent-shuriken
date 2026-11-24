#!/usr/bin/env python3
"""Checks an asset-manifest.json against the asset manifest contract (formats/asset-manifest.md).

It decides whether the manifest has every required field, one supported material style, whole-image
motion only, and the paths of the raw PNG, the alpha PNG, and the three review composites. It then
reads those files relative to the manifest's folder: each must exist and be a PNG with a positive
size, the alpha PNG must match the raw PNG in size and hold transparent and visible pixels, and an
outline handoff, when set, must exist. PNG files are read with the standard library (zlib, struct);
the pixels of 8-bit, non-interlaced PNGs of every color type are read.
Prints the result as JSON. Exits 0 when it passes, 1 when the manifest needs revising, 2 when called
wrongly or the manifest cannot be read.

usage: python3 check-asset-manifest.py <asset-manifest.json>
"""
import json
import struct
import sys
import zlib
from pathlib import Path

VALID_STYLES = {
    "felt-applique", "torn-paper-collage", "ink-wash-linework",
    "clay-relief", "ceramic-miniature", "custom",
}
REQUIRED = [
    "schemaVersion", "assetId", "role", "styleId", "staticRoleReason",
    "motionBoundary", "allowedMotion", "forbiddenExplanationWork", "generation", "review",
]
ALLOWED_MOTION = {"translate", "scale", "fade", "crop"}
GENERATION_FILES = ["rawPng", "alphaPng"]
REVIEW_FILES = ["lightComposite", "darkComposite", "sceneComposite"]
SIGNATURE = b"\x89PNG\r\n\x1a\n"
VISIBLE_ALPHA = 16
# Maps an alpha byte to 1 when it is above VISIBLE_ALPHA, so bytes.count(1) counts visible pixels.
VISIBLE_TABLE = bytes(1 if value > VISIBLE_ALPHA else 0 for value in range(256))


class PngError(Exception):
    pass


def read_chunks(data):
    """Returns the image header, palette, transparency, and image data of a PNG."""
    if data[:8] != SIGNATURE:
        raise PngError("signature")
    offset = 8
    header = palette = transparency = None
    image = []
    while offset + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR" and len(body) >= 13:
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body[:13])
            header = {"width": width, "height": height, "depth": depth, "color": color, "interlace": interlace}
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            transparency = body
        elif kind == b"IDAT":
            image.append(body)
        elif kind == b"IEND":
            break
    return header, palette, transparency, b"".join(image)


def unfilter(kind, line, previous, channels):
    """Undoes one of the five PNG row filters in place."""
    if kind == 0:
        return line
    if kind == 1:
        for i in range(channels, len(line)):
            line[i] = (line[i] + line[i - channels]) & 0xFF
        return line
    if kind == 2:
        return bytearray((a + b) & 0xFF for a, b in zip(line, previous))
    if kind == 3:
        for i in range(len(line)):
            left = line[i - channels] if i >= channels else 0
            line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        return line
    if kind == 4:
        for i in range(len(line)):
            a = line[i - channels] if i >= channels else 0
            b = previous[i]
            c = previous[i - channels] if i >= channels else 0
            pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
            predicted = a if pa <= pb and pa <= pc else b if pb <= pc else c
            line[i] = (line[i] + predicted) & 0xFF
        return line
    raise PngError(f"uses the unknown row filter {kind}")


def alpha_counts(header, palette, transparency, image):
    """Returns (transparent, visible) pixel counts, or None when the PNG has no alpha channel."""
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(header["color"])
    if header["depth"] != 8 or channels is None or header["interlace"] != 0:
        raise PngError("is not an 8-bit, non-interlaced PNG; save it as an 8-bit RGBA PNG")
    color = header["color"]
    if color in (0, 2, 3) and transparency is None:
        return None
    if color == 3 and palette is None:
        raise PngError("uses a palette it does not hold")
    try:
        raw = zlib.decompress(image)
    except zlib.error as error:
        raise PngError(f"has image data that cannot be inflated: {error}")
    width, height = header["width"], header["height"]
    stride = width * channels
    if len(raw) < (stride + 1) * height:
        raise PngError("is cut short")
    if color == 3:
        table = bytes(transparency[i] if i < len(transparency) else 255 for i in range(256))
    elif color == 0:
        key = struct.unpack(">H", transparency[:2])[0] if len(transparency) >= 2 else -1
        table = bytes(0 if value == key else 255 for value in range(256))
    elif color == 2:
        key = bytes(value & 0xFF for value in struct.unpack(">HHH", transparency[:6])) if len(transparency) >= 6 else None
    transparent = visible = 0
    previous = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        line = unfilter(raw[start], bytearray(raw[start + 1:start + 1 + stride]), previous, channels)
        previous = line
        if color == 6:
            alphas = bytes(line[3::4])
        elif color == 4:
            alphas = bytes(line[1::2])
        elif color == 2:
            alphas = bytes(0 if key and line[i:i + 3] == key else 255 for i in range(0, stride, 3))
        else:
            alphas = bytes(line).translate(table)
        transparent += alphas.count(0)
        visible += alphas.translate(VISIBLE_TABLE).count(1)
    return transparent, visible


def main():
    if len(sys.argv) != 2 or sys.argv[1].startswith("-"):
        print("usage: check-asset-manifest.py <asset-manifest.json>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1]).resolve()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(f"cannot read {sys.argv[1]}: {error}", file=sys.stderr)
        return 2
    if not isinstance(data, dict):
        print(f"cannot read {sys.argv[1]}: the file is not a JSON object", file=sys.stderr)
        return 2

    asset = data.get("assetId") if isinstance(data.get("assetId"), str) and data.get("assetId") else "manifest"
    issues = []

    def add(rule, field, message):
        issue = {"rule": rule, "asset": asset}
        if field:
            issue["field"] = field
        issue["message"] = message
        issues.append(issue)

    for field in REQUIRED:
        if field not in data:
            add("required-field", field, f"{field} is missing")

    style = data.get("styleId")
    if "styleId" in data and style not in VALID_STYLES:
        add("style-id", "styleId", f"styleId {style!r} is not one of {', '.join(sorted(VALID_STYLES))}")
    if style == "custom" and not data.get("customStyleContract"):
        add("custom-style-contract", "customStyleContract", "the custom style needs customStyleContract")
    if "motionBoundary" in data and data["motionBoundary"] != "whole-image":
        add("motion-boundary", "motionBoundary", "motionBoundary must be whole-image")
    motion = data.get("allowedMotion")
    if "allowedMotion" in data and (not isinstance(motion, list) or not set(map(str, motion)) <= ALLOWED_MOTION):
        add("allowed-motion", "allowedMotion", "allowedMotion is a list of translate, scale, fade, and crop only")

    # The files to read: (field, path relative to the manifest folder).
    files = []
    for group, names, rule in (("generation", GENERATION_FILES, "generation-file"), ("review", REVIEW_FILES, "review-file")):
        section = data.get(group)
        if group in data and not isinstance(section, dict):
            add(rule, group, f"{group} must be an object")
            continue
        for name in names:
            if group not in data:
                continue
            value = section.get(name)
            if not isinstance(value, str) or not value.strip():
                add(rule, f"{group}.{name}", f"{group}.{name} is required")
            else:
                files.append((f"{group}.{name}", value))

    handoff = data.get("outlineHandoff")
    if handoff is not None and (not isinstance(handoff, str) or not handoff.strip()):
        add("outline-handoff", "outlineHandoff", "outlineHandoff is null or the path of an outline-handoff.json")

    folder = path.parent
    sizes = {}
    for field, value in files:
        target = folder / value
        try:
            content = target.read_bytes()
        except OSError:
            add("missing-file", field, f"{field} names {value}, which does not exist or cannot be read")
            continue
        try:
            header, palette, transparency, image = read_chunks(content)
        except PngError:
            add("png-signature", field, f"{value} does not start with the PNG signature")
            continue
        if not header or not header["width"] or not header["height"]:
            add("png-size", field, f"{value} has no image header with a positive width and height")
            continue
        sizes[field] = (header["width"], header["height"])
        if field != "generation.alphaPng":
            continue
        try:
            counts = alpha_counts(header, palette, transparency, image)
        except PngError as error:
            add("png-alpha", field, f"{value} cannot be read for its alpha: it {error}")
            continue
        if counts is None:
            add("png-alpha", field, f"{value} has no alpha channel")
        elif counts[0] == 0:
            add("png-alpha", field, f"{value} has no fully transparent pixel")
        elif counts[1] == 0:
            add("png-alpha", field, f"{value} has no pixel with an alpha above {VISIBLE_ALPHA}")

    raw, alpha = sizes.get("generation.rawPng"), sizes.get("generation.alphaPng")
    if raw and alpha and raw != alpha:
        add("png-size", "generation.alphaPng",
            f"the alpha PNG is {alpha[0]}x{alpha[1]}, not the {raw[0]}x{raw[1]} of the raw PNG it was made from")

    if isinstance(handoff, str) and handoff.strip() and not (folder / handoff).is_file():
        add("missing-file", "outlineHandoff", f"outlineHandoff names {handoff}, which does not exist")

    result = {
        "check": "asset-manifest",
        "decision": "revise" if issues else "pass",
        "issueCount": len(issues),
        "source": str(path),
        "issues": issues,
    }
    print(json.dumps(result, indent=2))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
