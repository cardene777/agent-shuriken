#!/usr/bin/env python3
"""Check the text of a finished explainer document.

`check.py` checks the form of the document (figures, sizes, network use, structure).
This script checks the words a reader reads. The rule set follows `<html lang>`:
Japanese documents (`lang` starting with `ja`) get every check, other documents get only the
checks that do not depend on the language.

| Check | Japanese | Other | Result |
|---|---|---|---|
| Bundled word lists in `references/prose-words.txt` | yes | no | NG |
| Term table given with `--words` | yes | yes | NG |
| Katakana long-vowel variants, full-width letters and digits | yes | no | NG |
| Caption number gaps and repeats, per prefix and per page | yes | yes | NG |
| Table column counts | yes | yes | NG |
| Contents list vs section headings | yes | yes | NG |
| Worker headings (written for the person making the document) | all words | `TODO` only | NG |
| Commas in headings | yes | no | NG |
| Metaphor verbs after an identifier subject | yes | no | NG |
| Links left in the default blue | yes | yes | NG |
| Paragraph and sentence lengths, repeated sentences | yes | yes | counted only |

Lengths never fail: a long paragraph is right in some places (the lead-in to a table, a list of
steps), and splitting it would break the reading order. The longest ones are listed for the writer.

Whether the text is true is not checked: the evidence lives outside the document. The rereading
steps in `references/prose-check.md` cover it.

Left out of the text: `<script>`, `<style>`, `<code>`, `<pre>`, and every element the writer marks
with `data-prose-skip` (quoted text whose wording is fixed elsewhere).

Usage:

  prose.py <document.html> [--words FILE] [--words FILE] [--no-default-words]
           [--para 160] [--sent 100] [--dup 22] [--top 5]

Exit code 0 when no check fails, 1 when a check fails, 2 when a bundled word list cannot be read.
"""
import argparse
import html as H
import io
import os
import re
import sys
from collections import Counter, OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, os.pardir, "references")
SHARED_WORDS = os.path.join(DATA, "prose-words.txt")
METAPHOR_WORDS = os.path.join(DATA, "metaphor-words.tsv")

# Japanese characters the checks match, written as escapes so this file stays ASCII.
JA_STOP = "\u3002"         # ideographic full stop
JA_COMMA = "\u3001"        # ideographic comma
JA_LONG_VOWEL = "\u30fc"   # katakana long-vowel mark

HTML_LANG = re.compile(r"<html\b[^>]*?\s(?:xml:)?lang\s*=\s*[\"']?([^\"'\s>]*)", re.I)
# Text the writer quotes with fixed wording. Do not nest an element of the same name inside it
# (the match ends at the first closing tag).
SKIP_BLOCK = re.compile(r"<([A-Za-z][\w-]*)\b[^>]*\sdata-prose-skip\b[^>]*>.*?</\1>", re.S)
DROP_BLOCK = re.compile(r"<(script|style)\b.*?</\1>", re.S)
DROP_INLINE = re.compile(r"<(code|pre)\b[^>]*>.*?</\1>", re.S)
TAG = re.compile(r"<[^>]+>")
SECTION = re.compile(r'<section\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</section>', re.S)
# An identifier as the subject: a `<code>` element, replaced by \x01, followed by the topic or
# subject particle.
SUBJECT = re.compile("\x01\\s*[\u306f\u304c]")
# Ends of blocks. Headings, paragraphs, and table cells end a sentence even without a full stop,
# so a heading is not read as the start of the paragraph after it.
BLOCK_END = re.compile(r"</(p|h[1-6]|li|td|th|figcaption|summary|div|dt|dd)>|<br\s*/?>", re.I)
PARA = re.compile(r"<p\b[^>]*>(.*?)</p>", re.S)
H2 = re.compile(r"<h2\b[^>]*>(.*?)</h2>", re.S)
NUMSPAN = re.compile(r'<span class="num">\d+</span>')
TOC = re.compile(r'<nav[^>]*class="[^"]*toc[^"]*"[^>]*>(.*?)</nav>', re.S)
TOC_ITEM = re.compile(r'<a\b[^>]*href="#([^"]+)"[^>]*>(.*?)</a>', re.S)
# The contents list of templates/starter-doc.html is a row of buttons that switch sections.
TOC_BTN = re.compile(r'<button\b[^>]*\bdata-sec="([^"]+)"[^>]*>(.*?)</button>', re.S)
FIGCAP = re.compile(r"<figcaption\b[^>]*>(.*?)</figcaption>", re.S)
# Caption numbers with their prefix. Japanese captions use the prefixes for "figure" and
# "example"; other captions use `Figure`, `Fig.` (counted as `Figure`), and `Example`.
JA_FIGNO = re.compile("^(\u56f3|\u4f8b)\\s*(\\d+)")
EN_FIGNO = re.compile(r"^(Figure|Fig\.|Example)\s*(\d+)")
FIG_ALIAS = {"Fig.": "Figure"}
TABLE = re.compile(r"<table\b[^>]*>(.*?)</table>", re.S)
ROW = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.S)
CELL = re.compile(r"<(t[hd])\b([^>]*)>", re.I)
COLSPAN = re.compile(r'colspan="?(\d+)"?', re.I)
KATAKANA = re.compile("[\u30a1-\u30f4\u30fc]{3,}")
ASCII_WORD = re.compile(r"(?<![A-Za-z0-9])[A-Za-z][A-Za-z0-9]{2,}(?![A-Za-z0-9])")
WIDE_ALNUM = re.compile("[\uff21-\uff3a\uff41-\uff5a\uff10-\uff19]")
EN_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")

# Kinds in the first column of `prose-words.txt` that have their own handling in `run`.
# Every other kind in the file is matched the default way, so a kind added to the file is
# checked without a change here.
WORDY_KIND = "wordy"
JARGON_KIND = "jargon"
LOGBOOK_KIND = "logbook"
BARE_EN_KIND = "bare-english"
WORKER_HEAD_KIND = "worker-heading"
ALLOW_KIND = "allow"
NAMED_KINDS = (WORDY_KIND, JARGON_KIND, LOGBOOK_KIND, BARE_EN_KIND, WORKER_HEAD_KIND, ALLOW_KIND)

METAPHOR_HEADER = ["kind", "pattern", "usual meaning"]
METAPHOR_VERB_KINDS = ("personify", "operation")
METAPHOR_KINDS = METAPHOR_VERB_KINDS + ("adverb",)


def load_shared(path):
    """Read the bundled word list. Returns {kind: {word: replacement}}.

    One word per line: `kind  word  replacement`. Lines starting with `#` are comments.
    Kinds come from the first column as written. Raises ValueError when a line cannot be read or
    a kind in `NAMED_KINDS` has no words, so a broken list never reports "0 found".
    """
    out = OrderedDict((k, OrderedDict()) for k in NAMED_KINDS)
    bad = []
    for no, line in enumerate(io.open(path, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cols = line.split()
        if len(cols) < 3:
            bad.append("line %d" % no)
            continue
        out.setdefault(cols[0], OrderedDict())[cols[1]] = " ".join(cols[2:])
    empty = [k for k, v in out.items() if not v]
    if bad or empty:
        raise ValueError("cannot read the word list (%s): unreadable %s / kinds without words %s"
                         % (path, ", ".join(bad) or "none", ", ".join(empty) or "none"))
    return out


def load_metaphors(path):
    """Read the metaphor list and compile the verb patterns (`personify` and `operation`)."""
    out = []
    bad = []
    header = None
    for no, line in enumerate(io.open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        cols = line.split("\t")
        if header is None:
            header = cols
            if cols != METAPHOR_HEADER:
                bad.append("column names on line %d" % no)
            continue
        if len(cols) != 3 or cols[0] not in METAPHOR_KINDS:
            bad.append("line %d" % no)
            continue
        if cols[0] in METAPHOR_VERB_KINDS:
            try:
                out.append(re.compile(cols[1]))
            except re.error:
                bad.append("line %d" % no)
    if bad or header is None or not out:
        raise ValueError("cannot read the metaphor list (%s): unreadable %s / verbs %d"
                         % (path, ", ".join(bad) or "none", len(out)))
    return tuple(out)


try:
    _SHARED = load_shared(SHARED_WORDS)
    METAPHOR_VERBS = load_metaphors(METAPHOR_WORDS)
except (OSError, UnicodeError, ValueError) as e:
    sys.stderr.write("prose.py: %s\n" % e)
    raise SystemExit(2)
WORDY = _SHARED[WORDY_KIND]
# Merged with the `--words` term table; `--no-default-words` leaves it out.
JARGON = _SHARED[JARGON_KIND]
LOGBOOK = _SHARED[LOGBOOK_KIND]
BARE_EN = _SHARED[BARE_EN_KIND]
# Words never flagged as bare English.
ALLOW_EN = _SHARED[ALLOW_KIND]

# Kinds matched the default way, in file order (`coined` and any kind added later).
DEFAULT_KINDS = tuple(k for k in _SHARED if k not in NAMED_KINDS)

# Worker headings, written for the person making the document: a sign that the plan is still in
# a page meant for readers. Only headings and `<summary>` are checked, never body text.
NEUTRAL_WORKER_HEADS = ("TODO",)
WORKER_HEADS = tuple(_SHARED[WORKER_HEAD_KIND]) + NEUTRAL_WORKER_HEADS

HEADING = re.compile(r"<(h[1-6]|summary)\b[^>]*>(.*?)</\1>", re.S)
ANCHOR = re.compile(r"<a\b[^>]*\bhref=", re.I)
STYLE_BLOCK = re.compile(r"<style\b[^>]*>(.*?)</style>", re.S)
CSS_RULE = re.compile(r"([^{}]+)\{([^{}]*)\}", re.S)
CSS_VAR = re.compile(r"--([\w-]+)\s*:\s*([^;}]+)")
CSS_COLOR = re.compile(r"(?:^|;)\s*color\s*:\s*([^;!}]+)", re.I)
LINK_SEL = re.compile(r"(?:^|[\s,>+~])a(?:\s*[:.\[,]|\s|$)")
VAR_REF = re.compile(r"var\(\s*--([\w-]+)")
# The default link blue, written as a name. Blues written as numbers are found by `is_blue`.
BLUE_NAMES = ("blue", "navy", "mediumblue", "darkblue", "royalblue",
              "dodgerblue", "cornflowerblue", "-webkit-link", "linktext")

# An "allowed phrase" line of a term table: a phrase that is not counted even when it contains a
# listed word, for example a glossary entry that keeps the original term in parentheses.
# The older Japanese keyword is still read.
ALLOW_LINE = re.compile("^(?:allow|\u8a31\u3059)\\s*[:\uff1a]\\s*(.+)$")
# Separators of a term-table line, tried in this order.
WORD_SEPARATORS = ("\t", "\u2192", "->", "=>", ",")


def document_lang(doc):
    """The `lang` attribute of the `<html>` element, or "" when there is none."""
    m = HTML_LANG.search(doc)
    return m.group(1).strip() if m else ""


def is_japanese(lang):
    """Japanese rules apply when `lang` starts with `ja`."""
    return (lang or "").strip().lower().startswith("ja")


def default_words(lang=None):
    """Words of the default-matched kinds, as {word: replacement}.

    `figure.py` checks figure names with them. The words are Japanese: pass the document's `lang`
    to get an empty table for a document that is not Japanese. Without `lang`, the words are
    returned as they are.
    """
    out = OrderedDict()
    if lang is not None and not is_japanese(lang):
        return out
    for kind in DEFAULT_KINDS:
        out.update(_SHARED[kind])
    return out


def as_paths(path):
    """`--words` takes one path or a list. Returns a list, empty for None."""
    if path is None:
        return []
    return [path] if isinstance(path, str) else list(path)


def load_words(path):
    """Read term tables. One entry per line: `word -> replacement`.

    A tab, the arrow U+2192, `=>`, or `,` also separates the two (`WORD_SEPARATORS` gives the
    order). A line with only a word has an empty replacement. `allow:` lines are not words
    (`load_allow` reads them). With several tables, later tables override earlier ones.
    """
    out = OrderedDict()
    for one in as_paths(path):
        out.update(_load_words_one(one))
    return out


def _load_words_one(path):
    out = OrderedDict()
    for line in io.open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or ALLOW_LINE.match(line):
            continue
        for sep in WORD_SEPARATORS:
            if sep in line:
                k, v = line.split(sep, 1)
                out[k.strip()] = v.strip()
                break
        else:
            out[line] = ""
    return out


def load_allow(path):
    """Read the `allow:` lines of term tables, longest first so longer phrases are removed first."""
    out = []
    for one in as_paths(path):
        for line in io.open(one, encoding="utf-8"):
            m = ALLOW_LINE.match(line.strip())
            if m:
                out.append(m.group(1).strip())
    return sorted(set(out), key=len, reverse=True)


def drop_allowed(text, allow):
    """Remove the allowed phrases. Whitespace inside a phrase may differ from the text."""
    for phrase in allow or ():
        pat = r"\s*".join(re.escape(c) for c in re.sub(r"\s+", "", phrase))
        text = re.sub(pat, " ", text)
    return text


def visible(fragment):
    """Keep only the text a reader sees, without scripts, styles, `code`, and `pre`."""
    fragment = DROP_BLOCK.sub(" ", fragment)
    fragment = DROP_INLINE.sub(" ", fragment)
    return H.unescape(TAG.sub(" ", fragment))


def tight(text):
    """Text without any whitespace, for comparing and for Japanese lengths."""
    return re.sub(r"\s+", "", text)


def squash(text):
    """Text with whitespace collapsed to single spaces, for lengths of non-Japanese text."""
    return re.sub(r"\s+", " ", text).strip()


def chunks(doc):
    """(section id, section markup) pairs. A document without sections is one part, `body`."""
    out = [(sid, frag) for sid, frag in SECTION.findall(doc)]
    if out:
        return out
    m = re.search(r"<body\b[^>]*>(.*)</body>", doc, re.S)
    return [("body", m.group(1) if m else doc)]


def sentences(text, ja=True):
    """Split into sentences: at the ideographic full stop for Japanese, at `.` `!` `?` otherwise."""
    if ja:
        return [s for s in (tight(x) for x in re.split("(?<=%s)" % JA_STOP, text)) if s]
    return [s for s in (squash(x) for x in EN_SENTENCE_END.split(text)) if s]


def check_words(parts, table, label, found):
    """Count each listed word as a substring, with the sections it appears in."""
    hits = OrderedDict()
    for sid, text in parts:
        for word, into in table.items():
            n = text.count(word)
            if not n:
                continue
            row = hits.setdefault(word, {"n": 0, "where": [], "into": into})
            row["n"] += n
            if sid not in row["where"]:
                row["where"].append(sid)
    for word, row in hits.items():
        into = (" -> %s" % row["into"]) if row["into"] else ""
        found.append("%s %s %dx%s (%s)"
                     % (label, word, row["n"], into, ", ".join(row["where"][:4])))
    return len(hits)


def check_bare_english(parts, table, allow, found):
    """English words outside backticks. Returns (words found, words looked at).

    Unlike `check_words`, a word is matched on word boundaries (`alignment` does not match inside
    `realignment`) and case is ignored (`Interface` and `interface` are the same word).
    Words in `allow` are never flagged.
    """
    seen = OrderedDict((w, into) for w, into in table.items()
                       if w.lower() not in allow)
    hits = OrderedDict()
    for sid, text in parts:
        low = text.lower()
        for word, into in seen.items():
            n = len(re.findall(r"(?<![A-Za-z0-9])" + re.escape(word.lower())
                               + r"(?![A-Za-z0-9])", low))
            if not n:
                continue
            row = hits.setdefault(word, {"n": 0, "where": [], "into": into})
            row["n"] += n
            if sid not in row["where"]:
                row["where"].append(sid)
    for word, row in hits.items():
        found.append("bare English %s %dx -> %s (%s)"
                     % (word, row["n"], row["into"], ", ".join(row["where"][:4])))
    return len(hits), len(seen)


def check_spelling(parts, found, soft):
    """One word written two ways, found from pairs inside the document (no dictionary).

    Fails on katakana words with and without the final long-vowel mark, and on full-width
    letters and digits. Words that differ only in letter case are counted in `soft` and never
    fail: the same spelling can name different things (a company and a payment method).
    """
    words = Counter()
    ascii_words = Counter()
    wide = []
    for sid, text in parts:
        for w in KATAKANA.findall(text):
            words[w] += 1
        for w in ASCII_WORD.findall(text):
            ascii_words[w] += 1
        if WIDE_ALNUM.search(text) and sid not in wide:
            wide.append(sid)
    n = 0
    for w, c in words.items():
        if not w.endswith(JA_LONG_VOWEL):
            continue
        base = w[:-1]
        if len(base) >= 3 and words.get(base):
            n += 1
            found.append("spelling variants %s (%d) and %s (%d)"
                         % (base, words[base], w, c))
    if wide:
        n += 1
        found.append("full-width letters or digits (%s)" % ", ".join(wide[:4]))
    by_lower = OrderedDict()
    for w, c in ascii_words.items():
        by_lower.setdefault(w.lower(), []).append((w, c))
    for _low, forms in by_lower.items():
        if len(forms) > 1:
            soft.append("letter case %s"
                        % " and ".join("%s (%d)" % f for f in forms))
    return n


def check_figno(parts_raw, found, ja=True):
    """Caption numbers. A gap or a repeat makes "see Figure 5" point at the wrong figure.

    Numbers are counted per page (the part of the section id before `-`, so `a-s6` is page `a`)
    and per prefix, because each page and each prefix numbers from 1. A section id without `-`
    puts the whole document in one sequence.

    Captions without a number are counted, never failed: some figures need no number.

    Returns (problems, numbered captions, unnumbered captions).
    """
    pattern = JA_FIGNO if ja else EN_FIGNO
    groups = OrderedDict()
    unnumbered = 0
    for sid, frag in parts_raw:
        key = sid.split("-", 1)[0] if "-" in sid else ""
        for cap in FIGCAP.findall(frag):
            m = pattern.match(tight(visible(cap)))
            if m:
                prefix = FIG_ALIAS.get(m.group(1), m.group(1))
                groups.setdefault((key, prefix), []).append(int(m.group(2)))
            else:
                unnumbered += 1
    total = sum(len(v) for v in groups.values())
    if not total:
        return 0, 0, unnumbered
    n = 0
    for (key, pre), nums in groups.items():
        where = (" (%s)" % key) if key else ""
        # "Figure 2" with a space, the Japanese prefixes without one, as each language writes it.
        form = "%s %d" if pre.isascii() else "%s%d"
        dup = [k for k, v in Counter(nums).items() if v > 1]
        if dup:
            n += 1
            found.append("%s numbers repeated%s: %s"
                         % (pre, where, ", ".join(form % (pre, d) for d in sorted(dup))))
        lo, hi = min(nums), max(nums)
        missing = [i for i in range(lo, hi + 1) if i not in nums]
        if missing:
            n += 1
            found.append("%s numbers missing%s: %s"
                         % (pre, where, ", ".join(form % (pre, d) for d in missing)))
    return n, total, unnumbered


def check_table(doc, found):
    """Table column counts. A row whose width differs from the header has a value shifted."""
    n = 0
    total = 0
    for i, body in enumerate(TABLE.findall(doc), 1):
        rows = ROW.findall(body)
        if not rows:
            continue
        total += 1
        widths = []
        for r in rows:
            w = 0
            for _tag, attrs in CELL.findall(r):
                m = COLSPAN.search(attrs)
                w += int(m.group(1)) if m else 1
            widths.append(w)
        head = widths[0]
        odd = [(j + 1, w) for j, w in enumerate(widths) if w != head]
        if odd:
            n += 1
            found.append("table %d has uneven rows (header %d columns; %s)"
                         % (i, head, ", ".join("row %d has %d" % o for o in odd[:3])))
    return n, total


def check_toc(doc, found):
    """Contents entries against section headings. Renaming one without the other splits them."""
    titles = {}
    for sid, frag in SECTION.findall(doc):
        m = H2.search(frag)
        if m:
            titles[sid] = tight(visible(NUMSPAN.sub("", m.group(1))))
    n = 0
    total = 0
    for block in TOC.findall(doc):
        for sid, text in TOC_ITEM.findall(block) + TOC_BTN.findall(block):
            label = tight(visible(text))
            if sid not in titles:
                continue
            total += 1
            if label and label not in titles[sid]:
                n += 1
                found.append('contents "%s" differs from heading "%s" (%s)'
                             % (label, titles[sid], sid))
    return n, total


def headings(doc):
    """Visible text of every heading and `<summary>`."""
    heads = [tight(visible(m.group(2))) for m in HEADING.finditer(doc)]
    return [h for h in heads if h]


def check_comma(doc, found):
    """Ideographic commas in headings. Returns (headings with a comma, headings looked at).

    A heading is read at a glance; with a comma inside, the reader cannot tell one heading from
    two headings side by side. Headings that list items separate them with a middle dot.
    `<summary>` follows the same rule. Body text and table cells are not checked.
    """
    heads = headings(doc)
    hits = [h for h in heads if JA_COMMA in h]
    for h in hits:
        found.append("heading comma %s" % h[:40])
    return len(hits), len(heads)


def code_sentences(doc):
    """Split into sentences, keeping a mark where each identifier was. Returns (section, sentence).

    `visible()` drops `code`, which hides identifier subjects, so here each `code` becomes one
    mark character before the other tags are removed. Sentences also end at block ends, so a
    heading and the next paragraph are not read as one sentence.
    """
    out = []
    for sid, frag in chunks(doc):
        frag = DROP_BLOCK.sub(" ", frag)
        frag = DROP_INLINE.sub("\x01", frag)
        frag = BLOCK_END.sub("\x02", frag)
        text = tight(H.unescape(TAG.sub(" ", frag)))
        for sent in re.split("(?<=%s)|\x02" % JA_STOP, text):
            if sent:
                out.append((sid, sent))
    return out


def check_subject(doc, found):
    """Sentences where an identifier is the subject of a metaphor verb. Returns (hits, sentences).

    A folder or script name written as if it had a will leaves the reader to work out who
    actually does the thing. Both conditions must hold in one sentence:

      subject   a `<code>` identifier followed by the topic or subject particle
      predicate a verb pattern from `references/metaphor-words.tsv`

    The verbs alone match many correct sentences, so they never fail on their own. An identifier
    written without `<code>` is not seen, because nothing marks it as an identifier.
    """
    sents = code_sentences(doc)
    hits = 0
    for sid, sent in sents:
        if not SUBJECT.search(sent):
            continue
        words = [m.group(0) for pattern in METAPHOR_VERBS for m in pattern.finditer(sent)]
        if not words:
            continue
        hits += 1
        found.append("identifier subject %s (%s) %s"
                     % (", ".join(words), sid, sent.replace("\x01", "`...`")[:48]))
    return hits, len(sents)


def check_heads(doc, found, words=WORKER_HEADS):
    """Worker headings. Returns (worker headings, headings looked at)."""
    heads = headings(doc)
    hits = []
    for h in heads:
        for w in words:
            if w in h:
                hits.append((h, w))
                break
    for h, w in hits:
        found.append("worker heading %s (%s)" % (h[:24], w))
    return len(hits), len(heads)


def css_colors(doc):
    """(selector, color) pairs from the `<style>` blocks, and the table of CSS variables."""
    variables = {}
    rules = []
    for block in STYLE_BLOCK.findall(doc):
        for sel, decl in CSS_RULE.findall(block):
            for name, value in CSS_VAR.findall(decl):
                variables[name] = value.strip()
            m = CSS_COLOR.search(decl)
            if m:
                # Collapse whitespace instead of removing it, so `nav.toc a` stays a link selector.
                rules.append((re.sub(r"\s+", " ", sel).strip(), m.group(1).strip()))
    return rules, variables


def resolve(value, variables, depth=0):
    """Follow `var(--x)` to its value. A value that cannot be followed is returned as is."""
    m = VAR_REF.search(value)
    if not m or depth > 4:
        return value
    got = variables.get(m.group(1))
    return resolve(got, variables, depth + 1) if got else value


def is_blue(value):
    """Whether a color is blue. Returns None for a value it cannot read (never "not blue")."""
    v = value.strip().lower()
    if v in BLUE_NAMES:
        return True
    # Inherits the text color, so it never falls back to the default blue.
    if v in ("inherit", "currentcolor", "unset", "initial"):
        return False
    m = re.match(r"#([0-9a-f]{3})$|#([0-9a-f]{6})$", v)
    if m:
        h = m.group(1) or m.group(2)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    else:
        m = re.match(r"rgba?\(([^)]+)\)$", v)
        if not m:
            return None
        nums = re.findall(r"[\d.]+", m.group(1))
        if len(nums) < 3:
            return None
        r, g, b = (int(float(x)) for x in nums[:3])
    # Blue only when blue clearly exceeds both red and green; dark grays and near-black do not.
    return b - r >= 45 and b - g >= 40


def check_linkcolor(doc, found, soft):
    """Link colors. Without a rule, links show in the default blue.

    Returns (failures, rules looked at). A document without links is not checked: nothing turns
    blue when it is opened.
    """
    if not ANCHOR.search(doc):
        return 0, 0
    rules, variables = css_colors(doc)
    link = [(sel, val) for sel, val in rules if LINK_SEL.search("," + sel + ",")]
    if not link:
        found.append("link color not set (links show in the default blue)")
        return 1, 0
    n = 0
    for sel, val in link:
        got = is_blue(resolve(val, variables))
        if got is True:
            found.append("blue link %s: %s" % (sel[:30], val))
            n += 1
        elif got is None:
            soft.append("link color unreadable %s: %s (counted only)" % (sel[:30], val))
    return n, len(link)


def measure(parts, para_max, sent_max, dup_min, top, ja=True):
    """Lengths and repeats, never failed. Returns counts and the longest items.

    Lengths are in characters: without whitespace for Japanese, with whitespace collapsed
    otherwise.
    """
    length_form = tight if ja else squash
    paras = []
    sents = []
    seen = OrderedDict()
    for sid, frag in parts:
        for p in PARA.findall(frag):
            text = length_form(visible(p))
            if not text:
                continue
            paras.append((len(text), sid, text))
            for s in sentences(visible(p), ja):
                sents.append((len(s), sid, s))
                if len(s) >= dup_min:
                    seen.setdefault(s, []).append(sid)
    dup = [(s, w) for s, w in seen.items() if len(w) > 1]
    long_p = sorted((x for x in paras if x[0] >= para_max), reverse=True)[:top]
    long_s = sorted((x for x in sents if x[0] >= sent_max), reverse=True)[:top]
    return {
        "paras": paras, "sents": sents, "dup": dup,
        "long_p": long_p, "long_s": long_s,
        "n_long_p": sum(1 for x in paras if x[0] >= para_max),
        "n_long_s": sum(1 for x in sents if x[0] >= sent_max),
    }


def rules_line(lang, ja):
    """The info line that names the rule set."""
    if ja:
        return "-- rules: ja"
    if lang.lower().startswith("en"):
        return "-- rules: en (Japanese wording rules not applied)"
    return ("-- rules: en (Japanese wording rules not applied; html lang is %s)"
            % ('"%s"' % lang if lang else "missing"))


def count_line(n, ok, bad):
    """`OK ...` when nothing was found, `NG ...` otherwise."""
    return ("OK " + ok) if not n else ("NG " + bad)


# Lengths in characters past which a paragraph or a sentence is listed as long. A Japanese
# character carries about as much as a whole English word, so the two languages differ.
LENGTHS = {"ja": (160, 100), "other": (700, 220)}


def run(doc, words=None, use_default=True,
        para_max=None, sent_max=None, dup_min=22, top=5, allow=None):
    """Check the text of `doc`. Returns (failures, notes, measurements).

    `words` is the term table ({word: replacement}), `use_default` adds the bundled jargon list
    (Japanese documents only), and `allow` lists phrases removed before the term checks.
    """
    lang = document_lang(doc)
    ja = is_japanese(lang)
    default_para, default_sent = LENGTHS["ja" if ja else "other"]
    para_max = default_para if para_max is None else para_max
    sent_max = default_sent if sent_max is None else sent_max
    doc, n_skip = SKIP_BLOCK.subn(" ", doc)
    raw = chunks(doc)
    parts = [(sid, visible(frag)) for sid, frag in raw]

    ng = []
    notes = [rules_line(lang, ja)]
    soft = []
    # Show how many blocks were left out, so a document that skips too much is visible.
    if n_skip:
        notes.append("-- left out of the text: data-prose-skip blocks %d" % n_skip)
    extra = "; allowed phrases removed %d" % len(allow) if allow else ""

    # Text with the term table's allowed phrases removed. Only the phrase is removed, not the
    # word: an allowed glossary phrase passes while the same word elsewhere is still found.
    allowed = [(sid, drop_allowed(text, allow)) for sid, text in parts]

    if ja:
        # 1. Wordy phrases
        n = check_words(parts, WORDY, "wordy", ng)
        notes.append(count_line(n, "wordy phrases 0", "wordy phrases %d" % n))

        # 1b. Words about the state of the work
        n = check_words(parts, LOGBOOK, "logbook", ng)
        notes.append(count_line(n, "logbook words 0", "logbook words %d" % n))

        # 1c. English words outside backticks
        allow_en = set(w.lower() for w in ALLOW_EN)
        n, nseen = check_bare_english(allowed, BARE_EN, allow_en, ng)
        tail = " (words looked at %d; allowed words excluded %d%s)" % (nseen, len(allow_en), extra)
        notes.append(count_line(n, "bare English words 0" + tail,
                                "bare English words %d" % n + tail))

        # 1d. Kinds matched the default way, in file order. The section count is shown so a
        # document where no section was found does not report a bare "0".
        for kind in DEFAULT_KINDS:
            kind_words = _SHARED[kind]
            n = check_words(allowed, kind_words, kind, ng)
            tail = " (words looked at %d; sections %d)" % (len(kind_words), len(parts))
            notes.append(count_line(n, "%s words 0" % kind + tail,
                                    "%s words %d" % (kind, n) + tail))

    # 2. Term table, plus the bundled jargon for Japanese documents
    table = OrderedDict()
    if ja and use_default:
        table.update(JARGON)
    if words:
        table.update(words)
    if table:
        n = check_words(allowed, table, "term", ng)
        tail = " (words looked at %d%s)" % (len(table), extra)
        notes.append(count_line(n, "term words 0" + tail, "term words %d" % n + tail))
    else:
        notes.append("-- no term table (words not checked)")

    if ja:
        # 3. One word written two ways
        n = check_spelling(parts, ng, soft)
        notes.append(count_line(n, "no spelling variants", "spelling variants %d" % n))
        if soft:
            notes.append("-- letter-case variants %d (counted only: the forms may name"
                         " different things)" % len(soft))

    # 4. Caption numbers
    n, nfig, nounum = check_figno(raw, ng, ja)
    if not nfig:
        notes.append("-- no numbered captions (numbers not checked)")
    else:
        notes.append(count_line(n, "caption numbers %d, no gaps or repeats" % nfig,
                                "caption number problems %d (numbered captions %d)" % (n, nfig)))
    # Unnumbered captions are counted with the total, so "0" can be told from "not checked".
    if nounum:
        notes.append("-- unnumbered captions %d of %d" % (nounum, nfig + nounum))

    # 5. Table column counts
    n, ntab = check_table(doc, ng)
    if not ntab:
        notes.append("-- no tables")
    else:
        notes.append(count_line(n, "tables %d, every row has the header's column count" % ntab,
                                "tables with uneven rows %d of %d" % (n, ntab)))

    # 6. Contents list and headings
    n, ntoc = check_toc(doc, ng)
    if not ntoc:
        notes.append("-- no contents list")
    else:
        notes.append(count_line(n, "contents %d items match the headings" % ntoc,
                                "contents items that differ from the heading %d of %d"
                                % (n, ntoc)))

    # 7. Worker headings
    n, nhead = check_heads(doc, ng, WORKER_HEADS if ja else NEUTRAL_WORKER_HEADS)
    if not nhead:
        notes.append("-- no headings")
    else:
        notes.append(count_line(n, "headings %d, no worker headings" % nhead,
                                "worker headings %d of %d" % (n, nhead)))

    if ja:
        # 8. Commas in headings
        n, nhead = check_comma(doc, ng)
        if not nhead:
            notes.append("-- no headings (commas not checked)")
        else:
            notes.append(count_line(n, "headings %d, no commas" % nhead,
                                    "heading commas %d of %d" % (n, nhead)))

        # 8b. Identifier subjects with metaphor verbs
        n, nsent = check_subject(doc, ng)
        if not nsent:
            notes.append("-- no sentences (subjects not checked)")
        else:
            notes.append(count_line(n, "identifier-subject metaphors 0 of %d sentences" % nsent,
                                    "identifier-subject metaphors %d of %d sentences"
                                    % (n, nsent)))

    # 9. Link colors
    n, nlink = check_linkcolor(doc, ng, soft)
    if not nlink:
        notes.append("NG link color not set" if n else "-- no links (color not checked)")
    else:
        notes.append(count_line(n, "link colors %d, none blue" % nlink,
                                "blue link colors %d of %d" % (n, nlink)))

    # 10. Lengths and repeats (counted only)
    m = measure(raw, para_max, sent_max, dup_min, top, ja)
    npara = len(m["paras"])
    avg = sum(x[0] for x in m["paras"]) // npara if npara else 0
    notes.append("-- paragraphs %d / average %d chars / over %d chars %d"
                 % (npara, avg, para_max, m["n_long_p"]))
    notes.append("-- sentences %d / over %d chars %d"
                 % (len(m["sents"]), sent_max, m["n_long_s"]))
    notes.append("-- repeated sentences %d (sentences of %d chars or more)"
                 % (len(m["dup"]), dup_min))
    m["soft"] = soft
    return ng, notes, m


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("html")
    ap.add_argument("--words", action="append", default=None,
                    help="term table for this document (can be repeated)")
    ap.add_argument("--no-default-words", action="store_true",
                    help="leave out the bundled jargon list")
    ap.add_argument("--para", type=int, default=None,
                    help="characters that make a paragraph long (default 160 for Japanese, 700 otherwise)")
    ap.add_argument("--sent", type=int, default=None,
                    help="characters that make a sentence long (default 100 for Japanese, 220 otherwise)")
    ap.add_argument("--dup", type=int, default=22,
                    help="minimum characters of a sentence counted as a repeat")
    ap.add_argument("--top", type=int, default=5, help="how many of the longest items to list")
    a = ap.parse_args(argv)

    doc = io.open(a.html, encoding="utf-8").read()
    words = load_words(a.words) if a.words else None
    allow = load_allow(a.words) if a.words else None
    ng, notes, m = run(doc, words, not a.no_default_words,
                       a.para, a.sent, a.dup, a.top, allow)
    for line in notes:
        print(line)
    for line in ng:
        print("     %s" % line)
    for n, sid, text in m["long_p"]:
        print("     long paragraph %d chars (%s) %s..." % (n, sid, text[:40]))
    for n, sid, text in m["long_s"]:
        print("     long sentence %d chars (%s) %s..." % (n, sid, text[:40]))
    for text, where in m["dup"][:a.top]:
        print("     repeated sentence %dx (%s) %s..."
              % (len(where), ", ".join(where[:3]), text[:40]))
    for line in m["soft"][:a.top]:
        print("     %s" % line)
    print("---- %s (%s)"
          % ("no text findings" if not ng else "text findings %d" % len(ng),
             os.path.basename(a.html)))
    return 0 if not ng else 1


if __name__ == "__main__":
    sys.exit(main())
