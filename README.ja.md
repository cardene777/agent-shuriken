<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shurikenのアイコン">

# agent-shuriken

**Claude Code、Codex、ほかのコーディングエージェントで使える、慎重なプラグイン集。**

どのプラグインでも、面倒な作業はエージェントが進め、取り消せない操作はすべてあなたが決めます。
同じプラグインを、Claude Code、Codex、GitHub Copilot CLIにインストールでき、そのスキルはGemini CLIや`SKILL.md`を読むほかのエージェントでも動きます。
自分のスキルとルールとhookを全てのエージェントへ配る`agent-shared`は、専用のリポジトリ[cardene777/agent-shared](https://github.com/cardene777/agent-shared)にあります。

[English](README.md) · 日本語

[プラグイン](#プラグイン) ·
[インストール](#インストール) ·
[ドキュメント](#ドキュメント) ·
[リリース](https://github.com/cardene777/agent-shuriken/releases) ·
[変更履歴](CHANGELOG.md)

</div>

## プラグイン

| プラグイン | できること | 呼び出し方 | 最新バージョン |
|---|---|---|---|
| [account-cleanup](plugins/account-cleanup) | パスワードを一切読まずに、使っていないWebアカウントを見つけます。あなたが承認したアカウントは、サブスクリプションを解約してからアカウントを削除します | Claude Codeでは`/account-cleanup:account-cleanup`を実行し、Codexでは`$`を入力して**Account Cleanup**を選びます。やりたいことを言葉で頼んでも始まります | [0.4.0](plugins/account-cleanup/CHANGELOG.md) |
| [agent-guards](plugins/agent-guards) | エージェントが鍵のファイルや`.env`を読むか上書きすること、1Passwordに控えた値を出すこと、鍵を含む文やコミットを送ること、強制pushなどの壊すgitの命令、フォルダごとの削除や権限の取り上げを止めるフックです | Claude CodeとCodexで、シェルの命令とファイルの読み取りと書き換えの前にひとりでに動きます。呼ぶ物はありません | [0.2.1](plugins/agent-guards/CHANGELOG.md) |
| [agent-notices](plugins/agent-notices) | `pipefail`の中で`grep -q`へ流すこと、裏へ回した`nohup`、効かなかったブランチの切り替え、`.env.example`に無い環境変数、一時ディレクトリの空きの不足、危ない書き方をエージェントに知らせ、編集したファイルを整形するフックです。呼び出しは止めません | Claude CodeとCodexで、シェルの命令と編集の後にひとりでに動きます。呼ぶ物はありません。スキルとMCPのログは変数でオンにします | [0.1.0](plugins/agent-notices/CHANGELOG.md) |
| [chainome-diagram](plugins/chainome-diagram) | ブロックチェーンの仕組みを説明する、動くReactとSVGの図を設計して見直します。動く段は1つにし、状態の変化は起きる場所で見せ、説明の文は図から離し、色は意匠のfileから取ります | Claude Codeでは`/chainome-diagram:chainome-diagram`を実行し、Codexでは`$`を入力して**Blockchain Diagram**を選びます。ブロックチェーンの動く図を頼んでも始まります | [0.2.0](plugins/chainome-diagram/CHANGELOG.md) |
| [compare-report](plugins/compare-report) | 選ぶ時の候補を調べ、すべての主張に出典を、すべての点数に判定の根拠を付けた比較のレポートをHTMLとPDFで作ります | Claude Codeでは`/compare-report:compare-report`を実行し、Codexでは`$`を入力して**Compare Report**を選びます。比較を言葉で頼んでも始まります | [0.6.0](plugins/compare-report/CHANGELOG.md) |
| [convey](plugins/convey) | 人に伝える文を、結論を先に置き、読み手に要らないことを入れずに書きます。Slack、Discord、メール、GitHubのcommentに合わせて、長さ、書式、秘密に当たる値を確かめてから写します | Claude Codeでは`/convey:convey`を実行し、Codexでは`$`を入力して**Convey**を選びます。文で共有したい、報告したい、告知したいと頼んでも始まります | [0.3.0](plugins/convey/CHANGELOG.md) |
| [design-formats](plugins/design-formats) | ドキュメントとレポートの説明の構造と見た目を持ちます。説明の並び、見た目の決まり、出所の付いた4つの画面の型の規則、4つのHTMLの頁の雛形、コロンを持つ見出しや表に無い付帯の情報や言語と明暗の切り替えの欠けを名指すscriptを持ちます | Claude Codeでは`/design-formats:page-design`を実行し、Codexでは`$`を入力して**Page Design**を選びます。頁を書くスキルが名前で開きます | [0.2.0](plugins/design-formats/CHANGELOG.md) |
| [diagram-composer](plugins/diagram-composer) | スライドの図の部分を、見立てを1つに決め、線ごとに意味を持たせ、ラベルを線から離して設計します。スライドを描く前にscriptが配置を確かめます | Claude Codeでは`/diagram-composer:diagram-composer`を実行し、Codexでは`$`を入力して**Diagram Composer**を選びます。スライドの図を言葉で頼んでも始まります | [0.1.1](plugins/diagram-composer/CHANGELOG.md) |
| [diagram-explainer](plugins/diagram-explainer) | すべての節に図を描いた説明資料を、JSONから組んで確かめ、1つのHTMLファイルにします | Claude Codeでは`/diagram-explainer:diagram-explainer`を実行し、Codexでは`$`を入力して**Diagram Explainer**を選びます。説明資料を言葉で頼んでも始まります | [0.4.0](plugins/diagram-explainer/CHANGELOG.md) |
| [diagram-styles](plugins/diagram-styles) | 記事と技術書の図を作ります。図ごとに読者の疑問から設計し、32の既定の画風か`~/.styles/`に置いた自分の一覧の画風で、agentの画像生成で描き、文字と接続を確かめます | Claude Codeでは`/diagram-styles:article-diagram-styles`か`/diagram-styles:tech-book-figure`を実行し、Codexでは`$`を入力して**Article Diagram Styles**か**Tech Book Figure**を選びます。記事を書くスキルが名前で開きます | [0.4.0](plugins/diagram-styles/CHANGELOG.md) |
| [digital-dashboard](plugins/digital-dashboard) | 設計の中でどの画面がダッシュボードかを判定し、デジタル庁のダッシュボードデザインのガイドブックの公式資料を指紋で確かめて取り、その画面にだけ当てる頼みの文を書きます | Claude Codeでは`/digital-dashboard:digital-dashboard`を実行し、Codexでは`$`を入力して**Digital Dashboard**を選びます。ダッシュボードを頼んでも始まります | [0.1.2](plugins/digital-dashboard/CHANGELOG.md) |
| [doc-formats](plugins/doc-formats) | ほかのスキルが従う文書の書式を持ちます。設計書の書式と、全ての節が埋まったかを確かめるscriptを持ち、evm-devの設計のスキルが使います | Claude Codeでは`/doc-formats:design-doc`を実行し、Codexでは`$`を入力して**Design Doc**を選びます。evm-devの設計のスキルが名前で開きます | [0.1.0](plugins/doc-formats/CHANGELOG.md) |
| [docs-publish](plugins/docs-publish) | あなたが作るライブラリ、コマンドラインの道具、Webサービスのドキュメントを、コードが公開か非公開かを問わず、Quickstart、Concepts、APIリファレンス、Cookbook、FAQの5つの部に分けて、英語とあなたが選ぶもう1つの言語で書きます。すべてのページに翻訳があり、すべてのリンクが切れていないかを確かめます | Claude Codeでは`/docs-publish:docs-publish`を実行し、Codexでは`$`を入力して**Docs Publish**を選びます。プロジェクトのドキュメントを頼んでも始まります | [0.4.0](plugins/docs-publish/CHANGELOG.md) |
| [evm-dev](plugins/evm-dev) | ERCが確定したか、EIPがEthereumのメインネットで動いているか、L2のネットワークとEthereumのL1の今後とコンセンサスだけを変えるEIPがどうなっているかを答え、プロジェクトが使うsolcとOpenZeppelinとFoundryとHardhatの版に合わせてSolidityのコントラクトとそのテストを書き、鍵にエージェントが触れずにコントラクトを配って出した物を記録し、出す前に配ってある版と出す先のチェーンに照らして確かめ、コントラクトと、ウォレットと署名と、複数のチェーンにまたがるアプリと、dAppの部品の組み方と、ISO 20022やFIXなどの金融の規格を使うアプリを設計します。どれも公式の文書で確かめた日付きの項目に基づきます | Claude Codeでは`/evm-dev:evm-standards`と`/evm-dev:ethereum-knowledge`と`/evm-dev:solidity-code`と`/evm-dev:contract-tests`と`/evm-dev:contract-deploy`と`/evm-dev:release-check`と`/evm-dev:contract-design`と`/evm-dev:wallet-design`と`/evm-dev:multichain-design`と`/evm-dev:dapp-architecture`と`/evm-dev:financial-standards`を実行し、Codexでは`$`を入力して**EVM Standards**と**Ethereum Knowledge**と**Solidity Code**と**Contract Tests**と**Contract Deploy**と**Release Check**と**Contract Design**と**Wallet Design**と**Multichain Design**と**dApp Architecture**と**Financial Standards**を選びます。ERCやEIPかL2かEthereumのL1の今後の状態を尋ねるか、コントラクトかそのテストを書くよう頼むか、コントラクトを配るよう頼むか、出す前の確かめを頼むか、コントラクトの設計かウォレットの設計か複数のチェーンの設計かdAppの構成か金融の規格を使う設計を頼んでも始まります | [0.9.0](plugins/evm-dev/CHANGELOG.md) |
| [excalidraw-diagram](plugins/excalidraw-diagram) | アーキテクチャ図、フロー図、シーケンス図、ER図を、スクリプトが配置して重なり、詰まった間隔、線に重なるラベルを確かめたExcalidrawのファイルとして描きます。SVGとPNGの写しも作ります | Claude Codeでは`/excalidraw-diagram:excalidraw-diagram`を実行し、Codexでは`$`を入力して**Excalidraw Diagram**を選びます。図を言葉で頼んでも始まります | [0.3.0](plugins/excalidraw-diagram/CHANGELOG.md) |
| [feedback-loop](plugins/feedback-loop) | エージェントの出力を訂正すると、訂正を記録してファイルを直し、何も編集しない評価者がすべての基準に合格と判定するまでレビューを繰り返し、学んだことを検査かルールとして残します | Claude Codeでは`/feedback-loop:feedback-loop`を実行し、Codexでは`$`を入力して**Feedback Loop**を選びます。前の出力を訂正しても始まります | [0.1.2](plugins/feedback-loop/CHANGELOG.md) |
| [flow-format](plugins/flow-format) | 流れ、手順、ワークフローがどう進むかの問いに、番号の付いた手順で答えます。各手順は動作の1文と字下げしない短い段落でできていて、流れに分岐や戻りが在る時は手順の後に文字で描いた図を足します | Claude Codeでは`/flow-format:flow-format`を実行し、Codexでは`$`を入力して**Flow Format**を選びます。始めから終わりまでどう進むかを聞いても始まります | [0.1.0](plugins/flow-format/CHANGELOG.md) |
| [init-project](plugins/init-project) | プロジェクトを手元で動かす準備をします。空いているローカルのポートを選び、Dockerの設定を書き、envファイルを参照の形で1Passwordにつなぎます。どのファイルも書く前に見せます | Claude Codeでは`/init-project:init-project`を実行し、Codexでは`$`を入力して**Init Project**を選びます。プロジェクトの準備を頼んでも始まります | [0.4.0](plugins/init-project/CHANGELOG.md) |
| [japanese-speaking](plugins/japanese-speaking) | 人が話しているように聞こえる日本語を書きます。ポッドキャストとラジオの掛け合い、1人がニュースを読んで2人で話す回、対談、ナレーション、話す原稿に使え、紙の文を読んでいるように聞こえる行を道具が指し、会話を引き継がない読み手が残りを聞いて探します | Claude Codeでは`/japanese-speaking:japanese-speaking`を実行し、Codexでは`$`を入力して**Japanese Speaking**を選びます。日本語の台本、掛け合い、ナレーションを頼んでも始まります | [0.3.0](plugins/japanese-speaking/CHANGELOG.md) |
| [japanese-writing](plugins/japanese-writing) | 日本語の文章を、元に無いことを足さずに自然に読める形で書き、直します。翻訳調、AIらしい言い回し、比喩の動詞を道具が指し、repoに置くMarkdownの書式の決まりを足します | Claude Codeでは`/japanese-writing:japanese-writing`を実行し、Codexでは`$`を入力して**Japanese Writing**を選びます。日本語を書いてほしい、自然にしてほしいと頼んでも始まります | [0.3.0](plugins/japanese-writing/CHANGELOG.md) |
| [learning-to-skill](plugins/learning-to-skill) | 会話で得た学びを、AGENTS.md、CLAUDE.md、スキルのSKILL.mdのようなエージェントが読む指示のファイルに、必要なエージェントに届く場所へ1回だけ書きます。書くのはあなたが差分を承認した後だけです | Claude Codeでは`/learning-to-skill:learning-to-skill`を実行し、Codexでは`$`を入力して**Learning to Skill**を選びます。学びを覚えておくよう頼んでも始まります | [0.1.2](plugins/learning-to-skill/CHANGELOG.md) |
| [machine-cleanup](plugins/machine-cleanup) | 道具が作り直すキャッシュ、gitが無視するビルドの出力、大きいファイルと重複、使っていないアプリ、残っている開発用のサーバー、重いプロセス、ログイン項目、動いているコンテナを見つけ、手元のページで選んだ物だけを空けます。別の会話が使う物は表示しますが選べません | Claude Codeでは`/machine-cleanup:machine-cleanup`を実行し、Codexでは`$`を入力して**Machine Cleanup**を選びます。ディスクがいっぱいだ、コンピューターが重いと言っても始まります | [0.3.0](plugins/machine-cleanup/CHANGELOG.md) |
| [mechanism-explainer](plugins/mechanism-explainer) | 各節が1つの問いに、1文の答えとdragonの記法で描いた2〜4枚の図で答える説明資料の頁を作り、PDFにも書き出します | Claude Codeでは`/mechanism-explainer:mechanism-explainer`を実行し、Codexでは`$`を入力して**Mechanism Explainer**を選びます。説明資料を言葉で頼んでも始まります | [0.2.0](plugins/mechanism-explainer/CHANGELOG.md) |
| [motion-diagram](plugins/motion-diagram) | 仕組みを、カードが流れを1回通って実際の数で止まる1枚の動く絵で見せます。部品をあなたと決めてからエージェントが小さな仕様を書き、部品を押すと中身が出ます。ネットにつながずに開くHTMLのページ、MP4の動画、GIF、PNGの画像で作ります | Claude Codeでは`/motion-diagram:motion-diagram`を実行し、Codexでは`$`を入力して**Motion Diagram**を選びます。仕組みを動く図で見せてと頼んでも始まります | [0.1.0](plugins/motion-diagram/CHANGELOG.md) |
| [portman](plugins/portman) | プロジェクトごとに使うlocalhostのポートを1つの台帳で管理し、今それぞれのポートを何が使っているかを示し、よく使われる既定のポートを避けた空きポートを提案し、承認した後にプロジェクトの`.env.local`とDocker Composeにポートを書きます | Claude Codeでは`/portman:portman`を実行し、Codexでは`$`を入力して**Portman**を選びます。ポートが使われていて困った時にも始まります | [0.4.0](plugins/portman/CHANGELOG.md) |
| [product-deck](plugins/product-deck) | 実際の製品の画面から製品の紹介資料を作ります。字は1つのデータのファイルに置き、版面と文章を機械で確かめ、HTMLとPDFとPowerPointに焼きます | Claude Codeでは`/product-deck:product-deck`を実行し、Codexでは`$`を入力して**Product Deck**を選びます。製品の紹介資料を頼んでも始まります | [0.2.0](plugins/product-deck/CHANGELOG.md) |
| [remotion-explainer](plugins/remotion-explainer) | 題材そのものを絵にしたRemotionの解説動画を、アートディレクションと基準の場面から、全ての区切りのラフ、静止したボード、仕上げまで、あなたが承認する関門を通して作り、独自のPNGの原画と描き込まれる輪郭も作ります。動きを、1つの主役を場面から場面へ受け渡し、どの動きも実際に見た動画を根拠にする形で計画し、場面ごとに借りる作例を、利用を許すライセンスのRemotionの作例のカタログから探し、フレームを機械で確かめます。線が接続点で終わるか、安全な範囲と字幕の場所を守るか、要素の出始めと消え際に何かが一瞬映らないか、同じ作りの場面が続かないかを見て、その取り決めをmusubiでほかのスキルに渡します | 動画を作る時は、Claude Codeでは`/remotion-explainer:remotion`を実行し、Codexでは`$`を入力して**Remotion**を選びます。1つの部分だけの時は、`/remotion-explainer:remotion-explainer-production`、`/remotion-explainer:remotion-explainer-review`、`/remotion-explainer:png-asset-production`、`/remotion-explainer:png-outline-tracing`、`/remotion-explainer:remotion-motion-plan`、`/remotion-explainer:remotion-frame-checks`、`/remotion-explainer:remotion-catalog`か、**Remotion Explainer Production**、**Remotion Explainer Review**、**PNG Asset Production**、**PNG Outline Tracing**、**Remotion Motion Plan**、**Remotion Frame Checks**、**Remotion Catalog**を選びます。解説動画を作って、動きを計画して、PNGの原画を作って、Remotionの動画の配置や時間を確かめて、場面に使える作例を探して、と頼んでも始まります | [0.1.0](plugins/remotion-explainer/CHANGELOG.md) |
| [repo-progress](plugins/repo-progress) | 作業しているリポジトリ全部を、worktree、開いたIssueとプルリクエスト、コミットしていない変更とともに1つの表にし、止まっている物から並べます。何も変えません | Claude Codeでは`/repo-progress:repo-progress`を実行し、Codexでは`$`を入力して**Repo Progress**を選びます。何をやりかけだったか尋ねても始まります | [0.2.0](plugins/repo-progress/CHANGELOG.md) |
| [screen-video](plugins/screen-video) | Webアプリ、macOSのアプリ、iOS SimulatorかAndroidエミュレーターのアプリの動画をあなたと計画し、撮る前に操作ごとの画を並べた台本で見せてから撮ります。動画は読み上げと静かな曲付きで、テーマの枠と題と章のカードを持ち、操作ごとに寄り、横長、縦長、GIFで作ります。個人の値はぼかし、送信や支払いを起こす操作の手前で止まります | Claude Codeでは`/screen-video:screen-video`を実行し、Codexでは`$`を入力して**Screen Video**を選びます。アプリのデモ動画を頼んでも始まります | [0.4.0](plugins/screen-video/CHANGELOG.md) |
| [secure-dotfile](plugins/secure-dotfile) | シェルの起動ファイル、`~/.npmrc`、`~/.aws/credentials`に書いたAPIキーやトークンを見つけ、選んだ物だけを、エージェントに値を見せずにmacOSのキーチェーン、LinuxのSecret Service、`pass`、1Passwordのどれかへ移します | Claude Codeでは`/secure-dotfile:secure-dotfile`を実行し、Codexでは`$`を入力して**Secure Dotfile**を選びます。シェルの設定にある秘密の値の話をしても始まります | [0.8.0](plugins/secure-dotfile/CHANGELOG.md) |
| [session-handoff](plugins/session-handoff) | 新しいセッションに貼り付ける短いメッセージを書き、却下した案、今の段階、任せた作業、してはいけないことをプロジェクトごとに保存します。秘密の値に見える物は保存しません | Claude Codeでは`/session-handoff:session-handoff`を実行し、Codexでは`$`を入力して**Session Handoff**を選びます。呼び出した時だけ始まります | [0.1.1](plugins/session-handoff/CHANGELOG.md) |
| [skill-tune](plugins/skill-tune) | プラグインに置いた`claude plugin eval`の評価の案件でスキルを測り、`SKILL.md`を短くし、もう一度測ってどの案件も点が下がらないことを確かめます。費用は走らせる前に決めます | Claude Codeでは`/skill-tune:skill-tune`を実行し、Codexでは`$`を入力して**Skill Tune**を選びます。スキルを測る、短くすると頼んでも始まります | [0.2.0](plugins/skill-tune/CHANGELOG.md) |
| [slides](plugins/slides) | 10枚以上の説明の資料の構成をMarkdownで書いて確かめ、短い発表の資料をHTMLで作ってブラウザで直し、PowerPointとPDFとHTMLに書き出します | Claude Codeでは`/slides:slide-builder`か`/slides:slide-forge`を実行し、Codexでは`$`を入力して**Slide Builder**か**Slide Forge**を選びます。資料やスライドを言葉で頼んでも始まります | [0.1.2](plugins/slides/CHANGELOG.md) |
| [techdebt](plugins/techdebt) | ファイルごとの変更の回数に、大きさ、古いTODOのコメント、テストの有無、長い関数、重複を合わせて直す価値の高いファイルに順位を付け、上位のファイルを説明します | Claude Codeでは`/techdebt:techdebt`を実行し、Codexでは`$`を入力して**Tech Debt**を選びます。技術的負債について尋ねても始まります | [0.4.0](plugins/techdebt/CHANGELOG.md) |

各プラグインのREADMEに、何をするか、何を読んで何を送るか、何が必要かを書いています。

## インストール

このリポジトリをマーケットプレイスとして一度だけ追加し、使いたいプラグインをインストールします。

**Claude Code**

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install techdebt@agent-shuriken
```

**Codex**

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add techdebt@agent-shuriken
```

**GitHub Copilot CLI**

```
copilot plugin marketplace add cardene777/agent-shuriken
copilot plugin install techdebt@agent-shuriken
```

**Gemini CLI**

```
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt
```

`techdebt`の部分は、表にある別のプラグイン名に置き換えられます。
`SKILL.md`を読むほかのエージェントでは、各プラグインのリリースに添付したスキルのzipを使えます。
インストールでコピーされるのは、そのプラグインのフォルダだけです。
起動、アップデート、バージョンの固定、削除の方法は[はじめに](docs/getting-started.ja.md)で説明しています。

## ドキュメント

| ページ | 内容 |
|---|---|
| [はじめに](docs/getting-started.ja.md) | Claude Code、Codex、GitHub Copilot CLI、Gemini CLI、ほかのエージェントでのプラグインのインストール、起動、アップデート、削除 |
| [安全性](docs/safety.ja.md) | あなたのアカウントやファイルに触れる時に、どのプラグインも守る約束 |
| [プラグインの作り方](docs/creating-a-plugin.ja.md) | このリポジトリに新しいプラグインを追加する方法 |
| [リリースの手順](docs/releasing.ja.md) | プラグインのバージョンとリポジトリのバージョンをリリースする方法 |
| [公式ディレクトリへの掲載](docs/publishing.ja.md) | AnthropicとOpenAIのプラグインの公式ディレクトリにプラグインを提出する方法 |

どのページも日本語で読めます。

## バージョン

プラグインごとにバージョンがあり、`techdebt--v0.1.0`のようなタグでリリースします。
リポジトリにもバージョンがあり、`v0.2.0`のようなタグでリリースします。
リポジトリのバージョンを見ると、その時点でマーケットプレイスにあった各プラグインのバージョンが分かります。
どちらもセマンティックバージョニングに従い、[リリースのページ](https://github.com/cardene777/agent-shuriken/releases)に並びます。

## 開発に参加する

Issueとプルリクエストを歓迎します。
先に[プラグインの作り方](docs/creating-a-plugin.ja.md)と[`AGENTS.md`](AGENTS.md)を読み、プルリクエストを出す前に`bash scripts/check.sh`を実行してください。

## セキュリティ

脆弱性は、[`SECURITY.md`](SECURITY.md)に書いた方法で非公開で報告してください。

## ライセンス

[MIT](LICENSE)です。
各プラグインのフォルダには、ライセンスのコピーと、同梱している第三者の素材の一覧が入っています。
