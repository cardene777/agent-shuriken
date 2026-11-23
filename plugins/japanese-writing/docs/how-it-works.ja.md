# 仕組み

[English](how-it-works.md) · 日本語

このページは、Japanese Writingが読む物、動かす物、残す物と、どのファイルが上流から来たかと、その更新の仕方を書きます。
文章を書いて直すのはエージェントで、`skills/japanese-writing/scripts/`の道具は疑わしい行を指して端末に出すだけです。
手順と大半の道具といくつかの参照は、`coji/natural-japanese` v2.0.0から手を入れずに写した物です。

## スキルのファイル

パスは`skills/japanese-writing/`から見た形です。

| パス | 出どころ | 中身 |
|---|---|---|
| `SKILL.md` | このプラグイン | 先に読む物と、ほかのスキルが準拠するコンテンツと、道具の回し方 |
| `references/rules.md` | このプラグイン | 優先の順、repoに置くMarkdownの書式、プラグインの規範、各参照を読む時、直しの返し方 |
| `references/terminology.md`、`subject-and-verb.md`、`ai-smell.md`、`explaining.md`、`asking.md`、`natural-explanation.md`、`sentence-forms.md` | このプラグイン | 語の選び方、物が比喩の動詞の主語に立つ文の直し方、AIらしい文の3つの形、説明の組み立て方、問いと選択肢の書き方、記事の導入、文の8つの形 |
| `references/connecting.md` | このプラグイン (文化庁の2つの資料を加工して作成) | 人に伝える文で、長い文を区切り、関係ごとの接続詞で結び、結論を先に置く書き方 |
| `musubi.json` | このプラグイン | ほかのスキルがmusubiで準拠するコンテンツ`connecting`のバージョン1.0.0。ファイルは`references/connecting.md` |
| `references/metaphor-words.tsv` | このプラグイン | `suspects.py`が当てる比喩の語と正規表現。行ごとに、何を見つけて何と書けばよいかの英語の説明を持つ |
| `references/<名前>.en.md`、`references/doctypes/<名前>.en.md` | このプラグイン (隣の参照を英訳) | 同じ決まりの英語版。Markdownの参照ごとに同じ見出しと表で隣に置き、英語で読む人が使う。スキルは日本語のファイルだけを読む |
| `scripts/suspects.py` | このプラグイン | `lint.py`が数えない形を指す道具 |
| `upstream-manifest.txt` | このプラグイン | 上流から写した全てのファイルのSHA-256 |
| `tests/test-japanese-writing.sh` | このプラグイン | プラグインの検査 |
| `UPSTREAM-SKILL.md` | 上流 | 上流の`SKILL.md`。書くところから後片付けまでの手順 |
| `references/diagnose.md`、`references/manual-checklist.md`、`references/doctypes/` | 上流 | 文章の採点の仕方、`uv`が無い時に目で確かめる観点、文書の種類ごとの手引き |
| `scripts/lint.py`、`outline.py`、`paragraphs.py`、`terms.py`、`calques.py`、`newfacts.py`、`textcore.py`、`fixtures/` | 上流 | 道具と、道具が共有するcodeと、2つの見本の文章 |
| `assets/style-profile-template.md` | 上流 | 書き手の文体のプロファイルの雛形。文体を学ばせたいと頼んだ時だけ使います |
| `LICENSE` | 上流 | 上流のMITライセンス |

## 道具

| 道具 | 読む物 | 出す物 |
|---|---|---|
| `lint.py` | Markdownかテキストのファイル1つ | 種類ごとの疑わしい言い回しと直し方、1つずつ確かめる段落の一覧。`--json`は同じ内容をJSONで出し、`--reading-load`は読みにくい文を指します |
| `suspects.py` | Markdownのファイル1つ | 疑わしい文ごとに行番号と種類と語を1行で出し、最後に9種類の件数を出します。何が見つかっても0で終わり、ファイルを読めない時だけ1で終わります |
| `outline.py` | ファイル1つ | 見出し、各段落の最初の文、箇条書きを行番号つきで出します |
| `paragraphs.py` | ファイル1つ | 1つずつ確かめるための、番号つきの全ての段落 |
| `terms.py` | ファイル1つ | 各専門用語が最初に出る場所と、そこで説明しているか |
| `calques.py` | ファイル1つ | 機械の処理を人の動きで言う動詞と、仕組みを場所にたとえる名詞 |
| `newfacts.py` | 元のファイルと新しいファイル、または`--git`と1つのファイル | 新しい文にあって元に無い数値と固有名詞。`--git`では、commitした版を`git show`で読みます |

どの道具もファイルを書きません。
`textcore.py`は道具が共有するcodeで、`fixtures/`は上流の本文が例に使う見本です。

## 動かす物と繋ぐ先

- 道具は`PYTHONDONTWRITEBYTECODE=1 uv run --script <skill folder>/scripts/<script>.py`の形で動き、Pythonがスキルのフォルダに`__pycache__`を書かないようにします
- `uv`は各道具の先頭に書いた依存の`sudachipy>=0.6.8`と`sudachidict-core>=20240409`を読み、初めて使う時にPython Package Indexから自分の置き場に取りに行きます。合わせて約200MBです。置き場は、`UV_CACHE_DIR`で別のフォルダを指さなければ、macOSとLinuxでは`~/.cache/uv`です。Python 3.10以降が見つからない時は、`uv`がPythonを取りに行くことがあります
- `newfacts.py --git`は、渡したファイルのフォルダで`git show`を動かします
- あなたの文章はどこへも送らない作りです。道具は手元のファイルを読み、端末に出します
- 上流から外した物は、約1GBのモデルを取りに行きモデルのcodeを実行する`semantic.py`、閾値を合わせる`calibrate.py`と`corpus/`、`critical-thinking`のスキルです

## 残す物

何も残しません。
作業中のファイルは、上流の本文の最後の手順のとおり、エージェントがプロジェクトの外の一時のフォルダに置き、終わる時に消します。
取りに行った包みは、`uv cache clean`を実行するまでuvの置き場に残ります。

## 上流の写しの更新

プラグインのファイルをそのまま残すため、上流のファイルだけを写します。

1. 新しいcommitの`coji/natural-japanese`を空のフォルダに取り寄せます
2. `upstream-manifest.txt`が載せるファイルを、上流の`skills/natural-japanese/`から写します。上流の`SKILL.md`は`UPSTREAM-SKILL.md`として、`LICENSE`は上流の根から写します。`scripts/semantic.py`、`scripts/calibrate.py`、`corpus/`、ほかのスキルは写しません。上流の本文が名指す新しいファイルは`upstream-manifest.txt`に行を足し、上流が消したファイルは行を消します
3. スキルのフォルダで指紋を作り直し、出た行で指紋の行を置き換えます。`#`の行は残し、`# Source:`の行のcommitを書き換えます

   ```bash
   grep -E '^[0-9a-f]{64}  ' upstream-manifest.txt | cut -c67- | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done
   ```

4. `UPSTREAM-SKILL.md`の差分を読み、合わなくなった所を`references/rules.md`、プラグインの参照、`SKILL.md`で直します
5. `THIRD_PARTY_NOTICES.md`のcommitと日付と、`tests/test-japanese-writing.sh`の`COMMIT`を書き換えます
6. プラグインのフォルダで`bash skills/japanese-writing/tests/test-japanese-writing.sh`を実行します
