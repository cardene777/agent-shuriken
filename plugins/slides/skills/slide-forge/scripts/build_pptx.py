#!/usr/bin/env python3
"""build_pptx.py: builds a 1280 x 720 (16:9) PowerPoint slide from content.json.

Implements references/pptx-build-spec.md. Needs python-pptx and Pillow, which uv fetches for one
run, so nothing is installed into the user's Python:

    uv run --with python-pptx --with Pillow --no-project python3 build_pptx.py content.json out.pptx [--theme deep-navy]

content.json (references/pptx-build-spec.md, "content.json"):
{
  "title": "About me",
  "subtitle": "Alex Kim / Support team lead",
  "avatar": "./assets/avatar.jpg" or a base64 data URL,
  "bullets": ["..."],
  "footer": "Spring 2026"
}
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import tempfile
from pathlib import Path

RUN_HINT = "Run it through uv: uv run --with python-pptx --with Pillow --no-project python3 build_pptx.py ..."

try:
    from pptx import Presentation
    from pptx.dml.color import RGBColor
    from pptx.util import Inches, Pt
    from pptx.oxml.ns import qn
except ImportError as e:
    print(f"ERROR: python-pptx is not available ({e}). {RUN_HINT}", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
except ImportError as e:
    print(f"ERROR: Pillow is not available ({e}). {RUN_HINT}", file=sys.stderr)
    sys.exit(1)


THEMES = {
    "deep-navy": {
        "bg": RGBColor(0x0B, 0x1F, 0x3A),
        "fg": RGBColor(0xFF, 0xFF, 0xFF),
        "accent": RGBColor(0x4F, 0x9D, 0xFF),
    },
    "light-mono": {
        "bg": RGBColor(0xF5, 0xF5, 0xF5),
        "fg": RGBColor(0x1A, 0x1A, 0x1A),
        "accent": RGBColor(0x3A, 0x3A, 0x3A),
    },
    "mono-accent": {
        "bg": RGBColor(0xFF, 0xFF, 0xFF),
        "fg": RGBColor(0x0F, 0x0F, 0x0F),
        "accent": RGBColor(0xE5, 0x3E, 0x3E),
    },
    "vibrant-pop": {
        "bg": RGBColor(0xFF, 0xE6, 0x6D),
        "fg": RGBColor(0x1A, 0x1A, 0x1A),
        "accent": RGBColor(0xE5, 0x3E, 0x3E),
    },
}

FONT_NAME = "Hiragino Sans"
# The bullet mark before each item: U+30FB (middle dot) and a space.
BULLET = chr(0x30FB) + " "


def _apply_font(paragraph, size_pt: float = 18, bold: bool = False, color: RGBColor | None = None) -> None:
    """Sets the size, weight, and color of every run, and pins its East Asian, Latin, and
    complex-script fonts to Hiragino Sans."""
    for run in paragraph.runs:
        run.font.name = FONT_NAME
        run.font.size = Pt(size_pt)
        run.font.bold = bold
        if color is not None:
            run.font.color.rgb = color
        # python-pptx keeps a run's <a:r> element in _r and offers no public way to set ea and cs.
        rPr = run._r.get_or_add_rPr()
        for tag in ("latin", "ea", "cs"):
            existing = rPr.find(qn(f"a:{tag}"))
            if existing is not None:
                rPr.remove(existing)
            elem = rPr.makeelement(qn(f"a:{tag}"), {"typeface": FONT_NAME})
            rPr.append(elem)


def crop_center_square(img_path: str) -> str:
    """Crops the picture to its centered square with Pillow and returns the path of a temporary
    PNG (references/pptx-build-spec.md, "Crop photos to a centered square")."""
    img = Image.open(img_path)
    if img.mode not in ("RGB", "RGBA"):
        img = img.convert("RGB")
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = img.crop((left, top, left + side, top + side))
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    cropped.save(tmp.name, format="PNG")
    return tmp.name


def resolve_avatar(avatar: str) -> str:
    """Decodes a base64 data URL into a temporary file and returns its path; returns a file path
    unchanged."""
    if avatar.startswith("data:image"):
        # data:image/png;base64,XXXX
        header, b64 = avatar.split(",", 1)
        ext = ".png"
        if "jpeg" in header or "jpg" in header:
            ext = ".jpg"
        elif "webp" in header:
            ext = ".webp"
        tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
        tmp.write(base64.b64decode(b64))
        tmp.close()
        return tmp.name
    return avatar


def estimate_lines(text: str, chars_per_line: int = 30) -> int:
    """Estimates how many lines a text takes from its length (references/pptx-build-spec.md,
    "Keep bullets from overlapping")."""
    return max(1, (len(text) + chars_per_line - 1) // chars_per_line)


def build_slide(content: dict, theme_name: str = "deep-navy") -> Presentation:
    """Builds a one-slide presentation from the content.json dictionary."""
    if theme_name not in THEMES:
        print(f"WARN: unknown theme '{theme_name}', falling back to 'deep-navy'", file=sys.stderr)
        theme_name = "deep-navy"
    theme = THEMES[theme_name]

    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)

    blank_layout = prs.slide_layouts[6]  # blank layout
    slide = prs.slides.add_slide(blank_layout)

    # The background is a rectangle shape rather than slide.background.fill, which PowerPoint
    # versions show more consistently.
    bg = slide.shapes.add_shape(
        1,  # MSO_SHAPE.RECTANGLE
        Inches(0), Inches(0), prs.slide_width, prs.slide_height,
    )
    bg.fill.solid()
    bg.fill.fore_color.rgb = theme["bg"]
    bg.line.fill.background()

    # title
    if content.get("title"):
        tb = slide.shapes.add_textbox(Inches(0.7), Inches(0.5), Inches(11), Inches(1.2))
        tf = tb.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = content["title"]
        _apply_font(p, size_pt=44, bold=True, color=theme["fg"])

    # subtitle
    if content.get("subtitle"):
        tb = slide.shapes.add_textbox(Inches(0.7), Inches(1.8), Inches(11), Inches(0.7))
        tf = tb.text_frame
        p = tf.paragraphs[0]
        p.text = content["subtitle"]
        _apply_font(p, size_pt=22, bold=False, color=theme["accent"])

    # avatar, cropped to a centered square. add_picture copies the image into the slide, so the
    # temporary files are deleted right after.
    if content.get("avatar"):
        temporary = []
        try:
            resolved = resolve_avatar(content["avatar"])
            if resolved != content["avatar"]:
                temporary.append(resolved)
            cropped = crop_center_square(resolved)
            temporary.append(cropped)
            slide.shapes.add_picture(cropped, Inches(9), Inches(3), Inches(3), Inches(3))
        except (FileNotFoundError, OSError) as e:
            print(f"WARN: avatar load failed ({e}), skipping", file=sys.stderr)
        finally:
            for path in temporary:
                Path(path).unlink(missing_ok=True)

    # bullets, each placed below the previous one by its estimated height
    bullets = content.get("bullets", [])
    if bullets:
        cursor_y = Inches(3)
        for item in bullets:
            lines = estimate_lines(item)
            height = Pt(28.0 * lines)
            tb = slide.shapes.add_textbox(Inches(0.7), cursor_y, Inches(8), height)
            tf = tb.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.text = BULLET + item
            _apply_font(p, size_pt=18, bold=False, color=theme["fg"])
            cursor_y += height + Pt(8)

    # footer
    if content.get("footer"):
        tb = slide.shapes.add_textbox(Inches(0.7), Inches(6.8), Inches(11), Inches(0.5))
        tf = tb.text_frame
        p = tf.paragraphs[0]
        p.text = content["footer"]
        _apply_font(p, size_pt=12, bold=False, color=theme["fg"])

    return prs


def main() -> int:
    parser = argparse.ArgumentParser(description="content.json -> PowerPoint (16:9, 1280x720)")
    parser.add_argument("content_json", help="content.json path")
    parser.add_argument("out_pptx", help="output .pptx path")
    parser.add_argument("--theme", default="deep-navy", choices=list(THEMES.keys()))
    args = parser.parse_args()

    content_path = Path(args.content_json)
    if not content_path.is_file():
        print(f"ERROR: content.json not found: {content_path}", file=sys.stderr)
        return 1

    try:
        content = json.loads(content_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERROR: content.json is not valid JSON: {e}", file=sys.stderr)
        return 1

    prs = build_slide(content, theme_name=args.theme)
    prs.save(args.out_pptx)
    print(f"OK: {args.out_pptx} generated (theme={args.theme})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
