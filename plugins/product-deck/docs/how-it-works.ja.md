# 仕組み

[English](how-it-works.md) · 日本語

プラグインは技`product-deck`を1つだけ持ちます。
エージェントは`skills/product-deck/SKILL.md`に従い、あなたのrepoに資料のファイルを書き、`skills/product-deck/scripts/`のスクリプトをNode.jsで動かします。

## 技のファイル

| ファイル | 中身 |
|---|---|
| `SKILL.md` | 画面を撮る、構成を立てる、書く、承認を受ける、組む、焼く、検査する、見る、画面で直せるようにする、配る形を焼く、の手順 |
| `references/deck-structure.md` | 10面の基本、紹介資料が持たない面、版面の規律 |
| `references/layout-rules.md` | 版面の決まり。決まりごとに、それを見る検査か「目で見る」を添えます |
| `references/writing-rules.md` | 文章の決まり。決まりごとに、それを見る検査か「目で見る」を添えます |
| `references/banned-words.txt` | 面に出してはいけない語。`--words`で別の一覧を渡さない限り`audit.mjs`が読みます |
| `scripts/capture.mjs` | 1つの頁の画面を撮ります |
| `scripts/audit.mjs` | 焼いた面を検査します |
| `scripts/audit-text.mjs` | 資料のデータから文章を検査します |
| `scripts/shoot.mjs`、`scripts/render.mjs` | 面を1920x1080のPNGに焼きます |
| `scripts/glyph-fit.mjs` | 記号が入れ物に収まるかを測ります |
| `scripts/load-playwright.mjs` | ブラウザーを動かすスクリプトのためにPlaywrightを解きます |

## Playwright

プラグインは`node_modules`を持ちません。
ブラウザーを動かすスクリプトはどれも`load-playwright.mjs`を読み込み、`@playwright/test`を`PLAYWRIGHT_FROM`のフォルダーから、変数が無ければスクリプト自身のフォルダーから解きます。
どちらにも無い時は、`PLAYWRIGHT_FROM`の値を添えてPlaywrightが見つからないと出し、頁を開く前とファイルを書く前に終わり方2で止まります。

## 資料のファイル

エージェントはあなたのrepoの`docs/decks/<name>/`に書きます。

| ファイル | 中身 |
|---|---|
| `plan.md` | 構成。面ごとに1行で、主張、画面、図の有無を持ちます |
| `content.md` | 面ごとの文章。あなたの承認を受けます |
| `assets/` | 撮った画面 |
| `build/deck-data.mjs` | 面に出る字の全て。`export const faces = [...]`で、面ごとに1つのobjectです |
| `build/deck-faces*.mjs`、`build/deck-styles.mjs`、`build/deck-base-css.mjs`、`build/render.mjs` | 面の組み方。字を持ちません |
| `build/build-deck.mjs`、`build/build-decks.mjs` | 配るHTMLと、型を見比べる閲覧用を焼きます。どちらも検査を回します |
| `build/build-slide-edit.mjs`、`build/apply-edits.mjs` | 面の上で字を直す画面と、直した分を`deck-data.mjs`へ書き戻す道具 |
| `build/build-pdf.mjs`、`build/build-pptx.mjs` | PDFとPowerPointを焼きます |
| `build/writing-terms.txt` | 文章の検査が読む、その資料の語の表 |

## 検査

| 検査 | 読む物 | 終わり方 |
|---|---|---|
| `audit.mjs <viewer HTML> <style>...` | 焼いた面。画面の無いブラウザーで開きます | 引っかかった面が無ければ0、在れば1、型を開けないか検査が何も数えなければ2 |
| `audit-text.mjs <deck-data.mjs>` | 資料のデータと2つの語の一覧 | 引っかかった面が無ければ0、在れば1、一覧が無いか検査が何も数えなければ2 |

どちらの検査も何件を見たかを出します。「引っかかった0面」と、何も見なかった検査を読み分けるためで、数えた件数が0なら終わり方2で止まります。

## 語の一覧

`audit-text.mjs`は2つの一覧を読みます。どちらもプラグインには含みません。

| 一覧 | 読む所 | 無い時 |
|---|---|---|
| 落とす語 | `--prose-words <path>`、無ければ`~/.product-deck/prose-words.txt` | 検査を回さず、読みに行った置き場を名指して終わり方2で止まります |
| 資料の語の表 | `--terms <path>`、無ければ`~/.product-deck/writing-terms.txt` | 検査を回さず、読みに行った置き場を名指して終わり方2で止まります |

ホームのフォルダーはNode.jsの`os.homedir()`で解きます。

### 落とす語

1行に1語で、種類、語、代わりに書く語を空白で区切ります。`#`で始まる行は注記です。

```
# kind  word  instead
wordy  utilize  use
wordy  leverage  use
unknown  idempotent  safe-to-repeat
bare-english  workflow  steps
allow  API  keep
```

| 種類 | 当て方 |
|---|---|
| `bare-english` | 語の境目で切り、大文字と小文字を区別しません |
| `allow` | 落とす語ではなく、その語を`bare-english`から外します。3列目もやはり要ります |
| ほかの名前 | 部分一致で当てます。名前がそのまま検査の名前になります |

どの種類にも1語以上が要り、無ければ検査は終わり方2で止まります。

### 資料の語の表

1行に1つで、種類から書き始めます。

```
synonym  record  entry  log
synonym  agent  bot
except  record  history
core  record  3
core  policy  4
allow  smart contract
```

| 種類 | 形 | 意味 |
|---|---|---|
| `synonym` | `synonym <word decided> <word that mixes in>...` | 混ざる語を出しません。決めた語がその物を呼びます |
| `except` | `except <word decided> <form>...` | 挙げた形を含む文では、その語を検査しません。製品の画面の見出しを写す時などに使います |
| `core` | `core <word> <slide number>` | その語を、意味を書いた面より前に出しません |
| `allow` | `allow <phrase>` | 落とす語を含んでいても残す言い方 |

表には`synonym`と`core`の行が1つずつ以上要り、無ければ検査は終わり方2で止まります。

日本語の資料では、種類を日本語の名前のまま書けます。名前は`scripts/audit-text.mjs`が並べています。

## 見本

`~/.product-deck/samples/`が在る時、エージェントはその中を並べ、画面を置く前に画像を見ます。
プラグインは見本の画像を持ちません。

## 書く物と残す物

プラグインが書くのは、あなたのrepoの資料のファイルだけです。
`~/.product-deck/`はあなたが保つ物で何も書かず、どこにも何も送りません。
