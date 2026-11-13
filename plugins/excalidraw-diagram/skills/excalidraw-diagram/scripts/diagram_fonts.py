"""The fonts the SVG embeds, so the hand-drawn and rounded text looks the same on every machine.

Excalidraw ships Excalifont and Nunito split into files by Unicode range; data/fonts/ holds
unmodified copies of those files. The SVG embeds only the files whose ranges hold a character
of the text in that font, as data: URLs, so the picture needs no network and no installed font.
Characters outside every range, such as Japanese, fall back to the system fonts in the stack.
"""
import base64
import os

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "fonts")
EXCALIFONT = [
    ("Excalifont-Regular-a88b72a24fb54c9f94e3b5fdaa7481c9.woff2",
     "U+20-7e,U+a0-a3,U+a5-a6,U+a8-ab,U+ad-b1,U+b4,U+b6-b8,U+ba-ff,U+131,U+152-153,U+2bc,U+2c6,U+2da,U+2dc,"
     "U+304,U+308,U+2013-2014,U+2018-201a,U+201c-201e,U+2020,U+2022,U+2024-2026,U+2030,U+2039-203a,U+20ac,"
     "U+2122,U+2212"),
    ("Excalifont-Regular-be310b9bcd4f1a43f571c46df7809174.woff2",
     "U+100-130,U+132-137,U+139-149,U+14c-151,U+154-17e,U+192,U+1fc-1ff,U+218-21b,U+237,U+1e80-1e85,"
     "U+1ef2-1ef3,U+2113"),
    ("Excalifont-Regular-b9dcf9d2e50a1eaf42fc664b50a3fd0d.woff2", "U+400-45f,U+490-491,U+2116"),
    ("Excalifont-Regular-41b173a47b57366892116a575a43e2b6.woff2",
     "U+37e,U+384-38a,U+38c,U+38e-393,U+395-3a1,U+3a3-3a8,U+3aa-3cf,U+3d7"),
    ("Excalifont-Regular-3f2c5db56cc93c5a6873b1361d730c16.woff2",
     "U+2c7,U+2d8-2d9,U+2db,U+2dd,U+302,U+306-307,U+30a-30c,U+326-328,U+212e,U+2211,U+fb01-fb02"),
    ("Excalifont-Regular-349fac6ca4700ffec595a7150a0d1e1d.woff2",
     "U+462-463,U+472-475,U+4d8-4d9,U+4e2-4e3,U+4e6-4e9,U+4ee-4ef"),
    ("Excalifont-Regular-623ccf21b21ef6b3a0d87738f77eb071.woff2", "U+300-301,U+303"),
]
NUNITO = [
    ("Nunito-Regular-XRXI3I6Li01BKofiOc5wtlZ2di8HDIkhdTQ3j6zbXWjgeg.woff2",
     "U+0-ff,U+131,U+152-153,U+2bb-2bc,U+2c6,U+2da,U+2dc,U+304,U+308,U+329,U+2000-206f,U+2074,U+20ac,U+2122,"
     "U+2191,U+2193,U+2212,U+2215,U+feff,U+fffd"),
    ("Nunito-Regular-XRXI3I6Li01BKofiOc5wtlZ2di8HDIkhdTo3j6zbXWjgevT5.woff2",
     "U+100-2af,U+304,U+308,U+329,U+1e00-1e9f,U+1ef2-1eff,U+2020,U+20a0-20ab,U+20ad-20c0,U+2113,U+2c60-2c7f,"
     "U+a720-a7ff"),
    ("Nunito-Regular-XRXI3I6Li01BKofiOc5wtlZ2di8HDIkhdTk3j6zbXWjgevT5.woff2",
     "U+460-52f,U+1c80-1c88,U+20b4,U+2de0-2dff,U+a640-a69f,U+fe2e-fe2f"),
    ("Nunito-Regular-XRXI3I6Li01BKofiOc5wtlZ2di8HDIkhdTA3j6zbXWjgevT5.woff2",
     "U+301,U+400-45f,U+490-491,U+4b0-4b1,U+2116"),
    ("Nunito-Regular-XRXI3I6Li01BKofiOc5wtlZ2di8HDIkhdTs3j6zbXWjgevT5.woff2",
     "U+102-103,U+110-111,U+128-129,U+168-169,U+1a0-1a1,U+1af-1b0,U+300-301,U+303-304,U+308-309,U+323,"
     "U+329,U+1ea0-1ef9,U+20ab"),
]
# Excalidraw's fontFamily numbers: 1 Virgil (Excalifont took its place), 5 Excalifont, 6 Nunito.
EMBEDDED = {1: ("Excalifont", EXCALIFONT), 5: ("Excalifont", EXCALIFONT), 6: ("Nunito", NUNITO)}


def _ranges(spec):
    out = []
    for part in spec.split(","):
        lo, _, hi = part.strip()[2:].partition("-")
        out.append((int(lo, 16), int(hi or lo, 16)))
    return out


def family_name(family):
    """The name the SVG uses for an embedded font, or None for a system font."""
    hit = EMBEDDED.get(family)
    return hit[0] if hit else None


def faces(texts):
    """@font-face rules for (fontFamily, text) pairs, one per font file a character falls in.

    Returns (css, missing): missing names font files that should be embedded but cannot be read.
    """
    want = {}
    for family, text in texts:
        hit = EMBEDDED.get(family)
        if hit:
            want.setdefault(hit[0], (hit[1], set()))[1].update(ord(c) for c in text)
    rules, missing = [], []
    for name in sorted(want):
        files, chars = want[name]
        for filename, spec in files:
            ranges = _ranges(spec)
            if not any(lo <= c <= hi for c in chars for lo, hi in ranges):
                continue
            try:
                with open(os.path.join(DIR, filename), "rb") as f:
                    data = base64.b64encode(f.read()).decode("ascii")
            except OSError:
                missing.append(filename)
                continue
            rules.append("@font-face{font-family:'%s';src:url(data:font/woff2;base64,%s) format('woff2');"
                         "unicode-range:%s}" % (name, data, spec))
    return "".join(rules), missing
