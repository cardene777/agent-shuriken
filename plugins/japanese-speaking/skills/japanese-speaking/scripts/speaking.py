#!/usr/bin/env python3
"""Check a Japanese script meant to be spoken aloud.

Usage:
  speaking.py check <script> [--source <file>]...

The script is either JSON (a list of lines, or an object with "lines") whose lines have "text" and
an optional "speaker", or plain text with one utterance per line, written as name「text」 or as a
narration line without a name.

Output, one item per line:
  L<n> <pattern> <excerpt>     a pattern to fix, from references/patterns.tsv, or not-in-source
  note <name> <value>          a script-level value to read, which never changes the exit code

Exit codes: 0 when no pattern is found, 1 when at least one is found, 2 when the input cannot be read.
Only the Python 3 standard library is used.
"""

import argparse
import json
import re
import statistics
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "references"
SENTENCE_END = re.compile(r"(?<=[。？！?!])")
NAMED_LINE = re.compile(r"^\s*([^\s「」]{1,20}?)\s*「(.*)」\s*$")
BACKCHANNEL = re.compile(r"^(ええ|はい|なるほど|そうですね|そうなんですね|そうなんですか|そうなんですよ|へえ|確かに|本当ですね|ありますね)")
NE_YO = re.compile(r"(ね|よ|よね)[。？！?!]?$")
NUMBER = re.compile(r"\d+(?:\.\d+)?")
LATIN = re.compile(r"[A-Za-z][A-Za-z0-9+#.\-]*[A-Za-z0-9+#]|[A-Za-z]")
KATAKANA = re.compile(r"[ァ-ヴ][ァ-ヴー・]+")
SHORT_LIMIT = 10
LONG_SENTENCE = 50
REPEAT_RUN = 3


class InputError(Exception):
    pass


def load_patterns():
    rows = []
    lines = (DATA / "patterns.tsv").read_text(encoding="utf-8").splitlines()
    for row in lines[1:]:
        if not row.strip():
            continue
        name, pattern, exception, description = row.split("\t")
        rows.append((name, re.compile(pattern), re.compile(exception) if exception else None, description))
    return rows


def load_common_katakana():
    """Return the words of common-katakana.txt. Each word line holds the word, a tab, and its English meaning."""
    words = set()
    lines = (DATA / "common-katakana.txt").read_text(encoding="utf-8").splitlines()
    for number, row in enumerate(lines, start=1):
        if not row.strip() or row.startswith("#"):
            continue
        fields = row.split("\t")
        if len(fields) != 2 or not fields[0].strip() or not fields[1].strip():
            raise InputError(f"references/common-katakana.txt line {number} needs a word, a tab, and its English meaning")
        words.add(fields[0].strip())
    return words


def read_script(path):
    """Return (utterances, readings). Each utterance is (line number, speaker, text)."""
    file = Path(path)
    if not file.is_file():
        raise InputError(f"{path} is not a readable file")
    try:
        raw = file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as err:
        raise InputError(f"{path} cannot be read as UTF-8 text ({err.__class__.__name__})")
    if file.suffix == ".json" or raw.lstrip().startswith(("{", "[")):
        return read_json(path, raw)
    return read_text(raw), {}


def read_json(path, raw):
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as err:
        raise InputError(f"{path} is not valid JSON (line {err.lineno}, column {err.colno})")
    readings = {}
    if isinstance(data, dict):
        if not isinstance(data.get("lines"), list):
            raise InputError(f"{path} has no \"lines\" list")
        readings = data.get("readings") or {}
        if not isinstance(readings, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in readings.items()):
            raise InputError(f"{path} has a \"readings\" value that is not an object of strings")
        data = data["lines"]
    if not isinstance(data, list):
        raise InputError(f"{path} is neither a list of lines nor an object with \"lines\"")
    utterances = []
    for index, line in enumerate(data, 1):
        if not isinstance(line, dict) or not isinstance(line.get("text"), str):
            raise InputError(f"{path} line {index} has no \"text\" string")
        speaker = line.get("speaker")
        if speaker is not None and not isinstance(speaker, str):
            raise InputError(f"{path} line {index} has a \"speaker\" that is not a string")
        utterances.append((index, speaker, line["text"].strip()))
    return utterances, readings


def read_text(raw):
    utterances = []
    for number, row in enumerate(raw.splitlines(), 1):
        if not row.strip():
            continue
        named = NAMED_LINE.match(row)
        if named:
            utterances.append((number, named.group(1), named.group(2).strip()))
        else:
            utterances.append((number, None, row.strip()))
    return utterances


def sentences(text):
    return [part.strip() for part in SENTENCE_END.split(text) if part.strip()]


def excerpt(text, limit=40):
    return text if len(text) <= limit else text[: limit - 1] + "…"


def find_patterns(utterances, patterns):
    found = []
    for number, _, text in utterances:
        for sentence in sentences(text):
            for name, pattern, exception, _ in patterns:
                if pattern.search(sentence) and not (exception and exception.search(sentence)):
                    found.append((number, name, excerpt(sentence)))
    return found


def splits_into(word, common, source):
    """Return whether a katakana word is a run of common words and words in the source."""
    ends = {0}
    for end in range(1, len(word) + 1):
        for start in sorted(ends):
            part = word[start:end]
            if start < end and (part in common or (len(part) > 1 and part in source)):
                ends.add(end)
                break
    return len(word) in ends


def find_absent(utterances, readings, sources, common):
    source = unicodedata.normalize("NFKC", "\n".join(sources))
    lowered = source.lower()
    found = []
    for number, _, text in utterances:
        normal = unicodedata.normalize("NFKC", text)
        seen = set()
        tokens = [(m.start(), m.group(0)) for regex in (NUMBER, LATIN) for m in regex.finditer(normal)]
        tokens += [(m.start(), m.group(0)) for m in KATAKANA.finditer(text)]
        for _, token in sorted(tokens):
            if token in seen or token == "1":
                continue
            seen.add(token)
            if token in readings:
                present = readings[token].lower() in lowered
            elif NUMBER.fullmatch(token):
                present = re.search(rf"(?<![\d.]){re.escape(token)}(?![\d])", source) is not None
            elif KATAKANA.fullmatch(token):
                present = token in source or splits_into(token, common, source)
            else:
                present = token.lower() in lowered
            if not present:
                found.append((number, "not-in-source", token))
    return found


def notes(utterances):
    out = []
    lengths = [len(re.sub(r"\s", "", text)) for _, _, text in utterances]
    if not lengths:
        return out
    mean = statistics.fmean(lengths)
    cv = statistics.pstdev(lengths) / mean if mean else 0.0
    out.append(f"utterance-length-median {statistics.median(lengths):g}")
    out.append(f"utterance-length-cv {cv:.2f}")
    short = sum(1 for n in lengths if n <= SHORT_LIMIT) / len(lengths)
    out.append(f"short-utterance-ratio {short:.2f} ({SHORT_LIMIT} characters or fewer)")
    backchannels = sum(1 for _, _, text in utterances if BACKCHANNEL.match(text))
    out.append(f"backchannel-count {backchannels} of {len(utterances)} utterances")
    all_sentences = [s for _, _, text in utterances for s in sentences(text)]
    ne_yo = sum(1 for s in all_sentences if NE_YO.search(s)) / len(all_sentences) if all_sentences else 0.0
    out.append(f"ne-yo-ratio {ne_yo:.2f}")
    endings = []
    for number, _, text in utterances:
        last = sentences(text)[-1] if sentences(text) else ""
        endings.append((number, re.sub(r"[。？！?!]+$", "", last)[-2:]))
    start = 0
    while start < len(endings):
        end = start
        while end + 1 < len(endings) and endings[end + 1][1] == endings[start][1] and endings[start][1]:
            end += 1
        if end - start + 1 >= REPEAT_RUN:
            out.append(f"repeated-ending L{endings[start][0]}-L{endings[end][0]} {endings[start][1]}")
        start = end + 1
    for number, _, text in utterances:
        for sentence in sentences(text):
            if len(sentence) > LONG_SENTENCE:
                out.append(f"long-sentence L{number} {len(sentence)} characters")
    return out


def check(args):
    try:
        utterances, readings = read_script(args.script)
        sources = []
        for path in args.source or []:
            file = Path(path)
            if not file.is_file():
                raise InputError(f"{path} is not a readable source file")
            sources.append(file.read_text(encoding="utf-8", errors="replace"))
        common = load_common_katakana() if args.source else set()
    except InputError as err:
        print(f"error: {err}", file=sys.stderr)
        return 2
    found = find_patterns(utterances, load_patterns())
    if args.source:
        found += find_absent(utterances, readings, sources, common)
    found.sort(key=lambda item: item[0])
    for number, name, detail in found:
        print(f"L{number} {name} {detail}")
    for line in notes(utterances):
        print(f"note {line}")
    return 1 if found else 0


def patterns_command(args):
    del args
    for name, _, _, description in load_patterns():
        print(f"{name}: {description}")
    print("not-in-source: A number or name in the script is absent from the source material")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="speaking.py", description="Check a Japanese script meant to be spoken aloud.")
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("check", help="report patterns that sound read from a script, and script-level notes")
    run.add_argument("script", help="a JSON script or a plain text script")
    run.add_argument("--source", action="append", help="source material; numbers and names absent from it are reported")
    run.set_defaults(func=check)
    listing = commands.add_parser("patterns", help="list the patterns check reports and how to fix each")
    listing.set_defaults(func=patterns_command)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
