# 公式ディレクトリへの掲載

[English](publishing.md) · 日本語

[はじめに](getting-started.ja.md)で説明したとおり、このリポジトリのマーケットプレイスからは誰でもプラグインをインストールできます。
このページでは、それに加えてプラグインを公式ディレクトリに掲載し、Claudeの中や、ChatGPTとCodexの中で見つけてもらう方法を説明します。
どちらの公式ディレクトリも1回に1つのプラグインのフォルダを受け付け、メンテナーが自分のアカウントから提出します。

## 各プラグインの状況

| プラグイン | Anthropicの公式ディレクトリ | OpenAIの公式ディレクトリ |
|---|---|---|
| account-cleanup | 提出できます。`skills/account-cleanup/data/sites.json`が256 KiBを超えるため、各バージョンは公開前に審査担当者の確認待ちになります | アップロードできます。`assets/icon.svg`のアイコンを、`interface.composerIcon`と`interface.logo`の両方に使っています |
| pc-tidy | 提出できます | アップロードできます。アイコンも同じ形で設定しています |

Anthropicの公式ディレクトリでは、一般的な単語だけでできた名前も審査担当者の確認待ちになることがあります。

## Anthropicの公式ディレクトリ

掲載されたプラグインは、claude.aiから追加して、チャット、Cowork、Claude Codeで使えます。

提出には次の物が要ります。

- 公式ディレクトリへ提出できるロールが付いた、Claudeの有料プラン
- claude.aiに接続した、このリポジトリへプッシュできるGitHubのアカウント

手順は次のとおりです。

1. `claude plugin validate plugins/<name>`と`bash scripts/check.sh`を実行し、報告された問題を直します
2. 開発者ポータル`claude.ai/directory/manage`を開き、**Submit new**（新規提出）を選んでから**Plugin bundle**を選びます
3. **Source**（提出元）の画面で、リポジトリに`cardene777/agent-shuriken`、プラグインのパスに`plugins/<name>`、追跡するブランチに`release/<name>`を入力します
4. **Validate**（検証）を選び、**Blocking**の印が付いた指摘をすべて直します
5. **Listing details**（掲載内容）を確かめます。この内容は`.claude-plugin/plugin.json`と`README.md`から取られます
6. **Data handling**（データの扱い）の質問に下の表のとおり答え、**Compliance**を済ませてから**Submit for review**を選びます
7. そのバージョンが審査を通ったら、**Publish**を選びます

`scripts/release.sh`は、プラグインをリリースするたびに`release/<name>`をそのリリースへ動かします。
そのため、ポータルを開き直さなくても公式ディレクトリに新しいリリースが反映されます。
`main`にマージしただけでまだリリースしていない変更は、公式ディレクトリには反映されません。

## OpenAIの公式ディレクトリ

掲載されたプラグインは、ChatGPTとCodexが共有する公式ディレクトリに表示されます。

提出には次の物が要ります。

- 提出に使うOpenAI Platformの組織で、開発者か事業者として本人確認を済ませていること
- 組織のオーナーであるか、**Apps Management Write**の権限を持っていること
- プラグインのGitHubのリリースに添付された、プラグインのzipの`<name>-X.Y.Z-plugin.zip`

手順は次のとおりです。

1. プラグインの最新のGitHubリリースから、プラグインのzipをダウンロードします
2. OpenAI Platformで**Plugins**を開き、**Upload new or existing plugin**を選びます
3. 本人確認を済ませた開発者の身元を選び、**Upload plugin**を選んで、プラグインのzipをアップロードします
4. **Metadata & Skills**で検査とスキルのスキャンが終わるのを待ちます。**Issues**が出たら、直したzipをアップロードし直します
5. 下書きを選んで**Submit for review**を選び、ポリシーに関する確認事項に回答します
6. 承認されたら、承認されたバージョンを開いて**Publish plugin**を選びます

掲載済みのプラグインをアップデートするには、新しいリリースのプラグインのzipをアップロードし、もう一度審査に出します。
掲載される文は`.codex-plugin/plugin.json`の`interface`から取られ、このうち`displayName`と`shortDescription`は30文字までです。

## データの扱いに関する質問への答え

| 質問 | account-cleanup | pc-tidy |
|---|---|---|
| 個人データを読むか | パスワード管理アプリとブラウザから、サービス名、URL、日付を手元のマシン上で読みます。パスワードは読みません | ホームフォルダにあるファイルの名前、大きさ、日付を手元のマシン上で読みます |
| 個人データを保存するか | 手元のマシンの`~/.local/share/account-cleanup/`にだけ保存し、あなただけが読めるようにします | 手元のマシンの`~/.local/share/pc-tidy/`にだけ保存します |
| データをほかへ送るか | 各候補のドメインへの`HEAD`リクエストと、あなたが承認したサービスでのログインと削除の操作です。Web検索に使うのは、サービス名とドメインだけです | 何も送りません |
| データを保つ期間 | 作業を終えるまでです。終えた時点で、候補の一覧、候補を選ぶページ、ブラウザのプロファイルを削除します | 設定フォルダを消すまでです |
| 18歳未満の利用を想定しているか | いいえ | いいえ |

これらの答えの根拠は、各プラグインの`docs/how-it-works.md`に詳しく書いてあります。
