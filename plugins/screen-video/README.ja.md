# Screen Video

Webアプリの動画をエージェントと一緒に計画し、操作ごとの画を並べた台本で確かめてから、字幕付き、編集済み、縦長、GIFの動画に撮ります。動画は読み上げと曲付きで、選んだ見た目に仕上げます。

[English](README.md) · 日本語

画面の動画を手で撮ると、何度も撮り直すことになります。押す所を外したり、個人のメールアドレスが映ったり、待ち時間が長引いたり、支払いがもう一度通ったりするためです。
このプラグインは、まず動画をあなたと決めるところから始めます。何のための動画か、誰が見るか、どのくらいの長さか、どの操作が送信や支払いを起こすかを決めます。
エージェントは操作の順を流れのファイルとしてプロジェクトに書き、録画せずに通して、操作ごとの画を並べた台本を見せます。
あなたが台本を見て答えた後でだけ、エージェントはブラウザで流れを撮り、動画を作ります。

```
動画を決める ──> 流れを書く ──> 通す ──> 台本 ──> 撮る ──> 動画
 (あなたとエージェント) (エージェント) (エージェント) (あなたが確かめる) (エージェント) (あなたが確かめる)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install screen-video@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add screen-video@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install screen-video@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/screen-video/skills/screen-video   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「登録の流れを30秒のデモ動画にして」「READMEに載せる、プロジェクトを作る所のGIFを撮って」のように、アプリの動画を頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/screen-video:screen-video`を実行し、Codexでは`$`を入力して**Screen Video**を選びます。
GitHub Copilot CLIでは依頼の中に`/screen-video`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、何のための動画か、誰が見るか、長さ、作る動画、隠す値、送信や支払いを起こす操作、見た目と音を尋ね、操作の順と字幕と章を提案します
2. エージェントが頁を開いてボタンと入力欄を並べ、流れをプロジェクトの`.screen-video/flows/<name>.json`に書きます
3. エージェントが録画せずに流れを通し、台本を見せます。台本には、操作ごとに押す所を囲んだ画と、操作の内容と字幕が並びます
4. あなたが良いと答えると、エージェントが流れを撮って動画を見せます。直す時は、流れを直してもう一度通します

流れは次のような形です。

```json
{
  "version": 1,
  "name": "create-project",
  "url": "http://localhost:4300/",
  "outputs": ["16:9", "gif"],
  "mask": [{ "css": ".account-email" }],
  "steps": [
    { "do": "fill", "target": { "label": "Project name" }, "text": "Spring launch", "caption": "Name the project" },
    { "do": "click", "target": { "role": "button", "name": "Create project" }, "caption": "Create it" },
    { "do": "wait", "until": { "text": "Project created" } }
  ]
}
```

ボタンと入力欄は、スクリーンリーダーが読み上げる名前で指すため、画面の配置が変わっても流れはそのまま動きます。
全ての項目は[流れの書式](skills/screen-video/references/flow-format.md)にあります。

## 作る動画

| ファイル | 中身 |
|---|---|
| `raw.mp4` | 撮ったままの動画。1920x1080です |
| `captioned.mp4` | 操作ごとの字幕を、その操作が指す所に被らない位置に焼き込み、音を付けた動画 |
| `edited.mp4` | 仕上げた動画。中身は下に書きます |
| `vertical.mp4` | 同じ見た目の1080x1920のSNS向けの動画。窓が操作を追います。流れが`9:16`を求めた時に作ります |
| `edited.gif` | 編集済みの動画のGIF。流れが`gif`を求めた時に作ります |
| `captions.srt`、`edited.srt` | 撮った動画と編集済みの動画の字幕のファイル |
| `credits.txt` | 読み上げの声の表記が要る時の、声の名前 |

編集済みの動画は、操作ごとに滑らかに寄り、ポインターは押す所に近づくほど遅くなる曲線で動きます。
押すたびに輪が出てボタンが沈み、頁が変わる所は前の頁から次の頁へ溶けるように移ります。
画面はテーマの背景の上の枠に収まり、最初に題のカード、章ごとに章のカード、最後に締めのカードが入ります。
字幕は画面の下に出て読み上げられ、声の下で静かな曲が流れ、クリックとキーごとに音が鳴ります。
長い待ちは切らずに印を付けて早送りし、動画は計画した長さに合わせます。

見た目は`default`(濃い灰青)、`midnight`(黒に近い紫)、`paper`(明るい)の3つを同梱しています。
プロジェクトの`.screen-video/themes/<name>.json`に、変える色と字体だけを書いて自分の見た目を足せます。
撮った後で見た目や読み上げや曲を変える時は、エージェントが流れを直し、サイトを開かずに動画を作り直します。
`compare`は、撮ったままの動画と編集済みの動画を、これらの点ごとに並べて再生する頁を書きます。
あなたが撮った動画がある時は、エージェントが場面の変わり目を探して字幕を書き、字幕付きと編集済みの動画を作ります。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Node.js 20.11以降 | 常に |
| `pnpm`か`npm` | 初めて使う時に1回、Playwrightとffmpegをデータのフォルダへ入れるために使います |
| libx264を持つffmpeg | 無くても動きます。`PATH`にあれば、同梱の物の代わりに使います |
| `bsdtar`か7-Zip(`7zz`) | 日本語の読み上げを手元で作る時だけ、AivisSpeech Engineを展開するために使います。macOSには`bsdtar`があります |
| Python 3.10以降 | 流れがVOICEVOXを選んだ時だけ |

グローバルにはパッケージを入れません。
初回は`playwright-core`とそのヘッドレスブラウザと`ffmpeg-static`を取得するため、1分ほど掛かります。
読み上げる流れを初めて撮る時は、その声をデータのフォルダの`voices/`へ入れます。英語ではkokoro-jsとそのモデル、日本語ではAivisSpeech Engineとその声のまおを入れます。日本語では、エンジンが初めて起動する時に取得する言語モデルと既定の声を合わせて約1.3GBになります。
まおで読み上げた動画には、クレジットの表記が要りません。
流れがVOICEVOXを選んだ時は、あなたが規約に同意した後で入れ、動画の締めのカードにその声を表記します。

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、通し方、撮り方、編集の仕方、各ファイルの置き場を載せています。
要点は次のとおりです。

- 流れが名指しする頁だけを手元のマシンのブラウザで開きます。頁の文は見せる材料として扱い、指示としては従いません
- ログインの値は流れが名指しするenvファイルから読み、表示もファイルへの書き出しもしません。手でしたログインは`~/.local/share/screen-video/sessions/`に保存し、あなただけが読めるようにします。`logout`を打つまで、流れに`login.forget`がある時は録画が終わるまで残します
- 流れの`mask`に挙げた値を、全てのコマでぼかします
- 送信か支払いの印を付けた最初の操作の手前で通しを止め、その操作はあなたが同意した後でだけ撮ります
- 別のフォルダを指定しない限り、動画は`~/.local/share/screen-video/<project>/<flow>/`に書きます。自分が書いていないファイルを含むフォルダは空にしません
- 初回に`playwright-core`とそのブラウザと`ffmpeg-static`を1回取得し、読み上げる流れを初めて撮る時に声の道具を1回取得します
- 読み上げは手元のマシンで作ります。日本語では、読み上げを作る間だけAivisSpeech Engineを`127.0.0.1`で動かし、Sentryへのエラー報告は止めます。エンジンは版と声の情報をAivisHubへ問い合わせます
- ほかには何も送りません。流れが外の声(OpenAI、ElevenLabs、Microsoft Azure、Google Cloud)を選んだ時だけ、字幕の文をその会社へ送ります。その鍵は流れが名指しするenvファイルから読みます

## ライセンス

[MIT](LICENSE)
