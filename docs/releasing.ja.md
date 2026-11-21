# リリースの手順

[English](releasing.md) · 日本語

このページでは、このリポジトリにある2種類のバージョンと、それぞれのリリースの方法を説明します。

## 2種類のバージョン

| | プラグインのバージョン | リポジトリのバージョン |
|---|---|---|
| 何のバージョンか | 1つのプラグイン | マーケットプレイス全体。どのバージョンのプラグインを提供しているかと、リポジトリ自体のドキュメントとスクリプトが対象です |
| 書く場所 | そのプラグインにある2つの`plugin.json`の`version` | ルートの`CHANGELOG.md`で最も新しいリリースの見出し |
| 変更履歴 | `plugins/<name>/CHANGELOG.md` | `CHANGELOG.md` |
| タグ | `<name>--v<X.Y.Z>`、例えば`techdebt--v0.1.0` | `v<X.Y.Z>`、例えば`v0.2.0` |
| リリースの添付ファイル | `<name>-<X.Y.Z>-skill.zip`と`<name>-<X.Y.Z>-plugin.zip` | なし |

エージェントは、プラグインのバージョンを見てアップデートがあるかを判断します。
そのプラグインをリリースするたびにバージョンを上げてください。
上げないと、利用者は手元のコピーを使い続けます。

## セマンティックバージョニング

| 上げる番号 | 上げる時 |
|---|---|
| メジャー（`1.0.0`から`2.0.0`） | プラグインの呼び出し方か保存する内容が変わり、利用者の側で対応が要る時 |
| マイナー（`0.1.0`から`0.2.0`） | プラグインに機能が増えた時か、リポジトリにプラグインが増えた時 |
| パッチ（`0.1.0`から`0.1.1`） | 新しい機能を足さずに動きを直した時 |

## 作業中にすること

利用者が気付く変更を含むプルリクエストでは、触れたプラグインそれぞれの変更履歴の`## [Unreleased]`の下に1行足します。
リポジトリ自体の変更は、ルートの`CHANGELOG.md`の`## [Unreleased]`の下に書きます。
これらのプルリクエストでは、バージョンは変えません。

## プラグインをリリースする

1. プラグインの`## [Unreleased]`の項目を新しい`## [X.Y.Z] - YYYY-MM-DD`節へ移すプルリクエストを出します。そのプルリクエストでは、新しい節の上に空の`## [Unreleased]`を残し、ファイル末尾のリンクの定義を更新し、プラグインにある2つの`plugin.json`の`version`を`X.Y.Z`にします
2. マージしてから、`main`をチェックアウトしてプルします
3. `bash scripts/release.sh <name> X.Y.Z --dry-run`を実行し、表示されたリリースノートと添付ファイルを読みます
4. `bash scripts/release.sh <name> X.Y.Z`を実行します

doc-formatsかevm-devをリリースする前に、手元のmusubiのリポジトリのmusubiの命令で、このリポジトリの根から`musubi check plugins/doc-formats/skills plugins/evm-dev/skills`を実行し、`ok`が出た時だけリリースします。
`design-doc`の設計書の書式か`verify`を変えた時は、先に各設計のスキルを変更に照らして確かめ、同じ命令に`--update`を付けて実行し、新しい指紋をコミットします。

conveyかjapanese-writingをリリースする前も、同じように`musubi check plugins/japanese-writing/skills plugins/convey/skills`を実行し、`ok`が出た時だけリリースします。
japanese-writingの`references/connecting.md`か`SKILL.md`を変えた時は、先にconveyを変更に照らして確かめ、同じ命令に`--update`を付けて実行し、新しい指紋をコミットします。

design-formatsか、スキルがpage-designに従うプラグインをリリースする前も、同じように`musubi check plugins/design-formats/skills plugins/doc-formats/skills plugins/techdebt/skills plugins/compare-report/skills plugins/machine-cleanup/skills plugins/account-cleanup/skills plugins/diagram-explainer/skills plugins/repo-progress/skills plugins/secure-dotfile/skills plugins/init-project/skills plugins/evm-dev/skills plugins/portman/skills`を実行し、`ok`が出た時だけリリースします。
page-designの書式か雛形か`verify`を変えた時は、先に従う各スキルを変更に照らして確かめ、同じ命令に`--update`を付けて実行し、新しい指紋をコミットします。

diagram-stylesをリリースする前も、同じように`musubi check plugins/diagram-styles/skills`を実行し、`ok`が出た時だけリリースします。
article-diagram-stylesの`references/style4.md`か`SKILL.md`を変えた時は、先にtech-book-figureを変更に照らして確かめ、同じ命令に`--update`を付けて実行し、新しい指紋をコミットします。

スクリプトが動くのは、最新の`main`の上で作業ツリーに未コミットの変更が無く、`scripts/check.sh`が通り、バージョンがプラグインの変更履歴とマニフェストに一致する時だけです。
条件がそろうと、`<name>--vX.Y.Z`のタグを付けてプッシュし、変更履歴の節をリリースノートにしたGitHubのリリースを作って、次の2つのzipを添付します。

| ファイル | 中身 | 用途 |
|---|---|---|
| `<name>-X.Y.Z-skill.zip` | スキルのフォルダ | マーケットプレイスを使わずに、スキル用フォルダへ展開する |
| `<name>-X.Y.Z-plugin.zip` | プラグインのフォルダ全体 | OpenAIのプラグインの公式ディレクトリにアップロードする |

## リポジトリをリリースする

1つ以上のプラグインをリリースした後か、リポジトリ自体を変えた後に、リポジトリをリリースします。

1. ルートの`## [Unreleased]`の項目を新しい`## [X.Y.Z] - YYYY-MM-DD`節へ移すプルリクエストを出します。この節には全プラグインとその現在のバージョンを並べた`### Plugins`の表を入れ、リンクの定義も更新します
2. マージしてから、`main`をチェックアウトしてプルします
3. `bash scripts/release.sh repo X.Y.Z --dry-run`を実行し、続けて`bash scripts/release.sh repo X.Y.Z`を実行します

スクリプトは、`### Plugins`の表が`main`にあるプラグインのバージョンと一致するかを確かめます。
そのうえで`vX.Y.Z`のタグを付け、最新のリリースの印を付けたGitHubのリリースを作ります。
プラグインのリリースには最新の印を付けないので、リリースのページではリポジトリのリリースが一番上に表示され続けます。
