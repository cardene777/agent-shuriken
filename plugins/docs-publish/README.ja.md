# Docs Publish

オープンソースのプロジェクトの公開ドキュメントを、英語とあなたが選ぶもう1つの言語で、5つの部に分けて書きます。すべての翻訳とすべてのリンクを確かめます。

[English](README.md) · 日本語

オープンソースのプロジェクトの良いドキュメントには、すぐに動かす手順、考え方の説明、リファレンス、作業ごとの例、よくある質問への答えがそろっています。ほかの言語の読み手には、同じページがその言語で要ります。
手で保つと、2つの言語はずれていきます。片方の言語にだけページが増え、翻訳は元のページに遅れ、ファイルを動かすとリンクが切れます。
このプラグインは、あなたのプロジェクトのコードと例をもとに、エージェントにページを書かせます。5つの部に分け、英語と、日本語のようなもう1つの言語で、言語ごとに1ページ1ファイルで書きます。
スクリプトがフォルダを並べ、翻訳の対応表を保ち、すべてのページとリンクを確かめるので、2つの言語がそろったまま保てます。

```
プロジェクトを読む ──> 計画を決める ──> 並べて書く ──> 翻訳する ──> 全ページを確かめる
 (エージェント)       (あなたが承認)   (スクリプト、エージェント) (エージェント) (スクリプト)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install docs-publish@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add docs-publish@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install docs-publish@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/docs-publish/skills/docs-publish   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「このライブラリのドキュメントを英語と日本語で書いて」「ドキュメントを日本語に訳して、そろったまま保って」のように、ドキュメントを頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/docs-publish:docs-publish`を実行し、Codexでは`$`を入力して**Docs Publish**を選びます。
GitHub Copilot CLIでは依頼の中に`/docs-publish`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントがプロジェクトを読みます。README、パッケージの定義ファイル、公開しているAPI、例、テスト、今あるドキュメントです
2. 兄弟のライブラリのように、あなたのドキュメントが倣うプロジェクトを名指して同意すれば、エージェントがそれぞれの目次と5ページまでを読み、形だけを取り入れます
3. エージェントが、もう1つの言語、ドキュメントのフォルダ、ページを提案します。考え方のページを3から5つ、関数やクラスやコマンドごとにAPIのページを1つ、作業ごとにCookbookのページを1つです。あなたが確かめるか、変えます
4. スクリプトがフォルダと書き始めのページを並べ、エージェントが元の言語(ふつうは英語)で各ページを書きます
5. エージェントがすべてのページをもう1つの言語に訳し、スクリプトが訳したことを記録します
6. スクリプトがすべてのページとリンクを確かめ、エージェントが指摘を直して、残りが無くなるまで繰り返します
7. あなたが同意すれば、エージェントがREADMEからドキュメントへリンクを張ります。何もコミットしないので、先に新しいファイルを見直せます

作業が残っている間、確かめた結果は次のようになります。

```text
docs: 11 pages in en, ja, translated from en

stale        en/concepts/checkout.md changed after ja/concepts/checkout.md was translated from it
link         ja/cookbook/apply-a-coupon.md:43: ../api/applycoupon.md differs in letter case from the file on disk, so it breaks on GitHub and most web servers
crosslink    ja/faq.md:15: ../en/quickstart.md points into en/; link the page in ja/ instead
orphan       ja/faq.md cannot be reached by following links from ja/README.md

4 problems. Links: 85 checked, 1 broken.
```

ドキュメントが仕上がると、次のようになります。

```text
docs: 11 pages in en, ja, translated from en
No problems. Links: 86 checked, 0 broken.
```

## ページの並び

言語ごとにフォルダを1つ持ち、同じページを同じパスに置きます。あるページとその翻訳は、いつでもすぐに見つかります。

```text
docs/
├── _translation-map.json
├── en/
│   ├── README.md                 目次。プロジェクトが何かと、5つの部
│   ├── quickstart.md             何も無い状態から最初に動くまで
│   ├── concepts/                 README.mdと、考え方ごとに図を入れた1ページ
│   ├── api/                      README.mdと、関数、クラス、コマンドごとに1ページ
│   ├── cookbook/                 README.mdと、作業ごとに1ページ
│   └── faq.md                    よくある質問とエラー
└── ja/                           同じページの翻訳
```

各ページは、題名の下の行に、もう1つの言語の同じページへのリンクを持ちます。
`_translation-map.json`は、言語(元の言語が先)とページの一覧です。
翻訳ごとに、記録した時点の元のページのsha256を保つので、あとで元のページが変わると確かめる時に気付きます。

完成したCookbookのページは、次のようになります。架空のライブラリAcme Shopの`docs/ja/cookbook/apply-a-coupon.md`です。
英語の元のページ`docs/en/cookbook/apply-a-coupon.md`も、同じ見出し、一覧、コードブロックを持ちます。

````markdown
# クーポンを使う

[English](../../en/cookbook/apply-a-coupon.md) · 日本語

会計の時にクーポンのコードを受け取り、お客さんが支払う前にカートの合計を下げます。
値引きは、注文を確定するまでカートに残ります。

## 始める前に

- [Quickstart](../quickstart.md)のとおりにAcme Shopを入れてある
- [`createCart`](../api/createCart.md)でカートを作ってある

## 手順

1. コードをカートに当てます。

   ```ts
   import { applyCoupon } from "acme-shop";

   const result = await applyCoupon(cart, "SPRING10");
   ```

2. コードを使えない時は、お客さんに伝えます。

   ```ts
   if (!result.ok) {
     showError(result.reason); // "expired"、"unknown"、"minimum-not-met" のどれか
   }
   ```

## 結果を確かめる

```ts
console.log(cart.total, cart.discounts);
```

```text
4500 [ { code: 'SPRING10', amount: 500 } ]
```

## 関連

- [`applyCoupon`](../api/applyCoupon.md)
- [`createCart`](../api/createCart.md)
- [Cookbook](README.md)
````

## 確かめること

| 確かめること | 見つけるもの |
|---|---|
| 対になるページ | 片方の言語に無いページと、対応表に無いページのファイル |
| やることの印 | 書き始めのページのうち、まだ書いていない節 |
| 中身 | Mermaidの図が無い考え方のページと、コードの例が無いQuickstart、API、Cookbookのページ |
| 構成 | 見出し、コードブロック、表の行が元のページと違う翻訳 |
| 新しさ | 一度も記録していない翻訳と、記録した後に元のページが変わった翻訳 |
| リンク | 何も指していない相対リンクと画像、ファイルと大文字小文字が違うリンク。各ページのフォルダから解決し、コードの中はリンクとして読みません |
| 言語 | 言語の切り替え以外で、もう1つの言語のフォルダを指すリンクと、対になるページへのリンクが無いページ |
| たどり着けるか | その言語の目次からリンクをたどっても、たどり着けないページ |

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に。3.9以降 |
| `gh` | FAQの材料にプロジェクトのIssueを読む時だけ、GitHubにサインインした状態で、あなたが同意した時に使います。無くてもほかはすべて動きます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、計画、対応表、それぞれの確かめ方、スクリプトのコマンドを載せています。
要点は次のとおりです。

- エージェントは、ページを書くためにプロジェクトのファイル(README、ソースコード、例、今あるドキュメント)を読みます。スクリプトが読むのはドキュメントのフォルダだけです
- 書くのはドキュメントのフォルダの中だけです。READMEへのリンクは、あなたが同意した時だけ足します。ファイルを上書き、移動、削除することはありません
- 自分のPythonのスクリプトを動かします。QuickstartとCookbookのコマンドは、新しく何もインストールせずに動く時だけ、本当の出力を見せるために動かします。何かをインストールする前には尋ねます
- あなたが同意すれば、プロジェクトに対して`gh issue list`と`gh issue view`を動かします。あなた自身の`gh`のサインインで、リポジトリの名前をGitHubに送ります
- あなたが名指したプロジェクトのドキュメントは、あなたが同意した時だけ読みます。それぞれの目次と5ページまでを、GitHubのリポジトリなら`gh api`で、あなた自身の`gh`のサインインでその名前をGitHubに送って読み、ほかのサイトならエージェントのWebページを読む道具で読みます。取り入れるのは形だけで、文は写さず、プロジェクトの名前、アドレス、倣った所を翻訳の対応表に残します
- プロジェクトの外には何も残しません。ページと翻訳の対応表は、消すまでドキュメントのフォルダに残ります

## ライセンス

[MIT](LICENSE)
