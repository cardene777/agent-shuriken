# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "sudachipy>=0.6.8",
#     "sudachidict-core>=20240409",
# ]
# ///
"""日本語の比喩と文章の形を、直すか判断するために行ごとに指す。

合否や点数は出さない。Markdown の地の文だけを見て、上流の `lint.py` が
数えない 9 種類を返す。検出件数にかかわらず終了値は 0、入力を読めない時だけ 1。
後ろの 3 種類は `references/sentence-forms.md` の形のうち機械で数えられる分。
"""

from __future__ import annotations

import argparse
import csv
import dataclasses
import json
import re
import sys
from pathlib import Path

from textcore import (
    get_tokenizer,
    iter_lines_with_no,
    mask_markdown_structure,
    read_source_file,
    split_sentences_with_lines,
)


KINDS = (
    "比喩の動詞",
    "比喩の副詞",
    "サ変名詞で止めた文",
    "受け身の働きかけ",
    "短い断定",
    "文末のコロン",
    "URLの後の句点",
    "目的の断片",
    "括弧の長い補足",
)
METAPHOR_KINDS = ("擬人", "操作", "副詞")
# 上流の `mask_markdown_structure` は、リンクの記法の URL に加えて地の文に書いた URL も空白にする (#79)。
# そのため URL の後の句点は空白にする前の元の行で探し、リンクの記法 (`](` の直後) と山括弧の中の URL は数えない。
PERIOD_AFTER_URL = re.compile(r"(?<!\]\()(?<!<)https?://[^\s。)\]>`]+。\s*$")
BRACKET = re.compile(r"（[^（）]*）|\([^()]*\)")
# 初出の語に添える一言の訳より長い括弧を補足と見る。 理由や条件を書くと読点が入るか、これより長くなる。
BRACKET_GLOSS_MAX = 20
METAPHOR_WORDS = Path(__file__).resolve().parent.parent / "references" / "metaphor-words.tsv"
INLINE_SUBJECT = re.compile(
    r"(?P<code>``(?:[^`\n]|`(?!`))+``|`[^`\n]+`)(?P<gap>\s*)(?P<particle>[はが])"
)
SUBJECT_MARK = re.compile("\x01\\s*[はが]")
PASSIVE = re.compile(r"(?:推奨|期待|必要と)され|求められ|望まれ")
BOLD_ONLY = re.compile(r"^\s*\*\*(?:(?!\*\*).)+\*\*\s*$")
SHORT_ASSERTION_MAX = 10


@dataclasses.dataclass(frozen=True)
class Suspect:
    """行ごとの疑い。JSON と text の出力が同じ情報を使う。"""

    line: int
    kind: str
    match: str
    text: str

    def to_dict(self) -> dict[str, int | str]:
        return dataclasses.asdict(self)


def load_metaphor_words(path: Path) -> dict[str, list[re.Pattern[str]]]:
    """TSV の正規表現を種類ごとに読む。壊れた一覧は検査を続けず理由を返す。"""
    patterns: dict[str, list[re.Pattern[str]]] = {kind: [] for kind in METAPHOR_KINDS}
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            rows = (line for line in handle if line.strip() and not line.startswith("#"))
            reader = csv.DictReader(rows, delimiter="\t")
            if reader.fieldnames != ["種類", "正規表現", "よく指している操作"]:
                raise ValueError("列名が違う")
            for no, row in enumerate(reader, start=2):
                kind = row.get("種類", "")
                source = row.get("正規表現", "")
                if kind not in patterns or not source or not row.get("よく指している操作", ""):
                    raise ValueError(f"{no} 行目を読めない")
                try:
                    patterns[kind].append(re.compile(source))
                except re.error as exc:
                    raise ValueError(f"{no} 行目の正規表現を読めない ({exc})") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ValueError(f"一覧を読めない: {path} ({exc})") from exc
    empty = [kind for kind, values in patterns.items() if not values]
    if empty:
        raise ValueError(f"正規表現の無い種類: {'・'.join(empty)}")
    return patterns


def mark_identifier_subjects(raw_text: str, masked_text: str) -> str:
    """inline code の中身を見ず、直後が助詞の時だけ主語の印を残す。"""
    raw_lines = raw_text.split("\n")
    masked_lines = masked_text.split("\n")
    for index, (raw_line, masked_line) in enumerate(zip(raw_lines, masked_lines)):
        if not masked_line:
            continue
        chars = list(masked_line)
        for match in INLINE_SUBJECT.finditer(raw_line):
            chars[match.start("code")] = "\x01"
        masked_lines[index] = "".join(chars)
    return "\n".join(masked_lines)


def ends_with_period(raw_line: str, raw_sentence: str) -> bool:
    """文分割で落とした区切りが、短文とサ変を見る対象の句点かを確かめる。"""
    return re.search(re.escape(raw_sentence.rstrip()) + r"\s*。", raw_line) is not None


def sahen_ending(sentence: str) -> str | None:
    """格助詞「の」に続く文末の実質語がサ変可能な普通名詞なら返す。"""
    morphemes = get_tokenizer().tokenize(sentence)
    meaningful = [m for m in morphemes if m.part_of_speech()[0] not in {"空白", "補助記号"}]
    if len(meaningful) < 2:
        return None
    previous = meaningful[-2]
    last = meaningful[-1]
    pos = last.part_of_speech()
    previous_pos = previous.part_of_speech()
    if (
        previous.surface() == "の"
        and previous_pos[:2] == ("助詞", "格助詞")
        and pos[:3] == ("名詞", "普通名詞", "サ変可能")
    ):
        return last.surface()
    return None


def ends_with_noun(sentence: str) -> bool:
    """文末の実質語が名詞かを返す。"""
    morphemes = get_tokenizer().tokenize(sentence)
    meaningful = [m for m in morphemes if m.part_of_speech()[0] not in {"空白", "補助記号"}]
    return bool(meaningful) and meaningful[-1].part_of_speech()[0] == "名詞"


def ends_with_closing_bracket(sentence: str) -> bool:
    """元の文が閉じ括弧で終わるかを返す。"""
    return sentence.rstrip().endswith(("」", "』", "）", ")"))


def purpose_fragments(sentence: str) -> list[str]:
    """接尾辞の「用」に格助詞の「に」と読点が続く形を返す。

    「運用」「費用」は「用」で終わる 1 語の名詞なので、形態素で見れば指さない。
    """
    if "用に、" not in sentence:
        return []
    morphemes = list(get_tokenizer().tokenize(sentence))
    found = []
    for index in range(1, len(morphemes) - 2):
        suffix, particle, comma = morphemes[index : index + 3]
        if (
            suffix.surface() == "用"
            and suffix.part_of_speech()[0] == "接尾辞"
            and particle.surface() == "に"
            and particle.part_of_speech()[:2] == ("助詞", "格助詞")
            and comma.surface() == "、"
        ):
            found.append(morphemes[index - 1].surface() + "用に、")
    return found


def long_brackets(line: str) -> list[str]:
    """中身が読点か句点を含むか、空白を除いて一言の訳より長い括弧を返す。"""
    found = []
    for match in BRACKET.finditer(line):
        inside = re.sub(r"[\s\x01]", "", match.group(0)[1:-1])
        if re.search(r"[、。，．]", inside) or len(inside) > BRACKET_GLOSS_MAX:
            found.append(match.group(0))
    return found


def compact_length(sentence: str) -> int:
    """短い断定の長さから、空白と囲み・句読点だけを外す。"""
    return len(re.sub(r"[\s「」『』（）()。、！？!?]", "", sentence))


def find_suspects(
    raw_text: str, patterns: dict[str, list[re.Pattern[str]]]
) -> list[Suspect]:
    """地の文を走査し、9 種類の疑いを行番号つきで返す。"""
    masked = mask_markdown_structure(raw_text)
    marked = mark_identifier_subjects(raw_text, masked)
    lines = iter_lines_with_no(marked)
    raw_lines = dict(iter_lines_with_no(raw_text))
    sentences = split_sentences_with_lines(lines, raw_lines)
    findings: list[Suspect] = []

    for line_no, sentence, raw_sentence in sentences:
        has_identifier_subject = SUBJECT_MARK.search(sentence) is not None
        for metaphor_kind in ("擬人", "操作"):
            if metaphor_kind == "擬人" and not has_identifier_subject:
                continue
            for pattern in patterns[metaphor_kind]:
                for match in pattern.finditer(sentence):
                    findings.append(
                        Suspect(line_no, "比喩の動詞", match.group(0), raw_sentence)
                    )
        for pattern in patterns["副詞"]:
            for match in pattern.finditer(sentence):
                findings.append(Suspect(line_no, "比喩の副詞", match.group(0), raw_sentence))

        for match in PASSIVE.finditer(sentence):
            findings.append(Suspect(line_no, "受け身の働きかけ", match.group(0), raw_sentence))

        for fragment in purpose_fragments(sentence.replace("\x01", "")):
            findings.append(Suspect(line_no, "目的の断片", fragment, raw_sentence))

        raw_line = raw_lines.get(line_no, "")
        if not ends_with_period(raw_line, raw_sentence):
            continue
        plain = sentence.replace("\x01", "").strip()
        bold_only = BOLD_ONLY.fullmatch(raw_sentence) is not None
        if not bold_only and not ends_with_closing_bracket(raw_sentence):
            sahen = sahen_ending(plain)
            if sahen is not None:
                findings.append(Suspect(line_no, "サ変名詞で止めた文", sahen, raw_sentence))
        if (
            not bold_only
            and not ends_with_noun(plain)
            and compact_length(plain) <= SHORT_ASSERTION_MAX
            and not re.search(r"[\dA-Za-z`]", raw_sentence)
        ):
            findings.append(Suspect(line_no, "短い断定", plain, raw_sentence))

    for line_no, line in lines:
        match = re.search(r"[:：]\s*$", line)
        if match:
            findings.append(Suspect(line_no, "文末のコロン", match.group(0).strip(), raw_lines[line_no]))
        # 地の文の無い行 (code block の中など) は、空白にした後の行が空になるので見ない。
        match = PERIOD_AFTER_URL.search(raw_lines[line_no]) if line.strip() else None
        if match:
            findings.append(Suspect(line_no, "URLの後の句点", match.group(0).strip(), raw_lines[line_no]))
        for bracket in long_brackets(line):
            findings.append(Suspect(line_no, "括弧の長い補足", bracket, raw_lines[line_no]))

    order = {kind: index for index, kind in enumerate(KINDS)}
    findings.sort(key=lambda item: (item.line, order[item.kind], item.match))
    return findings


def print_text(path: Path, findings: list[Suspect], counts: dict[str, int]) -> None:
    """人が読む時も、行番号・種類・該当箇所を省かずに出す。"""
    print(f"=== suspects: {path} ===")
    for finding in findings:
        print(f"L{finding.line} [{finding.kind}] {finding.match}: {finding.text}")
    print("件数: " + " / ".join(f"{kind} {counts[kind]}" for kind in KINDS))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="検査する Markdown または平文")
    parser.add_argument("--json", action="store_true", help="機械可読な JSON で出力する")
    args = parser.parse_args()

    text, error = read_source_file(args.file)
    if error is not None:
        print(error, file=sys.stderr)
        return 1
    try:
        patterns = load_metaphor_words(METAPHOR_WORDS)
    except ValueError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1

    findings = find_suspects(text or "", patterns)
    counts = {kind: 0 for kind in KINDS}
    for finding in findings:
        counts[finding.kind] += 1
    if args.json:
        print(
            json.dumps(
                {
                    "file": str(args.file),
                    "counts": counts,
                    "findings": [finding.to_dict() for finding in findings],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        print_text(args.file, findings, counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
