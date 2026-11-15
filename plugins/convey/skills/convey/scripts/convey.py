#!/usr/bin/env python3
"""Checks a message before it is pasted into Slack, Discord, an email, a GitHub comment, or a plain text box,
and copies it to the clipboard once nothing in it must change.

  convey.py check --to DEST [FILE|-]               exit 0 when it can be pasted, 1 when a line must change
  convey.py copy --to DEST [--lines A-B] [FILE|-]  copies after the same check; exit 1 refused, 3 not copied
  convey.py formats                                each destination, its limit, and what it does not render

The message is read from FILE, or from standard input when FILE is missing or "-".
Lengths are counted in UTF-16 code units, the way the destinations count them, after trailing blank lines.
A finding names the line and the kind of problem, never the value: a secret-looking value, a local path,
or an email address on a line is reported without printing it. Lines starting with "L<n> warn:" are advice
and do not change the exit code. Nothing is sent anywhere; copy only hands the text to a local clipboard tool.
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FILLER_FILE = HERE.parent / "references" / "filler-phrases.tsv"

# name: (limit or None, kinds of Markdown it shows as typed, what `formats` says it does not render)
MARKDOWN = ("heading", "bold", "table", "link", "fence", "code")
DESTINATIONS = {
    "slack": (4000, ("heading", "bold", "table", "link"), "# headings, **bold**, tables, [text](url) links"),
    "discord": (2000, ("table",), "tables"),
    "email": (None, MARKDOWN, "Markdown (# headings, **bold**, tables, [text](url) links, code fences, "
                              "backticks); the first line is the subject"),
    "github": (65536, (), "nothing that check looks for"),
    "plain": (None, MARKDOWN, "Markdown (# headings, **bold**, tables, [text](url) links, code fences, backticks)"),
}
EMOJI_AT_HEADINGS = ("slack", "discord")

FORMAT_PATTERNS = {
    "heading": re.compile(r"^ {0,3}#{1,6}\s"),
    "bold": re.compile(r"\*\*[^*\n]+\*\*|(?<!\w)__[^_\n]+__(?!\w)"),
    "table": re.compile(r"^\s*\|.*\|\s*$"),
    "link": re.compile(r"\[[^\]\n]+\]\([^)\s]+\)"),
    "fence": re.compile(r"^\s*(```|~~~)"),
    "code": re.compile(r"`[^`\n]+`"),
}
FORMAT_ADVICE = {
    "heading": "a # heading, which {name} shows as typed; {heading}",
    "bold": "**bold**, which {name} shows with the asterisks; {bold}",
    "table": "a table{rows}, which {name} shows as pipes; use a short list instead",
    "link": "a [text](url) link, which {name} shows as typed; put the URL itself after the text",
    "fence": "a code fence, which {name} shows as backticks; indent the lines or drop the fence",
    "code": "backticks, which {name} shows as typed; drop them or use quotes",
}
HEADING_FIX = {"slack": "start the line with one emoji or use *bold*"}
BOLD_FIX = {"slack": "use *bold* with one asterisk"}
DISPLAY = {"slack": "Slack", "discord": "Discord", "email": "an email", "github": "GitHub", "plain": "plain text"}

# Prefixes of a subject line: "Subject:" and the Japanese word for subject, with an ASCII or a full-width colon.
SUBJECT = re.compile(r"^(subject|件名)\s*[:：]", re.I)

SECRETS = [
    ("GitHub token", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("AWS access key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("webhook URL", re.compile(r"/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]{16,}|/api/webhooks/\d+/[\w-]{30,}")),
    ("API key", re.compile(r"\bsk-(ant-|proj-)?[A-Za-z0-9_-]{20,}")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}")),
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("JSON web token", re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}")),
    ("URL with a password", re.compile(r"://[^/\s:@]+:[^/\s@]+@")),
    ("password or token", re.compile(
        r"(?i)\b(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key)\b\s*[:=]\s*['\"]?"
        r"(?=[^\s'\"]*\d)(?=[^\s'\"]*[A-Za-z])[^\s'\"]{8,}")),
]
PRIVATE = [
    ("a local path under a user's home folder",
     re.compile(r"/Users/[A-Za-z0-9._-]+/|/home/[a-z_][a-z0-9_-]*/|\b[A-Za-z]:\\Users\\[^\\\s]+")),
    ("an email address", re.compile(r"\b([A-Za-z0-9._%+-]+)@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b")),
    ("a phone number", re.compile(r"(?<![\d-])(0\d{1,4}-\d{1,4}-\d{3,4}|\+\d{1,3}[ -]\d{1,4}[ -]\d{3,4}[ -]\d{3,4})(?![\d-])")),
]
NOT_PERSONAL_MAIL = {"noreply", "no-reply", "git"}

EMOJI = ("\U0001F000-\U0001FAFF\u2600-\u27bf\u2b50\u2b55\u2b1b\u2b1c\u231a\u231b\u23e9-\u23f3\u23f8-\u23fa")
EMOJI_CHAR = re.compile("[" + EMOJI + "]")
LEADING_EMOJI = re.compile(r"^\s*(?:[#>*_~-]+\s*)*[" + EMOJI + r"](?:\ufe0f|[\U0001F3FB-\U0001F3FF]|\u200d[" + EMOJI + r"]\ufe0f?)*")

# A line that starts with a short label and a colon, such as "影響: 340件" or "- *Impact:* 340". Markup is
# dropped before matching; an ASCII colon counts only before a space, so times and URLs do not match.
LABEL_PAIR = re.compile(r"^\s*(?:[-•・]\s*)?(?:[^\s:：]+ ){0,3}[^\s:：]+(?::\s|：)")
MARKUP = re.compile(r"[*_]")
# A space between Japanese and a Latin letter or digit. Code spans, URLs, paths, file names, and mentions are
# dropped first, since the space around them is not counted.
JAPANESE = "".join(f"{chr(a)}-{chr(b)}" for a, b in ((0x3040, 0x30FF), (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xFF66, 0xFF9F)))
JP_LATIN_SPACE = re.compile(f"[{JAPANESE}] [A-Za-z0-9]|[A-Za-z0-9] [{JAPANESE}]")
NOT_PROSE = re.compile(r"`[^`]*`|https?://\S+|\S*/\S*|[\w.-]+\.[A-Za-z][A-Za-z0-9]{0,4}\b|<[@#]!?\d+>|@[\w.-]+")

CLIPBOARD_TOOLS = [
    ("pbcopy", []),
    ("wl-copy", []),
    ("xclip", ["-selection", "clipboard"]),
    ("xsel", ["--clipboard", "--input"]),
    ("clip.exe", []),
]


def units(text):
    """Length in UTF-16 code units."""
    return len(text.encode("utf-16-le")) // 2


def load_fillers():
    fillers = []
    for raw in FILLER_FILE.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        phrase, _, hint = raw.partition("\t")
        fillers.append((phrase, hint.strip() or "cut it"))
    return fillers


def fence_flags(lines):
    """For each line, whether it sits inside a code fence (fence lines themselves count as inside)."""
    inside, flags = False, []
    for line in lines:
        if FORMAT_PATTERNS["fence"].match(line):
            flags.append(True)
            inside = not inside
        else:
            flags.append(inside)
    return flags


def split_parts(lines, limit, fenced):
    """Pack paragraphs (runs of lines between blank lines outside code fences) into parts within the limit.
    Returns (first line, last line, length) with 1-based line numbers."""
    paragraphs, start = [], None
    for i, line in enumerate(lines):
        if line.strip() or fenced[i]:
            start = i if start is None else start
        elif start is not None:
            paragraphs.append((start, i - 1))
            start = None
    if start is not None:
        paragraphs.append((start, len(lines) - 1))

    pieces = []
    for a, b in paragraphs:
        if units("\n".join(lines[a:b + 1])) <= limit:
            pieces.append((a, b))
        else:
            pieces.extend((i, i) for i in range(a, b + 1))

    parts = []
    for a, b in pieces:
        if parts:
            pa, _ = parts[-1]
            if units("\n".join(lines[pa:b + 1])) <= limit:
                parts[-1] = (pa, b)
                continue
        parts.append((a, b))
    return [(a + 1, b + 1, units("\n".join(lines[a:b + 1]))) for a, b in parts]


def inspect(text, dest, offset=0):
    """Returns (summary lines, hard findings, warnings, over the limit); findings are (line number, text)."""
    limit, unsupported, _ = DESTINATIONS[dest]
    lines = text.rstrip().split("\n")
    fenced = fence_flags(lines)
    hard, warn = [], []
    name = DISPLAY[dest]

    for i, line in enumerate(lines):
        n = i + 1 + offset
        for kind, pattern in SECRETS:
            if pattern.search(line):
                hard.append((n, f"secret: looks like a {kind}; remove it and say where the reader can find it"))
        for kind, pattern in PRIVATE:
            match = pattern.search(line)
            if match and not (kind == "an email address" and match.group(1).lower() in NOT_PERSONAL_MAIL):
                hard.append((n, f"private: {kind}; remove it or write a placeholder"))

        for kind in unsupported:
            pattern = FORMAT_PATTERNS[kind]
            if kind == "fence":
                if pattern.match(line):
                    hard.append((n, "format: " + FORMAT_ADVICE[kind].format(name=name)))
                continue
            if fenced[i] or not pattern.search(line):
                continue
            rows = ""
            if kind == "table":
                if i and not fenced[i - 1] and pattern.search(lines[i - 1]):
                    continue  # one finding per table, on its first row
                last = i
                while last + 1 < len(lines) and not fenced[last + 1] and pattern.search(lines[last + 1]):
                    last += 1
                rows = f" (lines {n}-{n + last - i})" if last > i else ""
            advice = FORMAT_ADVICE[kind].format(
                name=name, rows=rows,
                heading=HEADING_FIX.get(dest, "write the heading as a plain line"),
                bold=BOLD_FIX.get(dest, "drop the asterisks"))
            hard.append((n, "format: " + advice))

        if fenced[i]:
            continue
        lowered = line.lower()
        found = [(phrase, hint) for phrase, hint in FILLERS if phrase.lower() in lowered]
        for phrase, hint in found:
            # "Hope this helps" inside "I hope this helps" is one phrase, reported once.
            if not any(phrase.lower() in other.lower() and phrase != other for other, _ in found):
                warn.append((n, f'warn: filler phrase "{phrase}" ({hint})'))
        if LABEL_PAIR.match(MARKUP.sub("", line)) and not SUBJECT.match(line.strip()):
            warn.append((n, "warn: label and colon; write the line as a sentence"))
        if JP_LATIN_SPACE.search(NOT_PROSE.sub("", line)):
            warn.append((n, "warn: space between Japanese and Latin letters; remove it"))
        if dest in EMOJI_AT_HEADINGS:
            rest = LEADING_EMOJI.sub("", line, count=1)
            if EMOJI_CHAR.search(rest):
                warn.append((n, "warn: emoji in the middle or at the end of a line; keep one at the start of a heading"))
        elif EMOJI_CHAR.search(line):
            warn.append((n, f"warn: emoji, which messages in {name} usually do without"))

    if dest == "email":
        first = next((i for i, line in enumerate(lines) if line.strip()), 0)
        if not SUBJECT.match(lines[first].strip()):
            hard.append((first + 1 + offset, "format: the first line is not a subject line; start with "
                                             "\"Subject: \" and the subject"))

    length = units("\n".join(lines))
    summary = []
    if limit is None:
        summary.append(f"{length} characters")
    elif length <= limit:
        summary.append(f"{length} of {limit} characters")
    else:
        summary.append(f"over the limit: {length} of {limit} characters")
        summary.append("split it into these parts at blank lines and paste them one by one:")
        for k, (a, b, size) in enumerate(split_parts(lines, limit, fenced), 1):
            note = "" if size <= limit else "; this line alone is over the limit, so split it inside the line"
            summary.append(f"part {k}: lines {a + offset}-{b + offset}, {size} characters{note}")
    return summary, hard, warn, limit is not None and length > limit


def report(summary, hard, warn):
    for line in summary:
        print(line)
    for n, message in sorted(hard + warn, key=lambda f: f[0]):
        print(f"L{n} {message}")


def read_text(source):
    try:
        if source in (None, "-"):
            return sys.stdin.buffer.read().decode("utf-8").replace("\r\n", "\n")
        return Path(source).read_text(encoding="utf-8").replace("\r\n", "\n")
    except (OSError, UnicodeDecodeError) as err:
        print(f"cannot read the message: {err}", file=sys.stderr)
        sys.exit(2)


def cmd_check(args):
    summary, hard, warn, over = inspect(read_text(args.file), args.to)
    report(summary, hard, warn)
    if hard or over:
        print("not ready: change the lines above and run check again")
        return 1
    print("ready to paste" + (", after reading the warnings" if warn else ""))
    return 0


def cmd_copy(args):
    text = read_text(args.file)
    offset = 0
    if args.lines:
        match = re.fullmatch(r"(\d+)-(\d+)", args.lines)
        lines = text.split("\n")
        if not match or not 1 <= int(match.group(1)) <= int(match.group(2)) <= len(lines):
            print(f"--lines takes A-B within 1-{len(lines)}", file=sys.stderr)
            return 2
        a, b = int(match.group(1)), int(match.group(2))
        text, offset = "\n".join(lines[a - 1:b]), a - 1
    summary, hard, warn, over = inspect(text, args.to, offset)
    if hard or over:
        report(summary, hard, warn)
        print("not copied: change the lines above first")
        return 1

    tried = []
    for tool, extra in CLIPBOARD_TOOLS:
        found = shutil.which(tool)
        if not found:
            continue
        data = ("\ufeff" + text).encode("utf-16-le") if tool == "clip.exe" else text.encode("utf-8")
        try:
            done = subprocess.run([found, *extra], input=data, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL, timeout=10)
        except (OSError, subprocess.TimeoutExpired):
            tried.append(f"{tool} did not finish")
            continue
        if done.returncode == 0:
            print(f"copied {units(text.rstrip())} characters to the clipboard with {tool}")
            return 0
        tried.append(f"{tool} exited {done.returncode}")
    names = ", ".join(tool for tool, _ in CLIPBOARD_TOOLS)
    reason = "; ".join(tried) if tried else f"no clipboard tool found (looked for {names})"
    print(f"not copied: {reason}")
    return 3


def cmd_formats(_args):
    for name, (limit, _, missing) in DESTINATIONS.items():
        print(f"{name:<9} {str(limit) if limit else 'none':<6} does not render: {missing}")
    return 0


FILLERS = []


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for command, about in (("check", "check a message for a destination"),
                           ("copy", "check a message, then copy it to the clipboard")):
        p = sub.add_parser(command, help=about)
        p.add_argument("--to", required=True, choices=sorted(DESTINATIONS))
        if command == "copy":
            p.add_argument("--lines", help="copy only lines A-B, such as one part of a long message")
        p.add_argument("file", nargs="?", help="the message file, or - for standard input (the default)")
    sub.add_parser("formats", help="list each destination, its limit, and what it does not render")
    args = parser.parse_args()
    FILLERS.extend(load_fillers())
    return {"check": cmd_check, "copy": cmd_copy, "formats": cmd_formats}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
