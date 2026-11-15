# Skill Tune

プラグインのスキルがエージェントに何をさせるかを測り、`SKILL.md`を短くし、同じ評価の案件でどの案件も悪くなっていないことを示します。

[English](README.md) · 日本語

`SKILL.md`はスキルの手順が増えるたびに長くなり、エージェントはスキルが始まるたびにその全文を読みます。
その多くは、スキルのスクリプトが自分で出す内容や見出しが既に示す内容の言い直しです。ただ、感覚で削るとエージェントが必要としていた1文まで落としかねません。
このプラグインは、エージェントにプラグインの中へ`claude plugin eval`の案件を書かせ、変える前のスキルを測り、あなたが同意した分だけを削り、もう一度測ります。
スクリプトは、プラグインの非公開の写しに対して評価を走らせ、スキルが動いたことを示すだけの判定を除いて案件ごとに点を出し、各案件を同じ、上がった、下がったに分けて並べます。

```
スキルを読む ──> 案件と削る所を決める ──> 案件を書く ──> 見込みを出す ──> 基準を取る ──> 短くする ──> 比べる
 (エージェント)   (あなたが選ぶ)           (エージェント) (あなたが許す)  (スクリプト)   (エージェント) (スクリプト)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install skill-tune@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add skill-tune@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install skill-tune@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/skill-tune/skills/skill-tune   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「このプラグインのスキルを評価で測ってSKILL.mdを短くして」「この評価の案件はなぜ落ちるの」「このrepoで長いスキルはどれ」のように、スキルを測る、短くすると頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/skill-tune:skill-tune`を実行し、Codexでは`$`を入力して**Skill Tune**を選びます。
GitHub Copilot CLIでは依頼の中に`/skill-tune`と書き、Gemini CLIではやりたいことを伝えます。

| したいこと | 起きること |
|---|---|
| スキルを測って短くする | 下の手順すべて |
| 評価の案件だけを作る | 手順1から5まで。削る所は扱いません |
| 案件が落ちる理由を知る | エージェントが落ちた実行のツール呼び出しを読み、原因を挙げます |
| repoの中の長いスキルを知る | すべてのスキルを長さ順に並べた表を評価の案件の数とともに出し、そのうち1つから始めるかを尋ねます |

1. エージェントが`SKILL.md`を測り、スクリプトや見出しや`--help`が既に言っている内容の言い直しを、削ると減る語数とともに挙げます
2. あなたが案件のまとまりと削る所を選びます。エージェントは1回の実行の費用を伝えます
3. エージェントがプラグインの`evals/`フォルダに案件を書きます。各案件には始まりの状態を作る`fixture.sh`が付きます。案件を確かめる検査もプラグインのテストに足します
4. スクリプトがプラグインを写し、各案件を1回ずつ走らせます。サンドボックスで通せない案件は、測るのにお金を使う前に直します
5. その実行から、スクリプトが測る費用の見込みを出します。エージェントがそれを見せ、スクリプトが新しい写しで基準を取ります
6. エージェントが`SKILL.md`で同意した所だけを削り、その大きさの上限をプラグインのテストに書きます
7. スクリプトが新しい`SKILL.md`の写しを測り、案件ごとに比べます。点が下がった案件は実行ごとに読み、何かを変える前に原因を挙げます
8. エージェントが各案件の変える前と後とプラグイン無しの点を費用とともに報告し、写しと評価が残したフォルダを消します

Claude Code以外のエージェントでは、`claude plugin eval`がClaude Codeに付いてくるため、スキルは手順1から3までを行って止まります。

何も悪くならなかった比較は次のようになります。

```text
outline-first  before 1.00  after 1.00  kept
build-from-outline  before 1.00  after 1.00  kept
fix-missing-figure  before 0.83  after 1.00  higher
unrelated-request  before 1.00  after 1.00  kept
before: runs where the skill fired: 9, average 0.442 USD, 96 s, 14.2 turns
after: runs where the skill fired: 9, average 0.431 USD, 92 s, 13.6 turns
```

## 点の付け方

各案件はプラグインありで3回、基準ではプラグイン無しでも3回走ります。
スクリプトが出す行のように、スキルが動いたことを示すだけの判定は、案件で`with-only`と印を付けるか`--indicator`で名指し、点に数えません。
1回の実行の点はそれ以外の判定のうち通った割合で、案件の点はその実行の平均です。

| 状態 | 意味 |
|---|---|
| `kept` | 変える前と後で点が同じです |
| `higher` | 変えた後のほうが点が高いです |
| `lower` | 変えた後のほうが点が低いです。`compare`は1で終わり、エージェントが両側の実行を読みます |
| `not measured` | 片側に点の付いた実行がありません。`compare`は3で終わります |

## 必要なもの

| ツール | 要る時 |
|---|---|
| `python3` | いつも。バージョン3.9以降 |
| Claude Code | 測る時。`claude plugin eval`が付いてきます。実行の費用を払うアカウントでサインインしておきます。案件を書くのはどのエージェントでもできます |

## 読む物、実行する物、送る物

[しくみ](docs/how-it-works.ja.md)に、スクリプトのコマンド、結果の点の付け方、データのフォルダに置く物を書いています。
要点は次のとおりです。

- エージェントは指定したプラグインを読み、スクリプトはその`SKILL.md`、`evals/`フォルダ、評価の結果、評価が残す記録を読みます
- 評価の案件と同意した削りはそのプラグインの中にだけ書き、写しと結果は`~/.local/share/skill-tune/`に、あなただけが読める形で置きます
- `claude plugin eval`は案件にあなたが同意した後にだけ走らせ、測る前に費用の見込みを見せます。`--max-cost-usd`は、あなたが上限を言った時だけ渡します。各案件の`fixture.sh`はあなたの権限で走るので、自分で書いたか信頼するプラグインにだけ使います
- スクリプト自身は何も送りません。`claude plugin eval`が各案件の依頼文と実行中にエージェントが読む物を、あなた自身のClaude Codeのサインインを通してAnthropicのモデルへ送り、費用はあなたのアカウントに請求されます。結果は公開しません
- 終わる時に、写しとその結果と評価が残したフォルダを消します

## ライセンス

[MIT](LICENSE)
