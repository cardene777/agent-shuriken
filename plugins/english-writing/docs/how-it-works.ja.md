# 仕組み

[English](how-it-works.md) · 日本語

このページは、English Writingが読む物、動かす物、残す物と、上流から写したファイルとその更新の手順を書きます。
文章を書いて直すのはエージェントで、道具は疑わしい行を指して端末に出すだけです。
AIらしく聞こえる文章の型は`blader/humanizer`から変えずに写しています。

## スキルのファイル

パスは`skills/english-writing/`からの相対です。

| パス | 出どころ | 中身 |
|---|---|---|
| `SKILL.md` | このプラグイン | 最初に読む物、他のスキルが従う中身、道具の走らせ方 |
| `references/rules.md` | このプラグイン。3つの文体の手引きから短く引いています | 優先の順、日本語から直訳した言い回し、文の長さ、用語、平易な英語、曖昧な語の決まりと、直した点の返し方 |
| `references/translationese.tsv` | このプラグイン | `suspects.py`が照らす、日本語から直訳した言い回しの一覧。各行に例文と、代わりに書く形を持ちます |
| `musubi.json` | このプラグイン | 他のスキルがmusubiを通して従う中身`rules`、バージョン1.0.0。ファイルは`references/rules.md`です |
| `scripts/suspects.py` | このプラグイン | 長い文、受動態、日本語から直訳した言い回しを指します |
| `upstream-manifest.txt` | このプラグイン | 上流から写した各ファイルのSHA-256 |
| `tests/test-english-writing.sh` | このプラグイン | このプラグインの検査 |
| `UPSTREAM-SKILL.md` | 上流 | 上流の`SKILL.md`。AIらしく聞こえる文章の26の型と、それぞれの書き直し方と、手を出さない時を持ちます |
| `LICENSE` | 上流 | 上流のMITライセンス |

## 道具

| 道具 | 読む物 | 出す物 |
|---|---|---|
| `suspects.py` | 渡されたMarkdownかテキストのファイルと、`references/translationese.tsv` | ファイルごとに、疑わしい箇所を1件1行で、行番号、種類、語、注記とともに出し、最後に3種類それぞれの件数を出します。見つけた数にかかわらず0で終わり、ファイルが無い時は2、言い回しの一覧が壊れている時は1で終わります |
| proselint 0.16.0 | 渡されたファイルと、`/etc/proselintrc`、`~/.proselintrc.json`、`~/.config/proselint/config.json`、今のフォルダの`.proselintrc.json`のうち在る設定ファイル | 見つけた物1件ごとに、検査の名前、文、行と列を持つJSON。何か見つけると1で終わります |

`suspects.py`は地の文だけを読みます。
front matter、囲みのコード、インラインのコード、HTMLのコメント、リンクの先、URLは読みません。
25語を超える文を長い文として指し、コード、コマンド、パス、URLはそれぞれ1語と数えます。
どちらの道具もファイルを書きません。

## 動かす物と繋ぐ先

- `suspects.py`は`python3 <skill folder>/scripts/suspects.py <file>`で走り、Pythonの標準ライブラリだけを読み込みます
- proselintは`uv run --with proselint==0.16.0 proselint check --output-format json <file>`で走ります。初回に`uv`がproselint 0.16.0と、それが要る`google-re2`と`google-re2-stubs`をPython Package Indexからキャッシュへ取りに行きます。キャッシュはmacOSとLinuxでは`~/.cache/uv`で、`UV_CACHE_DIR`が別のフォルダを指す時はそちらです。合うPythonが見つからない時は、`uv`がPythonを取りに行くことがあります
- `uv`が無い時、エージェントはproselintを飛ばし、決まり文句、ぼかし、曖昧な語を`references/rules.md`で目で確かめます
- このプラグインは文章をどこへも送らない作りです。道具は手元のファイルを読み、端末に出します
- 上流から写していない物は、上流のパッケージ自身を確かめる`scripts/validate-package.py`と、上流のリポジトリのマニフェスト、文書、設定です

## 残す物

何も残しません。
エージェントは途中のファイルをプロジェクトの外の一時フォルダに置き、終わる時に消します。
proselintは`uv cache clean`を実行するまでuvのキャッシュに残ります。

## 上流の写しの更新

上流のファイルだけを写し、このプラグイン自身のファイルはそのまま残します。

1. 新しいcommitの`blader/humanizer`を空のフォルダに取ってきます
2. その`SKILL.md`を`UPSTREAM-SKILL.md`として、`LICENSE`はそのままの名前で、スキルのフォルダに写します。`scripts/`とリポジトリの他のファイルは写しません
3. スキルのフォルダで指紋を作り直し、指紋の行を出力で置き換えます。`#`の行は残し、`# Source:`の行のcommitを変えます

   ```bash
   grep -E '^[0-9a-f]{64}  ' upstream-manifest.txt | cut -c67- | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done
   ```

4. `UPSTREAM-SKILL.md`の差分を読み、`references/rules.md`と`SKILL.md`が合わなくなった所を直します
5. `THIRD_PARTY_NOTICES.md`のcommitと日付、`tests/test-english-writing.sh`の`COMMIT`を変えます
6. プラグインのフォルダから`bash skills/english-writing/tests/test-english-writing.sh`を実行します
