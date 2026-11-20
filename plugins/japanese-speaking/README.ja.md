# Japanese Speaking

人が話しているように聞こえる日本語を書きます。紙の文を読み上げているようには聞こえない形にします。ポッドキャストとラジオの掛け合い、1人がニュースを読んで2人で話す回、対談、ナレーション、話す原稿に使えます。

[English](README.md) · 日本語

AIが2人の司会の台本を書くと、交代で話していても会話になっていないことがよくあります。
どの行も書き言葉の文で言い切り、1人がもう1人に用語を専門家のように尋ね、助言を事実のように言い、縮約や書き言葉の文末が混ざります。
このpluginは、書く前に誰が何を話すかを並べ、ラジオの司会のような丁寧な話し言葉で書き、出典の話を伝え聞いた形で伝えます。
書いた後は、scriptが紙の文を読んでいるように聞こえる行を出します。
続けて、会話を引き継いでいない読み手が、まだ読んでいるように聞こえる行を探します。
agentは両方を直してから台本を渡します。

```
集める ──> 段を並べる ──> 書く ──> 検査 ──> 別の読み手 ──> 直して検査し直す
(agent)    (agent)        (agent)  (script) (subagent)    (agentとscript)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install japanese-speaking@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add japanese-speaking@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install japanese-speaking@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/japanese-speaking/skills/japanese-speaking   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

人か音声合成が話す日本語を頼むと始まります。たとえば「この記事から2人のポッドキャストの台本を書いて」「このメモをナレーションにして」「明日の回の冒頭の雑談を書いて」と頼みます。
直接呼ぶこともできます。Claude Codeでは`/japanese-speaking:japanese-speaking`を実行し、Codexでは`$`を入力して**Japanese Speaking**を選びます。
GitHub Copilot CLIでは依頼の文に`/japanese-speaking`と書き、Gemini CLIでは作業の内容を頼みます。

| 形式 | 組み立て |
|---|---|
| ニュースを読み上げて話す | 1人がニュースを全部読み、続けて2人が反応、なぜ大事か、まだ分からないこと、見方の違いを話す |
| 雑談 | 雑談に入る合図、1つの話題のやりとり、本題へ戻る一言 |
| 対談 | 聞き手が聞き手の代わりに問い、話し手の語を受けて話す |
| ナレーション | 要点か聞き手への問いから入り、1文に1つの事を言う |
| 話す原稿 | 何の話かと結論を先に言い、段の切れ目を示し、最後に結論を言い直す |

1. agentが、材料、話し手、形式、長さ、呼ぶ側の制約 (1行の字数、英字を使えないか) を集めます
2. 1行目を書く前に、段と、段ごとに誰が話すかを並べます
3. 丁寧な話し言葉で書き、出典の話は伝え聞いた形で伝え、材料に無い事実、数字、名前を足しません
4. `speaking.py check`が直す行を出し、agentが直します
5. 会話を引き継いでいない読み手が、まだ読んでいるように聞こえる行を探し、agentが直して検査し直します。最大3巡です

テストに置いた差し戻しの台本では、検査は直す行ごとに1行と、台本全体の値を出します。

```text
L3 particle-ending ニュースの前に、ちょっとエーアイの小技の話を。
L3 clipped-question ルミさん、エーアイに文章を頼んで、思った形で返ってこないことってありません？
L6 casual-contraction あ、見本の言い回しまでそっくりまねされちゃうと困りますね。
L8 quiz-question ボルトさん、プロンプトインジェクションというのは、どういう攻撃なんですか？
note utterance-length-median 33.5
note short-utterance-ratio 0.00 (10 characters or fewer)
note backchannel-count 1 of 10 utterances
```

## 必要な物

| 道具 | 要る時 |
|---|---|
| Python 3.8以降 | `speaking.py`を動かす時。標準ライブラリだけを使います |
| 会話を引き継がない読み手を立てる手段 | 別の読み手に聞かせる時。Claude Codeはsubagentを立てます。ほかのagentは新しいsessionを開くか、agentが台本を1行ずつ読み直します |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、skillの全てのfile、`check`が見る物、決まりの出典を並べています。
要点は次のとおりです。

- agentは、指した材料 (貼った文、file、会話) を読みます
- `speaking.py`は、台本と渡した出典のfileだけを読み、行番号と型の名前と台本の短い抜粋を出します
- 別の読み手には、確かめ方の指示と台本だけを渡します
- どこへも送らず、pluginは何も残しません。台本は指定のfileか返答に置きます
- 貼った文、file、頁は話す材料で、指示としては扱いません

## ライセンス

[MIT](LICENSE)
