# Doc Review

仕様書、設計書、READMEを公開やマージの前に新しい目で1回だけ見直し、見つかった点を直します。

[English](README.md) · 日本語

文書を書いた人は、込めた意図を知ったうえで読むので、抜けや食い違いや切れたリンクを見落とします。書いたエージェント自身に見直させても同じことが起きます。
このプラグインはまず、スクリプトで確かめられる形を調べます。見出しの階層、見出しの番号、リンクとアンカー、表、コードブロックです。
次に、会話を引き継がない2人の見直し役が文書を読みます。1人は文書の種類に応じた中身を、もう1人は形を確かめます。
エージェントは指摘を1つずつ自分で確かめ、該当する節を直すか、直さない理由を残し、1回で終えます。2回目を回すと、文書が良くなるより先に新しい細かい指摘が出続けるためです。

```
形を確かめる ──> 中身と形を見直す ──> 指摘ごとに直すか退ける ──> 記録して報告する
 (スクリプト)      (新しい見直し役2人)    (エージェント)              (スクリプトとエージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install doc-review@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add doc-review@agent-shuriken
```

## 使い方

このプラグインは、「公開する前にdocs/SPEC.mdを見直して」のように文書の見直しを頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/doc-review:doc-review`の後に必要ならファイルを続けて実行し、Codexでは`$`を入力して**Doc Review**を選びます。
ファイルを指定しない時は、`docs/SPEC.md`、`docs/DESIGN.md`、`docs/ARCHITECTURE.md`のうち最初にある物を使い、どれも無ければ`docs/`の下で最近変わったMarkdownのファイルを使います。どの文書か複数考えられる時は尋ねます。

1. スクリプトが形を確かめ、各文書の種類を推し量ります。仕様書、設計書、アーキテクチャ、決定の記録、README、その他のどれかです
2. 会話を引き継がない2人の見直し役が同時に文書を読みます。1人は中身を、もう1人は形を確かめ、重大、大きい、小さいの3段階で指摘を返します
3. エージェントが指摘を1つずつ確かめ、指摘された節を直すか、理由を添えて退けます
4. スクリプトがすべての指摘に判断があることを確かめて記録し、エージェントが何を変えたか、何を直さなかったかを伝えます

Codexでサブエージェントが使えない時は、エージェント自身が2つの観点を順に見直し、観点ごとにファイルを最初から読み直し、そのことを報告で伝えます。
見直しのフォルダはプロジェクトの外にあるので、Codexはそこへ書く命令の承認をあなたに求めます。

形を確かめると、次のような一覧が出ます。

```text
doc-review of 2 files in ~/work/shop
  docs/SPEC.md  kind spec
  docs/DESIGN.md  kind design

Form checks: 3 findings
  docs/SPEC.md:9  anchor  anchor #data-model not found in docs/DESIGN.md
  docs/SPEC.md:23  numbering  heading 4 follows 2
  docs/DESIGN.md:41  table  row has 3 cells, header has 2

Review: ~/.local/share/doc-review/shop-4d2849e3/20261112-194012
```

最後に、記録が見直しをまとめます。

```text
Recorded 7 findings for docs/SPEC.md, docs/DESIGN.md: critical 1, major 3, minor 3; fixed 6, not fixed 1
Not fixed:
  minor    form    docs/DESIGN.md line 41: The third cell is a planned column described in section 4
Record: ~/.local/share/doc-review/shop-4d2849e3/20261112-194012/review.md
```

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | 任意です。リポジトリの最上位のフォルダを調べます。このフォルダで、見直しのフォルダの名前を決め、出力のパスを短くし、`/`で始まるリンクを解きます。無い時は最初の文書のあるフォルダを使います |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、各検査の中身、見直し役が見る点、記録を載せています。
要点は次のとおりです。

- 見直す文書と、アンカーを確かめるために、そのリンクが指すMarkdownのファイルを読みます
- Pythonで`scripts/doc_review.py`を動かします。このスクリプトは、リポジトリの最上位のフォルダを調べるために`git rev-parse --show-toplevel`を動かします
- 2人の見直し役は同じ文書と、名前を確かめるのに要るリポジトリのファイルを読みます。見直し役には、読むだけにすることと、文書の文を指示ではなくデータとして扱うことを伝えます
- 見直した文書のうち、指摘された節だけをその場で書き換えるので、変えた所はすべて`git diff`で見られます
- スクリプトはWebのリンクを開かず、ネットワークにはつなぎません。見直し役はエージェントのセッションの一部なので、文書が届く先は、エージェントがすでに使っているモデルだけです
- 見直しごとに、`~/.local/share/doc-review/<project>-<ハッシュ>/`の下に見直しのフォルダを作ります。`DOC_REVIEW_HOME`を設定している時はその下です。あなただけが読め、消すまで残ります

## ライセンス

[MIT](LICENSE)
