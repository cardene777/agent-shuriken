# 0003. The skills that write HTML pages apply one shared theme command from design-formats

## Decision

Where the code that reads a user's theme file and writes it into an HTML page lives, now that skills other than page-design write pages a user wants in their own colors and fonts.

## Chosen

The `theme` command of `page-design.py` in the `design-formats` plugin is the only code that writes the theme file into an HTML page.
A skill that writes HTML pages names the base colors of its own template after the keys of the theme file (`bg`, `surface`, `ink`, `sub`, `line`, `label`, and the accent colors), mixes its other shades from them with `color-mix()`, and has its steps run `theme --keys` with the keys it takes on the finished page.
A skill that keeps its own sizes takes `light`, `dark`, `font.sans`, and `font.mono` only.

## Rejected

| Option | Why not |
|---|---|
| Each skill reads the theme file with its own script | The reading and the checks of the theme file would sit in every skill, and every change of the format would have to be made in each |
| Apply every key, including text size, page width, and corners | Skills with their own print layouts and side panels would need new checks, and the look a user asked for is the colors and fonts |
| Keep the shades that the theme file has no key for at fixed values | A dark theme background would leave lines and secondary text in colors made for the default background |

## Grounds

- The plugin rule in `AGENTS.md` keeps each plugin self-contained, so the theme command is reached by opening the `page-design` skill by name, as the shared `verify` is (0002).
- `theme` replaces only tokens a page defines, so a template whose base tokens carry the theme's key names takes the theme without a mapping table.
- chainome-diagram writes diagram code into the user's project rather than an HTML page with `:root` tokens, so it reads the theme file with its own `scripts/diagram-theme.py` (#354).
- Issue #359 and issue #358, decision tables.

## Date

2026-11-23
