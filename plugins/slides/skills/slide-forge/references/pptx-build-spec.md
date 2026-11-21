# PowerPoint rules

The rules `scripts/build_pptx.py` follows so that the slide looks the same when opened in PowerPoint.
The script runs through `uv run --with python-pptx --with Pillow`, which fetches both packages for that run only.

## Slide size

| Item | Value |
|---|---|
| Aspect ratio | 16:9 |
| Pixels | 1280 x 720 px, the size of the HTML mockup |
| EMU | width 12192000, height 6858000 (`Inches(13.333)` by `Inches(7.5)`) |

`prs = Presentation()`, then `prs.slide_width = Inches(13.333)` and `prs.slide_height = Inches(7.5)`. A 4:3 slide is not supported.

## Crop photos to a centered square

`slide.shapes.add_picture()` stretches a picture whose frame has another aspect ratio, so a face looks long.

The builder opens the picture with Pillow, crops its centered square, and adds that square through a temporary file.

```python
from PIL import Image
import tempfile

def crop_center_square(img_path: str) -> str:
    img = Image.open(img_path)
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = img.crop((left, top, left + side, top + side))
    tmp = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    cropped.save(tmp.name, format='PNG')
    return tmp.name

cropped_path = crop_center_square('avatar.jpg')
slide.shapes.add_picture(cropped_path, Inches(1), Inches(1), Inches(3), Inches(3))
```

The frame is square too (`Inches(3)` by `Inches(3)`), so a square picture in a square frame is not stretched.

## Keep bullets from overlapping

A long bullet in a box of fixed height runs into the bullet below it.
The builder estimates each bullet's lines from its length and places the next bullet below the previous one.

```python
def estimate_lines(text: str, chars_per_line: int = 30) -> int:
    return max(1, (len(text) + chars_per_line - 1) // chars_per_line)

def add_bullet_list(slide, items: list[str], left, top, width, line_height_pt: float = 22.0):
    cursor_y = top
    for item in items:
        lines = estimate_lines(item)
        height = Pt(line_height_pt * lines)
        tb = slide.shapes.add_textbox(left, cursor_y, width, height)
        tf = tb.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = BULLET + item  # BULLET = chr(0x30FB) + " ", a middle dot
        _apply_font(p)
        cursor_y += height + Pt(4)  # 4 pt gap
```

`chars_per_line` depends on the font and the box width. About 30 characters fit in Hiragino Sans at 18 pt in a box 8 inches wide; check it against a real deck.

## Pin the font

When a machine replaces the font, the layout shifts.
The builder pins the East Asian (`ea`), Latin (`latin`), and complex-script (`cs`) fonts of every run to Hiragino Sans.

```python
from pptx.util import Pt
from pptx.oxml.ns import qn

def _apply_font(paragraph, font_name='Hiragino Sans', size_pt=18, bold=False, color=None):
    for run in paragraph.runs:
        run.font.name = font_name
        run.font.size = Pt(size_pt)
        run.font.bold = bold
        if color:
            run.font.color.rgb = color
        # Pin the East Asian, Latin, and complex-script fonts to the same font.
        rPr = run._r.get_or_add_rPr()
        for tag in ('latin', 'ea', 'cs'):
            existing = rPr.find(qn(f'a:{tag}'))
            if existing is not None:
                rPr.remove(existing)
            elem = rPr.makeelement(qn(f'a:{tag}'), {'typeface': font_name})
            rPr.append(elem)
```

python-pptx keeps a run's `<a:r>` element in `run._r`; it has no public setting for the `ea` and `cs` fonts.
On Windows, where Hiragino Sans is missing, a theme can switch the font to `Yu Gothic` or `Meiryo`.

## Theme colors

```python
THEMES = {
    'deep-navy': {
        'bg': RGBColor(0x0B, 0x1F, 0x3A),
        'fg': RGBColor(0xFF, 0xFF, 0xFF),
        'accent': RGBColor(0x4F, 0x9D, 0xFF),
    },
    'light-mono': {
        'bg': RGBColor(0xF5, 0xF5, 0xF5),
        'fg': RGBColor(0x1A, 0x1A, 0x1A),
        'accent': RGBColor(0x3A, 0x3A, 0x3A),
    },
    'mono-accent': {
        'bg': RGBColor(0xFF, 0xFF, 0xFF),
        'fg': RGBColor(0x0F, 0x0F, 0x0F),
        'accent': RGBColor(0xE5, 0x3E, 0x3E),
    },
    'vibrant-pop': {
        'bg': RGBColor(0xFF, 0xE6, 0x6D),
        'fg': RGBColor(0x1A, 0x1A, 0x1A),
        'accent': RGBColor(0xE5, 0x3E, 0x3E),
    },
}
```

Choose one with `--theme deep-navy`. The default is `deep-navy`.

## content.json

```json
{
  "title": "About me",
  "subtitle": "Alex Kim / Support team lead",
  "avatar": "./assets/avatar.jpg",
  "bullets": [
    "Ten years in customer support",
    "Runs the night shift",
    "Speaks at local meetups"
  ],
  "footer": "Spring 2026"
}
```

The **Export JSON** button of the edit page downloads `content.json`, and `build_pptx.py` reads it in phase 3.
`avatar` is a path or a base64 data URL. Every key is optional; the builder leaves out what is missing.

## What goes where on the slide

| Part | Position and size | Text |
|---|---|---|
| Background | A rectangle over the whole slide | The theme's `bg` |
| Title | 0.7 in from the left, 0.5 in from the top, 11 in wide | 44 pt bold, the theme's `fg` |
| Subtitle | 0.7 in, 1.8 in, 11 in wide | 22 pt, the theme's `accent` |
| Photo | 9 in, 3 in, 3 in square | Cropped to a centered square |
| Bullets | 0.7 in, from 3 in down, 8 in wide, 28 pt per estimated line and 8 pt between bullets | 18 pt, the theme's `fg`, each after a middle dot |
| Footer | 0.7 in, 6.8 in, 11 in wide | 12 pt, the theme's `fg` |

## Related files

- `scripts/build_pptx.py`, which follows these rules
- `references/design-tones.md`, with the tones behind each theme
