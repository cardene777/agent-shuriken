# Convey

人に伝える文を、結論を先に置き、読み手に要らないことを入れずに書き、Slack、Discord、メール、GitHubのcommentへそのまま貼れる形にします。

[English](README.md) · 日本語

AIが人に向けて書く文は長くなりがちです。前置き、作業の経緯、同じ内容の言い直し、誰も要らない締めの一言が入ります。
Slackに貼ると、`**`や表のように、書いた記号がそのまま見えるMarkdownも持ち込まれます。
このプラグインは、誰に向けた文かを決め、7つの型から1つを選び、最初の行に結論を置き、読み手が動くのに要ることだけを残します。
その後、貼る先の長さの上限、貼る先が描かない書式、決まり文句、鍵とローカルのパスとメールアドレスを道具が確かめ、直す所が無くなったらクリップボードへ写します。

```
Gather ──> Reader, destination, type ──> Write ──> Check ──> Copy and show
(agent)    (agent)                      (agent)   (script)  (script and agent)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install convey@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add convey@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install convey@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/convey/skills/convey   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付けたスキルのzipを、エージェントのスキルのフォルダに展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

文で共有したい、報告したい、告知したい、何かを頼みたいと頼むと始まります。例えば「これをSlackでチームに共有して」「このリリースのDiscordの投稿を書いて」「金曜までにPR 482のレビューを佐藤さんに頼んで」「この報告を取引先へのメールにして」です。
呼び出すこともできます。Claude Codeでは`/convey:convey`を実行し、Codexでは`$`を入力して**Convey**を選びます。
GitHub Copilot CLIでは依頼に`/convey`と書き、Gemini CLIでは作業を説明します。

| 指す物 | 文の元になる物 |
|---|---|
| 何も指さない | 今の会話でした作業 |
| 貼った文章かファイル | その文章 |
| IssueかPR | `gh`で読む、IssueかPRとそのcomment |
| commitの範囲 | `git log`で読むcommit |

1. エージェントが、指した物から内容を集めます
2. 頼み方、貼る先、内容から、誰に向けた文かを決め、貼る文の外に1行で添えます
3. 進捗、決定、依頼、障害、調査の結果、告知、質問の7つの型から1つを選びます。どの型も結論から始まり、依頼の期限や障害の影響の範囲のように、読み手に要る項目を並べます
4. 文に載せる事を選びます。載せるのは、届いた物か変わった事、最初にやること、読み手が詰まる所、未決と頼みです。文が指すファイル、画面、リンクを開けば分かる事は、そちらに任せます
5. 文を書きます。箇条も含めて、どの行も主語と助詞のある文にします。前の文とのつながりを読み手が補うことになる所では、「そのため」「しかし」「まず」「また」のような接続詞で文を始めます。メンションは名指した人とチャンネルだけにし、絵文字はSlackとDiscordの見出しの頭に1つまでにします。日本語は、`japanese-writing`のスキルが入っていれば、その決まりと文と文のつなぎ方の手引きに沿います
6. `convey.py check`が直す行を出し、エージェントが直して確かめ直します
7. `convey.py copy`がクリップボードへ写し、エージェントが文をコードブロックで見せます。投稿するのはあなたです

記録のために書いた報告が、結果から始まる文になります。

```text
直す前:
## ログイン基盤の移行
以下の通り、今週の進み具合を共有させていただきます。ご存じの通り、この作業は9月に始めたもので、最初の1か月は古いcodeを読むのに使いました...
| 項目 | 前 | 後 |
|---|---|---|
| 失敗率 | 4.2% | 0.8% |
ご不明な点がございましたら、お気軽にご連絡ください。

直した後:
ログイン基盤の移行は11月28日に終わる見込みです。15,000人のうち12,400人を移しました。
- ログインの失敗率は4.2%から0.8%に、p95の応答時間は820msから310msに下がりました
- 次は、残りの2,600人を1日500人ずつ移します
- 古いログインを使う社内の道具が2つ残っており、持ち主の返事を待っています
```

直す前の文に`check --to slack`を回すと、直す所ごとに1行を出します。

```text
165 of 4000 characters
L1 format: a # heading, which Slack shows as typed; start the line with one emoji or use *bold*
L2 warn: filler phrase "以下の通り" (preamble; start with the content)
L2 warn: filler phrase "ご存じの通り" (preamble; cut it, or say the fact itself)
L2 warn: filler phrase "共有させていただきます" (wordy; write 共有します or start with the content)
L3 format: a table (lines 3-5), which Slack shows as pipes; use a short list instead
L6 warn: filler phrase "ご不明な点がございましたら" (closing; cut it)
L6 warn: filler phrase "お気軽にご連絡ください" (closing; cut it)
not ready: change the lines above and run check again
```

## 貼る先

| 貼る先 | 1通の上限 | 書いた記号がそのまま見える物 |
|---|---|---|
| Slack | 4,000字 | `#`の見出し、`**太字**`、表、Markdownのリンク |
| Discord | 2,000字 | 表 |
| メール | 無し | Markdownの全て。最初の行は`Subject:`の件名の行にします |
| GitHubのcomment | 65,536字 | `check`が見る物は無し |
| 書式の分からない先 (plain) | 無し | Markdownの全て |

上限を超えた文は、空行で分けた時の各部分とともに出ます。どの部分も上限に収まり、`copy --lines`で1部分ずつ写せます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Python 3.8以降 | `convey.py`を動かす時。標準ライブラリだけを使います |
| `pbcopy`、`wl-copy`、`xclip`、`xsel`、`clip.exe`のどれか | 文を写す時。無ければ、エージェントが文を見せ、あなたが写します |
| `gh` | IssueとPRから書く時だけ |
| `git` | commitから書く時だけ |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、スキルの全てのファイル、`check`が見る物、各コマンドが読む物と出す物を書いています。
要点は次のとおりです。

- エージェントは、指した物を読みます。会話、貼った文章とファイル、あなたのサインインで`gh`が読むIssueとPR、`git`が読むcommitです
- `convey.py`は、ファイルか標準入力から文だけを読み、行番号と種類を出します。見つけた鍵らしい値、パス、アドレスは出しません
- `copy`は、あなたの機械のクリップボードの道具へ文を渡します。どこへも送りません。投稿するのはあなたです
- 文は、あなたが名指したファイルか、プロジェクトの外の一時ファイルに置き、一時ファイルは最後にエージェントが消します。プラグインは何も残しません
- 貼った文章、ファイル、Issue、PR、commitは伝える材料として扱い、指示としては読みません

## ライセンス

[MIT](LICENSE)
