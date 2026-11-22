# Theme file

A theme file holds the user's own colors, fonts, text size, page width, and corners.
`page-design.py theme <page>` writes them into a page made from one of the templates, so every page the user makes looks the same without changing the templates.

## Where it lives

The theme is read from the first of these two places that holds one.

| Order | Place | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the git repository the command runs in | The look of one project |
| 2 | `~/.design-theme.json` | The look of every page the user makes |

The repository's file is used as it is, and the home file is not merged into it.
When neither place holds a file, `theme` leaves the page as it is and ends with 0.

## What it holds

The file is JSON with up to four objects, `light`, `dark`, `font`, and `space`.
Every key may be left out, and a key left out keeps the value the page already has.
`light` and `dark` set the colors of the light and the dark theme, and `dark` is written into both dark blocks of the page, the one for the system's dark mode and the one for the dark button.

```json
{
  "light": {
    "bg": "#fafaf7",
    "surface": "#ffffff",
    "ink": "#111111",
    "sub": "#444444",
    "line": "#dddddd",
    "accent": "#0b6e4f",
    "accent-ink": "#ffffff",
    "accent-soft": "#e3f2ec",
    "bar": "#eeeeee",
    "label": "#f2f2f2"
  },
  "dark": {
    "bg": "#101312",
    "surface": "#181c1a",
    "ink": "#eeeeee",
    "sub": "#b0b8b4",
    "line": "#2c3330",
    "accent": "#5fd0a5",
    "accent-ink": "#0b1410",
    "accent-soft": "#1b3a2f",
    "bar": "#232a27",
    "label": "#1f2523"
  },
  "font": {
    "sans": "\"Inter\", sans-serif",
    "mono": "\"JetBrains Mono\", monospace",
    "size": 16,
    "line-height": 1.75
  },
  "space": {
    "page-width": 1100,
    "radius-small": 4,
    "radius": 6,
    "radius-large": 8
  }
}
```

## Keys and defaults

Each key sets one token of the page.
The four columns on the right are the values each template has before a theme is applied, and `page-design.py theme --defaults <page>` prints the same values as JSON.
A template marked "not used" has no such token, and a theme value for it is ignored.

| Key | Type | report | sheet | document | choice |
|---|---|---|---|---|---|
| `light.bg` | color | `#f5f6f8` | `#f5f6f8` | `#ffffff` | `#f5f6f8` |
| `light.surface` | color | `#ffffff` | `#ffffff` | `#ffffff` | `#ffffff` |
| `light.ink` | color | `#1b2129` | `#1b2129` | `#1b2129` | `#1b2129` |
| `light.sub` | color | `#4d5664` | `#4d5664` | `#4d5664` | `#4d5664` |
| `light.line` | color | `#dce1e7` | `#dce1e7` | `#dfe3e8` | `#dce1e7` |
| `light.accent` | color | `#2a5bd7` | `#2a5bd7` | `#2a5bd7` | `#2a5bd7` |
| `light.accent-ink` | color | `#ffffff` | `#ffffff` | `#ffffff` | `#ffffff` |
| `light.accent-soft` | color | `#e8eefc` | `#e8eefc` | `#e8eefc` | `#e8eefc` |
| `light.bar` | color | `#e9edf2` | `#e9edf2` | not used | not used |
| `light.label` | color | `#eef1f5` | `#eef1f5` | `#eef1f5` | `#eef1f5` |
| `dark.bg` | color | `#121519` | `#121519` | `#14171c` | `#121519` |
| `dark.surface` | color | `#1a1e24` | `#1a1e24` | `#1a1e24` | `#1a1e24` |
| `dark.ink` | color | `#e6e9ee` | `#e6e9ee` | `#e6e9ee` | `#e6e9ee` |
| `dark.sub` | color | `#a9b2be` | `#a9b2be` | `#a9b2be` | `#a9b2be` |
| `dark.line` | color | `#2e343d` | `#2e343d` | `#2e343d` | `#2e343d` |
| `dark.accent` | color | `#7d9cff` | `#7d9cff` | `#7d9cff` | `#7d9cff` |
| `dark.accent-ink` | color | `#0f1420` | `#0f1420` | `#0f1420` | `#0f1420` |
| `dark.accent-soft` | color | `#1f2a45` | `#1f2a45` | `#1f2a45` | `#1f2a45` |
| `dark.bar` | color | `#262c35` | `#262c35` | not used | not used |
| `dark.label` | color | `#222831` | `#222831` | `#222831` | `#222831` |
| `font.sans` | font list | `-apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans", "Noto Sans JP", sans-serif` | `-apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans", "Noto Sans JP", sans-serif` | `-apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans", "Noto Sans JP", sans-serif` | `-apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans", "Noto Sans JP", sans-serif` |
| `font.mono` | font list | `ui-monospace, "SF Mono", Menlo, Consolas, monospace` | `ui-monospace, "SF Mono", Menlo, Consolas, monospace` | `ui-monospace, "SF Mono", Menlo, Consolas, monospace` | `ui-monospace, "SF Mono", Menlo, Consolas, monospace` |
| `font.size` | pixels from 12 to 40 | `15` | `15` | `16` | `15` |
| `font.line-height` | number from 1 to 3 | `1.7` | `1.7` | `1.8` | `1.7` |
| `space.page-width` | pixels from 320 to 4000 | `1200` | `1200` | `820` | `1240` |
| `space.radius-small` | pixels from 0 to 64 | `8` | `8` | `8` | `8` |
| `space.radius` | pixels from 0 to 64 | `10` | `10` | `10` | `10` |
| `space.radius-large` | pixels from 0 to 64 | `12` | `12` | `12` | `12` |

## Values

| Type | Written as |
|---|---|
| color | A hex color such as `"#2a5bd7"`, or `rgb()`, `rgba()`, `hsl()`, or `hsla()` |
| font list | A CSS font list such as `"\"Inter\", sans-serif"`, without `;`, `{`, `}`, `<`, `>`, or `\` |
| pixels | A number without a unit, such as `16`, written into the page as `16px` |
| number | A number without a unit, such as `1.75` |

Text stays at 12px or larger, as `verify` asks, so `font.size` starts at 12.

## Refused files

`theme` refuses a theme file that holds a key not listed above, a color that is not a color, or a number outside its range.
It names each such key, such as `light.acent`, ends with 2, and leaves the page as it is.
A file that is not JSON is refused the same way.
