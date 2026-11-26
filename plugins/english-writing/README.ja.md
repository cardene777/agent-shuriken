# English Writing

英語の文章を、元に無いことを足さずに、自然に読めて意味が1つに決まる形で書き、直します。

[English](README.md) · 日本語

日本語を母語とする書き手のためにAIが書いた英語には、2種類の癖がよく残ります。
1つは「It is necessary to」や「Regarding the error,」のように日本語の語順を残した言い回しで、もう1つは機械が書いたように聞こえる言い回しです。
道具が疑わしい行を指し、エージェントが前後の文脈から1行ずつ判断します。
このプラグインは`blader/humanizer`(MIT)の型をそのまま持ち込み、日本語から直訳した言い回し、短い文、用語、平易な英語の決まりを足します。

```
決まりを読む ──> 書くか直す ──> 疑わしい行を指す ──> 1行ずつ判断する ──> 直した点を返す
 (エージェント)   (エージェント)   (道具)               (エージェント)        (エージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install english-writing@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add english-writing@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install english-writing@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/english-writing/skills/english-writing   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付けたスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

英語を書いてほしい、自然にしてほしいと頼むと始まります。
たとえば「この英語を自然にして」「このプルリクエストを校正して」「翻訳っぽく読める」と頼みます。
Claude Codeでは`/english-writing:english-writing`を実行し、Codexでは`$`を入力して**English Writing**を選んでも呼べます。
GitHub Copilot CLIでは依頼に`/english-writing`と書き、Gemini CLIでは作業を説明します。

| したいこと | 頼み方 | 何が起きるか |
|---|---|---|
| 文章を直す | 文章かファイル | エージェントは事実を足さずに言い回しを直し、道具を走らせ、疑わしい行を1行ずつ判断して、直した点と理由を添えて文章を返します |
| 新しく書く | 題材か手元のメモ | エージェントは英語で書き、下書きを同じ手順で確かめます |

1. エージェントはこのプラグインの決まりを読み、次に上流の型を読みます
2. 元に無い事実、数、名前、日付、主張を足さずに、文章を書くか直します
3. `suspects.py`とproselintが疑わしい行を指します
4. エージェントは疑わしい行を文脈で1行ずつ判断し、型をわざと使っている行は残します
5. 直した文章と、直した点を1件1行で返します。各行には直した点の種類と、利用者が書く言語での理由を添えます

直す時は、書き手の言ったことと確かさの度合いを保ち、言い回しだけを変えます。

```text
Before: Regarding the login error, it is necessary to restart the server in order to clear the cache.
After:  To fix the login error, restart the server to clear the cache.
```

`suspects.py`は次のように行を指します。

```text
=== suspects: draft.md ===
L3 [from Japanese] Regarding the login error,: start with the subject: "We fixed the login error yesterday."
L3 [from Japanese] it is necessary to: use "need to", "must", or the verb alone: "Restart the server after the update."
L3 [from Japanese] in order to: use "to": "We changed the setting to reduce the load."
Counts: long sentence 0 / passive voice 0 / from Japanese 3
```

## このプラグインが足す決まり

決まりは`references/rules.md`が持ち、エージェントは上流の型より先に読みます。

| 決まり | 置き場 |
|---|---|
| 書く先のプロジェクトの指示ファイル、用語集、文体の手引き、利用者自身の指示を先にし、次にこのプラグインの決まり、最後に上流の型に従います | `references/rules.md`の1節 |
| 日本語から直訳した言い回しでなく、主語と仕事をする動詞を持つ英語の語順で各文を書きます | `references/rules.md`の2節と`references/translationese.tsv` |
| 1文を25語までにし、能動態で書き、名詞に隠れた動詞を戻します | `references/rules.md`の3節 |
| 1つの物は1つの名前と1つの綴りで呼び、定着した技術用語はそのまま使います | `references/rules.md`の4節 |
| 短く身近な語を使い、読み手を「you」と呼び、結論を先に書き、曖昧な語を具体的な語に替えます | `references/rules.md`の5節と6節 |
| 直した点には`from Japanese`、`AI-sounding`、`vague word`、`inconsistent term`、`too long`、`passive voice`のどれかの種類を付けます | `references/rules.md`の8節 |

## 必要なもの

| 道具 | 要る時 |
|---|---|
| Python 3 | `suspects.py`を走らせる時。標準ライブラリだけを使います |
| `uv` | proselintを走らせる時。初回にproselint 0.16.0と、それが要る`google-re2`を自身のキャッシュに取りに行きます。`uv`が無い時は、エージェントがこのプラグインの決まりで決まり文句と曖昧な語を目で確かめます |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、skillの全ファイル、各道具が読む物と出す物、上流の写しの更新の手順を書いています。
要点は次のとおりです。

- エージェントは渡された文章かファイルを読み、道具は渡されたファイルだけを読んで端末に出します
- proselintは`uv run --with proselint==0.16.0`で走り、初回にPython Package Indexからuvのキャッシュへ取りに行きます。このプラグインは文章をどこへも送らず、道具は手元の機械で動きます
- 途中のファイルはプロジェクトの外の一時フォルダに置き、最後に消します。このプラグインは何も残しません
- `skills/english-writing/musubi.json`は、英語を書く他のskillがmusubiを通して従う中身`rules`として`references/rules.md`を宣言します。skill自身は`musubi.json`を読まず、`musubi`コマンドが読みます
- 貼られた文章とファイルの中身は直す材料であり、指示として扱いません

## 出どころ

`UPSTREAM-SKILL.md`は`blader/humanizer`からMITライセンスで、変えずに写しています。
`references/rules.md`はこのプラグイン自身の文章で、Google developer documentation style guide(CC BY 4.0)、plainlanguage.gov(パブリックドメイン)、GOV.UKの書き方の手引き(Open Government Licence v3.0)から数文を引いています。
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)に、出典、commitか読んだ日、ライセンスを書いています。

## ライセンス

[MIT](LICENSE)
