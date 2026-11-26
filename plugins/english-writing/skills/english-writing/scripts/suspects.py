"""Point at English sentences to check, line by line, so the agent can decide whether to fix each one.

It gives no pass or fail and no score. It reads the prose of each Markdown or text file passed to it,
skips front matter, fenced code, inline code, HTML comments, link targets, and URLs, and prints three
kinds of suspects:

  long sentence   a sentence of more than LIMIT words (references/rules.md sets the limit)
  passive voice   a form of "be" followed by a past participle
  from Japanese   a phrasing translated word for word from Japanese, from references/translationese.tsv

Usage: python3 suspects.py <file>...
It exits 0 whatever it finds, 2 when a file is missing or cannot be read, and 1 when the phrase list
is broken. It reads only the files passed and the phrase list, and writes nothing.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

KINDS = ("long sentence", "passive voice", "from Japanese")
LIMIT = 25
PHRASES = Path(__file__).resolve().parent.parent / "references" / "translationese.tsv"
COLUMNS = ["pattern", "example", "instead"]

FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
TABLE_RULE = re.compile(r"^\s*\|?\s*:?-{3,}")
QUOTE = re.compile(r"^\s{0,3}>\s?")
COMMENT = re.compile(r"<!--.*?-->")

INLINE_CODE = re.compile(r"(`+)(?:(?!\1).)+\1")
IMAGE_OR_LINK = re.compile(r"!?\[([^\]]*)\]\([^)]*\)")
REFERENCE_LINK = re.compile(r"\[([^\]]+)\]\[[^\]]*\]")
URL = re.compile(r"<?(?:https?|ftp)://[^\s>)]+>?")
HTML_TAG = re.compile(r"</?[A-Za-z][^>]*>")
EMPHASIS = re.compile(r"\*{1,3}|(?<!\w)_{1,3}|_{1,3}(?!\w)")

WORD = re.compile(r"[A-Za-z0-9]+(?:['’.-][A-Za-z0-9]+)*")
# A sentence ends at ., !, or ? (with any closing quote or bracket) at the end of a line, or before a
# space and a capital, a digit, or an opening quote or bracket, unless the word before is an abbreviation.
SENTENCE_END = re.compile(r"[.!?][\"'’”)\]]*(?:\n\s*|\s+(?=[A-Z0-9\"'‘“(\[]))")
ABBREVIATIONS = {"e.g", "i.e", "vs", "cf", "mr", "mrs", "ms", "dr", "st", "fig", "no", "approx"}

BE = r"(?:am|is|are|was|were|be|been|being)"
BETWEEN = r"(?:\s+(?:not|never|also|then|now|still|already|always|often|only|just|being|been|\w+ly))*"
IRREGULAR = (
    "known shown given taken written done made seen built sent found held kept left run set put read thrown "
    "chosen driven broken spoken begun drawn grown hidden eaten forgotten gotten frozen stolen sold told paid "
    "said brought bought caught taught thought meant lost won shut cut let split spread bound sung struck "
    "stuck swept torn worn sworn born borne shaken woken ridden risen fallen beaten bitten blown flown sewn "
    "dealt fed led met overridden rewritten withdrawn undone"
).split()
NOT_PARTICIPLES = {
    "indeed", "need", "speed", "seed", "feed", "weed", "deed", "greed", "breed", "bleed", "exceed", "proceed",
    "succeed", "embed", "shed", "bed", "red", "wed", "bred", "hundred", "sacred", "naked", "wicked", "rugged",
    "ragged", "jagged", "crooked", "kindred", "shred",
}
PASSIVE = re.compile(rf"\b{BE}{BETWEEN}\s+((?:[a-z]{{2,}}ed)|(?:{'|'.join(IRREGULAR)}))\b", re.IGNORECASE)


def load_phrases(path: Path) -> list[tuple[re.Pattern[str], str]]:
    """Read the phrase list. A list without its header or with a bad row stops the run with a reason."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ValueError(f"cannot read the phrase list {path}: {error.strerror}") from error
    rows = [line.split("\t") for line in lines if line.strip() and not line.startswith("#")]
    if not rows or rows[0] != COLUMNS:
        raise ValueError(f"{path}: the first row must be the columns {' '.join(COLUMNS)}, separated by tabs")
    phrases = []
    for number, row in enumerate(rows[1:], 2):
        if len(row) != len(COLUMNS):
            raise ValueError(f"{path}: row {number} has {len(row)} columns, not {len(COLUMNS)}")
        try:
            phrases.append((re.compile(row[0], re.IGNORECASE), row[2]))
        except re.error as error:
            raise ValueError(f"{path}: row {number} is not a valid pattern: {error}") from error
    return phrases


def clean(line: str) -> str:
    """Keep the words of a line of prose: code and URLs become one word, links keep their text."""
    line = INLINE_CODE.sub(" Code ", line)
    line = IMAGE_OR_LINK.sub(r"\1", line)
    line = REFERENCE_LINK.sub(r"\1", line)
    line = URL.sub(" Link ", line)
    line = HTML_TAG.sub(" ", line)
    return " ".join(EMPHASIS.sub("", line).split())


def blocks(text: str) -> list[list[tuple[int, str]]]:
    """Split a file into blocks of prose: paragraphs, list items, headings, and table cells.

    Each block is a list of (line number, cleaned text). Front matter, fenced code, HTML comments,
    and table rules are left out.
    """
    lines = text.splitlines()
    found: list[list[tuple[int, str]]] = []
    current: list[tuple[int, str]] = []
    fence = ""
    comment = False
    start = 0
    if lines and lines[0].strip() == "---":
        end = next((i for i in range(1, len(lines)) if lines[i].strip() in ("---", "...")), None)
        start = end + 1 if end is not None else 0

    def close() -> None:
        nonlocal current
        if current:
            found.append(current)
        current = []

    for index in range(start, len(lines)):
        number, line = index + 1, lines[index]
        mark = FENCE.match(line)
        if fence:
            if mark and mark.group(1)[0] == fence[0] and len(mark.group(1)) >= len(fence) and not line.strip()[len(mark.group(1)):].strip():
                fence = ""
            continue
        if mark:
            close()
            fence = mark.group(1)
            continue
        if comment:
            if "-->" not in line:
                continue
            line, comment = line.split("-->", 1)[1], False
        line = COMMENT.sub(" ", line)
        if "<!--" in line:
            line, comment = line.split("<!--", 1)[0], True
        line = QUOTE.sub("", line)
        if not line.strip():
            close()
        elif TABLE_RULE.match(line) and "|" in line:
            close()
        elif line.lstrip().startswith("|"):
            close()
            found.extend([[(number, clean(cell))] for cell in line.strip().strip("|").split("|") if cell.strip()])
        elif HEADING.match(line):
            close()
            found.append([(number, clean(HEADING.sub("", line)))])
        elif LIST_ITEM.match(line):
            close()
            current = [(number, clean(LIST_ITEM.sub("", line)))]
        else:
            current.append((number, clean(line)))
    close()
    return found


def sentences(block: list[tuple[int, str]]) -> list[tuple[str, list[tuple[int, int]]]]:
    """Join a block and cut it into sentences. Each comes with (offset, line number) marks for its lines."""
    text, marks = "", []
    for number, part in block:
        if text:
            text += "\n"
        marks.append((len(text), number))
        text += part.strip()
    found, begin = [], 0
    for end in SENTENCE_END.finditer(text):
        before = text[begin:end.start() + 1].split()
        if before and before[-1].lower().rstrip(".") in ABBREVIATIONS:
            continue
        found.append((begin, end.end()))
        begin = end.end()
    found.append((begin, len(text)))
    # The line breaks marked the ends of lines for the cut; inside a sentence they are spaces again,
    # one character each, so the offsets of the marks still hold.
    return [(text[first:last].replace("\n", " ").rstrip(), [(offset - first, number) for offset, number in marks])
            for first, last in found if text[first:last].strip()]


def line_at(marks: list[tuple[int, int]], offset: int) -> int:
    """The line number that holds the character at an offset of the sentence."""
    number = marks[0][1]
    for start, line in marks:
        if start <= offset:
            number = line
    return number


def one_line(text: str) -> str:
    return " ".join(text.split())


def excerpt(sentence: str) -> str:
    sentence = one_line(sentence)
    return sentence if len(sentence) <= 80 else sentence[:77].rstrip() + "..."


def suspects(text: str, phrases: list[tuple[re.Pattern[str], str]]) -> list[tuple[int, str, str, str]]:
    """Every suspect as (line, kind, match, note), in the order of the text."""
    found = []
    for block in blocks(text):
        for sentence, marks in sentences(block):
            count = len(WORD.findall(sentence))
            if count > LIMIT:
                found.append((line_at(marks, 0), KINDS[0], f"{count} words", excerpt(sentence)))
            for match in PASSIVE.finditer(sentence):
                if match.group(1).lower() not in NOT_PARTICIPLES:
                    found.append((line_at(marks, match.start()), KINDS[1], one_line(match.group(0)), excerpt(sentence)))
            for pattern, instead in phrases:
                match = pattern.search(sentence)
                if match:
                    found.append((line_at(marks, match.start()), KINDS[2], one_line(match.group(0)), instead))
    return sorted(found, key=lambda finding: finding[0])


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print((__doc__ or "").strip())
        return 0 if argv else 2
    paths = [Path(arg) for arg in argv]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        print("suspects: no such file: " + ", ".join(missing), file=sys.stderr)
        return 2
    try:
        phrases = load_phrases(PHRASES)
    except ValueError as error:
        print(f"suspects: {error}", file=sys.stderr)
        return 1
    texts = []
    for path in paths:
        try:
            texts.append(path.read_text(encoding="utf-8", errors="replace"))
        except OSError as error:
            print(f"suspects: cannot read {path}: {error.strerror}", file=sys.stderr)
            return 2
    for path, text in zip(paths, texts):
        found = suspects(text, phrases)
        print(f"=== suspects: {path} ===")
        for line, kind, match, note in found:
            print(f"L{line} [{kind}] {match}: {note}")
        print("Counts: " + " / ".join(f"{kind} {sum(1 for f in found if f[1] == kind)}" for kind in KINDS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
