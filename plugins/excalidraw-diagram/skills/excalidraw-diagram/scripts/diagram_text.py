"""Estimate the size of text without a font file.

The Excalidraw editor measures text with its own fonts when it opens a file. This module
only needs an estimate that is never smaller than the real text, so that shapes sized
from it hold their text in the editor, the SVG, and the PNG. Widths are averages per
character class of a Helvetica-like font, scaled per font family, plus a safety margin.
"""
import unicodedata

# Excalidraw font family numbers used here.
FAMILY_HAND = 5        # Excalifont, the hand-drawn font (1 is the older Virgil)
FAMILY_SANS = 2        # Helvetica
MONO_FAMILIES = {3, 8}

# Line height per font family, as a multiple of the font size.
LINE_HEIGHT = {1: 1.25, 2: 1.15, 3: 1.2, 5: 1.25, 6: 1.35, 7: 1.15, 8: 1.25}
# How much wider than Helvetica each family runs.
FAMILY_WIDTH = {1: 1.15, 2: 1.0, 5: 1.15, 6: 1.08, 7: 1.0}
SAFETY = 1.06
BOLD = 1.08            # how much wider a bold line runs; the SVG draws a shape's first line bold

_NARROW = set(" iIl|!.,:;'`")
_THIN = set("fjtr()[]{}-/\\\"*")
_WIDE = set("mwMW@%&")
_UPPER_WIDE = set("ABCDGHKNOQRUVXY")


def char_em(ch):
    """Width of one character in em for a Helvetica-like font."""
    if ch in _NARROW:
        return 0.28
    if ch in _THIN:
        return 0.36
    if ch in _WIDE:
        return 0.9
    if "A" <= ch <= "Z":
        return 0.74 if ch in _UPPER_WIDE else 0.68
    if ch.isascii():
        return 0.58
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 1.0
    if unicodedata.category(ch) in ("Mn", "Me", "Cf"):
        return 0.0
    return 0.62


def line_height(family):
    return LINE_HEIGHT.get(family, 1.25)


def line_width(line, size, family):
    if family in MONO_FAMILIES:
        em = sum(1.0 if unicodedata.east_asian_width(c) in ("W", "F") else 0.6 for c in line)
        return em * size * SAFETY
    em = sum(char_em(c) for c in line)
    return em * size * FAMILY_WIDTH.get(family, 1.15) * SAFETY


def text_size(text, size, family):
    """Return (width, height) of text that may hold line breaks."""
    lines = text.split("\n")
    width = max(line_width(line, size, family) for line in lines)
    height = len(lines) * size * line_height(family)
    return width, height


def room_for(text, size, family):
    """(width, height) a shape must hold for text whose first line is drawn bold."""
    lines = text.split("\n")
    width = max([line_width(lines[0], size, family) * BOLD] + [line_width(line, size, family) for line in lines[1:]])
    return width, len(lines) * size * line_height(family)
