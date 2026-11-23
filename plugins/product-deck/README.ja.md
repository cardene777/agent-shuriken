# Product Deck

製品を1つ紹介する資料を、実際の製品の画面から作ります。版面と文章は、あなたが見る前に機械で確かめます。

[English](README.md) · 日本語

紹介資料は、説明する人が隣に居ない状態で読まれます。
この技は製品そのものに絞り、何か、どんな課題に答えるか、どう使うか、何が違うかを書きます。会社の紹介と料金と問い合わせは持ちません。
先に画面を撮り、10面の基本から構成を決め、構成と文章をあなたに承認してもらってから、あなたのrepoに面を組みます。字は全部1つのデータのファイルに置くので、後から画面で直せます。

```
Take screenshots ──> Plan and text ──> You approve ──> Build the slides ──> Check to zero ──> Look full size ──> HTML, PDF, PowerPoint
 (Playwright)         (agent)           (chat)          (your repository)   (two scripts)     (agent)           (your repository)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install product-deck@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add product-deck@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install product-deck@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/product-deck/skills/product-deck   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

Claude Codeでは`/product-deck:product-deck`を実行し、Codexでは`$`を入力して**Product Deck**を選びます。
製品の紹介資料やサービスの紹介資料を頼んでも始まります。

```
Make an introduction deck for this product. The admin screen runs at http://localhost:4100
```

エージェントは、面を組む前に構成と文章の承認を会話で求め、ログインが要る画面ではURLか撮った画像を尋ねます。

### 自分の語の一覧を使う

文章の検査は、組み込みの規則をいつも回します。エージェントが資料の隣に書くその資料の語の表から、1つの物を別の語で呼んでいないかと、中核の語を意味を書く前に使っていないかを見て、日本語では人が物の動作をしていないかも見ます。
どの資料からも落とす自分の語を`~/.product-deck/prose-words.txt`に置くと、その一覧の種類ごとに検査が1つ増えます。一覧が無い時は、語の一覧が見つからないと出して、組み込みの規則だけを回します。
画面の置き方の見本は、`~/.product-deck/samples/`が在る時だけ読みます。
一覧の書き方は[仕組み](docs/how-it-works.ja.md#語の一覧)にあります。

### 自分の見た目を使う

repoの根に`.design-theme.json`が在るか、ホームのフォルダーに`~/.design-theme.json`が在る時、資料のどの型も、主の色、中立の色、書体、角をそこから取ります。
design-formatsのpage-designの技が読むのと同じ見た目のファイルなので、頁と資料が同じ見た目になります。product-deckは自分のスクリプトで読みます。
無い時は、エージェントが資料の主の色を1つ選びます。
資料が取るキーは[仕組み](docs/how-it-works.ja.md#見た目のファイル)にあります。

## 必要なもの

- スクリプトを動かすNode.js
- 画面を撮り、面を焼き、版面を検査するための、`@playwright/test`を入れたプロジェクト。`PLAYWRIGHT_FROM`で名指します
- ほかには要りません。落とす語の一覧と見た目のファイルは、在る時に読みます

## 読む物と動かす物と送る物

スクリプトとファイルは全て[仕組み](docs/how-it-works.ja.md)にあります。
要点は次のとおりです。

- `capture.mjs`は、あなたが渡したURLを画面の無いブラウザーで開き、撮った画像を資料のフォルダーに置きます
- エージェントは、あなたのrepoの`docs/decks/<name>/`に、構成、文章、面を組むファイル、焼いたHTMLとPDFとPowerPointを書きます
- `audit.mjs`、`shoot.mjs`、`render.mjs`は、資料のHTMLを画面の無いブラウザーで開きます。`audit-text.mjs`は、資料のデータと資料の語の表を読み、落とす語の一覧が在ればそれも読みます
- `theme.mjs`は、repoの根の`.design-theme.json`か、無ければホームのフォルダーのものを読み、資料が取るCSSの変数を出します
- スクリプトはPlaywrightを`PLAYWRIGHT_FROM`のフォルダーから取り、無い時は終わり方2で止まります
- プラグインはあなたのrepoの外に何も書かず、どこにも何も送りません。撮った頁は中身として扱い、指示としては扱いません

## ライセンス

[MIT](LICENSE)
