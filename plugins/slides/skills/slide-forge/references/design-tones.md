# The four tones

The four design tones that phase 1 draws its three HTML mockups from: the colors, the font, and the feel of each, in one place.

## deep-navy (default)

A dark navy background, white text, and a blue accent. For talks at technical meetups and software conferences.

| Item | Value |
|---|---|
| Background | `#0B1F3A` (dark navy) |
| Text | `#FFFFFF` (white) |
| Accent | `#4F9DFF` (cyan blue) |
| Font | Hiragino Sans (East Asian, Latin, and complex scripts) |
| Feel | Professional, technical, formal |

## light-mono

A light gray background, black text, and a dark gray accent. For large companies, public offices, and formal presentations.

| Item | Value |
|---|---|
| Background | `#F5F5F5` |
| Text | `#1A1A1A` |
| Accent | `#3A3A3A` |
| Font | Hiragino Sans |
| Feel | Calm, trustworthy, no decoration |

## mono-accent

A white background, black text, and a red accent. Strong emphasis for short talks and pitches.

| Item | Value |
|---|---|
| Background | `#FFFFFF` |
| Text | `#0F0F0F` |
| Accent | `#E53E3E` (red) |
| Font | Hiragino Sans |
| Feel | Sharp, high impact, startup pitch |

## vibrant-pop

A yellow background, black text, and a red accent. For event announcements, young audiences, and friendly occasions.

| Item | Value |
|---|---|
| Background | `#FFE66D` |
| Text | `#1A1A1A` |
| Accent | `#E53E3E` |
| Font | Hiragino Sans |
| Feel | Playful, energetic, eye-catching |

## Choosing a tone

Pass `--theme {deep-navy|light-mono|mono-accent|vibrant-pop}`. The default is `deep-navy`.

The `THEMES` dictionary in `scripts/build_pptx.py` holds the same colors as this page. Change both together when adding a tone.

## Related files

- `scripts/build_pptx.py`, which defines `THEMES`
- `references/pptx-build-spec.md`, with the RGB values of each tone
