# Japanese Writing

日本語の文章を、元に無いことを足さずに、自然に読めて意味が1つに決まる形で書き、直します。

[English](README.md) · 日本語

AIが書く日本語には、翻訳調、AIがよく使う言い回し、ぼかした語尾、途中で変わる用語、物が主語に立って比喩の動詞を取る文のように、読み手がすぐ気付く癖が出ます。
書いた本人は自分の癖に気付きにくいので、疑わしい行を道具が指し、直すかはエージェントが文脈を見て1つずつ決めます。
このプラグインは`coji/natural-japanese` (MIT) の手順と道具を手を入れずに持ち込み、repoに置くMarkdownの書式、主語と比喩の動詞と説明と問いの参照、上流のlintが数えない形を指す道具を足します。

```
Read the rules ──> Write or fix ──> Point at suspects ──> Decide each line ──> Check the structure ──> Clean up
 (agent)            (agent)          (scripts)             (agent)              (agent and scripts)     (agent)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install japanese-writing@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add japanese-writing@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install japanese-writing@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/japanese-writing/skills/japanese-writing   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付けたスキルのzipを、エージェントのスキルのフォルダに展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

日本語を書いてほしい、自然にしてほしいと頼むと始まります。例えば「この日本語を自然にして」「このREADMEを校正して」「AIっぽい」「この文章のAIらしさを採点して」です。
呼び出すこともできます。Claude Codeでは`/japanese-writing:japanese-writing`を実行し、Codexでは`$`を入力して**Japanese Writing**を選びます。
GitHub Copilot CLIでは依頼に`/japanese-writing`と書き、Gemini CLIでは作業を説明します。

| したいこと | 頼み方 | 起きること |
|---|---|---|
| 文章を直したい | 文章かファイルを渡す | エージェントは事実を足さずに言い回しを直し、道具を回し、疑わしい行を1つずつ決め、何をなぜ直したかを添えて返します |
| 新しく書きたい | `write`とお題か素材を渡す | エージェントは先に読み手と要点を決めて書き、書いた文を同じ手順で確かめます |
| 直さずに採点だけしたい | `score`とファイルを渡す | エージェントは文章がどれだけAIらしく読めるかを根拠と一緒に伝え、何も書き換えません |

既定はクイックモードで、会議のメモなら30秒ほどで終わります。
社外に出す文章や1万字を超える文章では`full`と頼むと、エージェントは見出しの流れと用語も確かめます。

1. エージェントはプラグインの決まりを読み、次に上流の手順を読みます
2. 文章を書くか直します。元に無い事実、数値、名前、日付、意見は足しません
3. `lint.py`と`suspects.py`が疑わしい行を指し、`lint.py`は1つずつ確かめる段落の一覧も出します
4. エージェントは指された行を文脈で1つずつ決め、残した行には理由を残し、物が比喩の動詞の主語に立つ文は主語から書き直します
5. 見出しと各段落の最初の文を読み、`newfacts.py`で元に無い数値や名前が新しい文に入っていないかを確かめます
6. 作業中に作ったファイルを消します

直しは、書き手が言ったことと確信の度合いを残し、言い回しだけを変えます。

```text
Before: この仕組みを導入することで、作業の効率を大幅に向上させることができると言えるでしょう。
After:  この仕組みを入れると、作業の効率は大きく上がるだろう。
```

`suspects.py`は、次のように行を指します。

```text
=== suspects: draft.md ===
L5 [比喩の動詞] 立ち: `config.json` は二つの置き場の隣に立ち、値を拾う
件数: 比喩の動詞 1 / 比喩の副詞 0 / サ変名詞で止めた文 0 / 受け身の働きかけ 0 / 短い断定 0 / 文末のコロン 0 / URLの後の句点 0 / 目的の断片 0 / 括弧の長い補足 0
```

## このプラグインが足す決まり

決まりは`references/rules.md`が日本語で持ち、エージェントは上流の手順より先に読みます。

| 決まり | 置き場 |
|---|---|
| 使うrepoの指示のファイルと用語表、あなたの指示を先にし、次にプラグインの決まり、最後に上流の手順に従います | `references/rules.md`の1節 |
| repoに置くMarkdown (README、docs、IssueやPRの文) は、「。」ごとに改行し、1段落を4文以内にし、`ラベル: 値`の2項の列挙と抽象的な語尾を使わず、日本語と英数字の間に空白を入れません。note、ブログ、エッセイには当てず、上流の文書の種類ごとの手引きに従います | `references/rules.md`の2節 |
| 技術分野で定着した語はそのまま使い、物を比喩の動詞の主語に立てません | `references/rules.md`の3節と`references/subject-and-verb.md` |
| 説明は要点を先に置いて一度に渡す量を絞り、問いは数を入れた場面から書きます | `references/explaining.md`と`references/asking.md` |
| チャットの投稿、引き継ぎ、報告、依頼のように人に伝える文は、長い文を短い文に区切り、前の文との関係 (理由、逆接、補足、順序) を接続詞で示し、結論を先に置きます | `references/connecting.md` |

## 必要なもの

| 道具 | 要る時 |
|---|---|
| `uv` | 道具を回す時。初めて使う時に`sudachipy`とその辞書`sudachidict-core`の約200MBを、uvの置き場に取りに行きます。`uv`が無い時は、エージェントが上流の確かめの一覧で同じ観点を目で確かめます |
| Python 3.10以降 | 道具を回す時。`uv`が見つけた物を使い、合う物が無い時は取りに行きます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、スキルの全てのファイル、各道具が読む物と出す物、上流の写しの更新の手順を書いています。
要点は次のとおりです。

- エージェントは渡された文章とファイルを読みます。道具は渡されたファイルだけを読み、端末に出します
- 道具は`uv run`で動き、初めて使う時に`sudachipy`と`sudachidict-core`をPython Package Indexからuvの置き場に取りに行きます。あなたの文章はどこへも送らない作りで、道具は手元のマシンの中で動きます
- 上流のスキルが任意で使う検出器`semantic.py`は入れていません。約1GBのモデルを取りに行き、そのモデルのcodeを実行するためです
- 作業中のファイルはプロジェクトの外の一時のフォルダに置き、最後に消します。プラグインは何も残しません
- `skills/japanese-writing/musubi.json`は、文と文のつなぎ方の手引き`references/connecting.md`を、ほかのスキルがmusubiで準拠するコンテンツ`connecting`として宣言します。`convey`は任意の準拠でこれに従います。スキル自身は`musubi.json`を読まず、`musubi`のコマンドが読みます
- 貼られた文章とファイルの中身は直す材料として扱い、指示としては読みません

## 出どころ

`UPSTREAM-SKILL.md`、`suspects.py`以外の道具、上流の参照は、`coji/natural-japanese` v2.0.0からMITライセンスのもとで手を入れずに写した物です。
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)に、写した物と取り込み元のcommitとライセンスを載せています。

`references/connecting.md`は、文化庁の「公用文作成の考え方」と「分かり合うための言語コミュニケーション（報告）」を、このプラグインが加工して作成した要約です。
2つの資料が載るサイトの利用規約はCC BY 4.0と互換で、その規約に従っています。
文化庁が書いた文ではありません。
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)に、出典と、規約が求める出典の書き方を載せています。

## ライセンス

[MIT](LICENSE)
