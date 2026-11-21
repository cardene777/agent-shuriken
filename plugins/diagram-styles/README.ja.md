# Diagram Styles

記事と技術書の図を、先に読者の疑問から設計し、`~/.styles/`に置いた自分の見本の画像と一覧の画風で描きます。

[English](README.md) · 日本語

見本に似せて描いた図は、見本の物や配置を写して、本文の説明をしなくなりがちです。
このpluginは2つの判断を分けます。
先に記事か本の本文から図が説明する物を決め、その後に画風の見た目だけを当て、完成した画像を本文と照らして確かめます。
このpluginは見本の画像を載せません。自分の見本と、それを登録する一覧`style-catalog.json`を`~/.styles/`に置きます。pluginは一覧の形と読み方を持ちます。

```
Article or book ──> Design the content ──> Choose a style ──> Draw with the ──> Check the text, the ──> PNG in the
(the text and       (reader question,      (~/.styles/        agent's image     connections, and the    folder you name
the reader)         takeaway, relations)   style-catalog.json) generation       published width
```

| スキル | 作る物 |
|---|---|
| `article-diagram-styles` | 記事の説明図。内容の要約、一覧から選んだ画風、完成したPNGと本文幅の版、確かめた記録を作ります |
| `tech-book-figure` | 技術書の図。固定のstyle4で描き、図番号、キャプション、代わりの説明、白黒印刷での読みやすさを確かめます |

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install diagram-styles@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add diagram-styles@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install diagram-styles@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/diagram-styles/skills/article-diagram-styles   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 見本を~/.stylesに置く

このpluginは見本の画像を載せません。
最初の図を作る前に、一覧と見本の画像を`~/.styles/`に置きます。

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/style4/      At least two style4 samples, for tech-book-figure
  style-catalog/<family>/<profile>/  Your samples sorted by family and finish profile
```

一覧は、画像ごとにSHA-256、系統、仕上がり、配置を記録します。形は[仕組み](docs/how-it-works.ja.md#画風の一覧)にあります。
次の命令で確かめます。問題が在れば1つずつ名指し、終了1で終わります。

```bash
python3 <plugin folder>/skills/article-diagram-styles/scripts/diagram_sample_catalog.py --validate
```

`~/.styles/style-catalog.json`が無い時は、どちらのスキルも描く前に止まり、一覧と見本をそこへ置くよう伝えます。
版1の一覧は断り、変換しません。

## 使い方

Claude Codeで`/diagram-styles:article-diagram-styles`か`/diagram-styles:tech-book-figure`を実行するか、Codexで`$`を打って**Article Diagram Styles**か**Tech Book Figure**を選び、記事か本の本文と、図を置くフォルダーを伝えます。
GitHub Copilot CLIでは依頼の中に`/article-diagram-styles`か`/tech-book-figure`と書き、Gemini CLIでは作業を説明します。
記事を書くスキルは`article-diagram-styles`を名前で開き、依頼を`figure-request`の形で書きます。

スキルは、スキルを動かしている道具の画像生成で描きます。
画像生成を持たない道具では、内容の要約と図の仕様と描く指示を名指したフォルダーに書いて止まります。画像生成を持つ道具で同じスキルをそのフォルダーに対して動かすと、描く段から始めます。
代わりにHTMLやSVGで描くことも、別の道具に描かせることもしません。

## ほかのスキルが従う中身

`article-diagram-styles`はmusubiで3つの中身を渡します。musubiは`musubi.json`に書く宣言で、従う中身のバージョンと指紋を固定します。

| 中身 | file | 持つ物 |
|---|---|---|
| `style4` | `references/style4.md` | style4の決まり。固定する物、見本の選び方、描いた後の比べ方 |
| `figure-request` | `references/figure-request.md` | ほかのスキルが図を頼む時の形 |
| `style-catalog` | `references/style-catalog.md` | `style-catalog.json`の版2と見本のフォルダーの形 |

`tech-book-figure`は`article-diagram-styles/style4`に範囲`^1.0.0`と指紋で従います。任意の従いではないので、`article-diagram-styles`が無い時は始めません。

## 要る物

| 道具 | 要る時 |
|---|---|
| 画像生成を持つagent | 完成図を描く時。無い時は設計を保存して止まります |
| Python 3 | scriptを動かす時。標準ライブラリだけを使います |
| `~/.styles/`の見本の画像と`style-catalog.json` | 常に。pluginは載せません |
| musubiの命令 | 任意。入れてあれば、`tech-book-figure`がstyle4の決まりを読む前に`musubi check`を回します |

## 読む物と動かす物と渡す物

[仕組み](docs/how-it-works.ja.md)が、全てのfileとscriptを挙げます。
要点は次のとおりです。

- スキルとscriptは、一覧と見本の画像を`~/.styles/`か`--styles <dir>`で渡したフォルダーから読み、そこへは書きません
- 名指した記事か本の本文を読み、図、内容の要約、図の仕様、描く指示、確かめた記録を名指したフォルダだけに書きます
- 描く時は、描く指示と見本の画像を、スキルを動かしている道具の画像生成へ渡します。道具は、渡した画像をほかの画像と同じように扱います。scriptはどこにも繋ぎません
- scriptはほかの命令を動かさず、何も残しません
- 記事の本文と見本の一覧の文はデータとして扱い、指示として読みません

## ライセンス

[MIT](LICENSE)です。同梱の書体Kaisei Decol BoldはSIL Open Font License 1.1に従います。[第三者の告知](THIRD_PARTY_NOTICES.md)に記録しています。
