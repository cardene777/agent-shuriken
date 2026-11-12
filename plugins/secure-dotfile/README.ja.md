# Secure Dotfile

シェルの起動ファイルに書いたAPIキーやトークンを、エージェントに値を一度も見せずにmacOSのキーチェーンへ移します。

[English](README.md) · 日本語

`~/.zshrc`に`export OPENAI_API_KEY="sk-..."`のような行があると、キーはバックアップにも、dotfileのリポジトリにも、そのファイルを読むエージェントの会話にも入ります。
手で移すには、キーをターミナルに貼ってシェルの履歴に残し、行を1つずつ打ち間違えずに書き換えることになります。
このプラグインはそうした行を見つけ、選んだ物だけをキーチェーンへ移します。
移した行はシェルの起動時にキーチェーンから値を読むので、プログラムからは前と同じ環境変数が見えます。
値を読み、保存し、確かめるのはスクリプトなので、エージェントに届くのは名前と場所と種類と長さだけです。

```
起動ファイルを調べる ──> 移す物を選ぶ ──> キーチェーンへ保存して行を書き換える ──> 結果を報告し、キーの作り直しを勧める
 (エージェント)          (あなた)          (エージェント)                           (エージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install secure-dotfile@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add secure-dotfile@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install secure-dotfile@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/secure-dotfile/skills/secure-dotfile   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「.zshrcにAPIキーを書いているので、安全な所へ移したい」のようにシェルの設定にある秘密の値の話をすると始まります。
呼び出して始めることもできます。Claude Codeでは`/secure-dotfile:secure-dotfile`を実行し、Codexでは`$`を入力して**Secure Dotfile**を選びます。
GitHub Copilot CLIでは依頼の中に`/secure-dotfile`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントがシェルの起動ファイルを調べ、秘密の値を名前と場所と種類と長さで並べ、値がファイルのgitの履歴にあるかを示します
2. 移す物をあなたが選びます
3. エージェントが1つずつキーチェーンへ保存して読み戻し、その行をキーチェーンから値を読む形に書き換えます。キーチェーンの鍵を開けるために、macOSがログインのパスワードを尋ねることがあります
4. エージェントが、移した物と、移さなかった物とその理由を報告します。値がgitの履歴にあるキーは作り直すよう伝えます

調べた結果は次の形です。

```text
Scanned 4 files: ~/.zprofile, ~/.zshrc, ~/.bashrc, ~/.secrets.sh
Found 2 secrets written into them.

1  GH_TOKEN  ~/.zshrc:12
   GitHub token, 40 characters, in git history: not in a git repository
   item     ~/.zshrc:12:GH_TOKEN
   becomes  export GH_TOKEN="$(security find-generic-password -a "$USER" -s GH_TOKEN -w 2>/dev/null)"
2  OPENAI_API_KEY  ~/.secrets.sh:3
   OpenAI API key, 164 characters, in git history: yes
   item     ~/.secrets.sh:3:OPENAI_API_KEY
   becomes  export OPENAI_API_KEY="$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null)"
```

Codexのように、エージェントのサンドボックスが尋ねた時は命令を承認してください。ホームフォルダのファイルを読み、キーチェーンを使うためです。

## 必要な物

| 道具 | 要る時 |
|---|---|
| macOSと`security`コマンド | 秘密の値を移す時。調べるだけならLinuxでも動きます |
| `python3` | 常に。macOSに入っている物で動きます |
| `git` | 値がファイルのgitの履歴にあるかを調べる時 |
| `zsh`、`bash`、`fish` | 書き換えたファイルの文法を確かめる時。シェルが無いファイルは、書き換えますが確かめません |
| `chezmoi` | dotfileをchezmoiで管理している時だけ |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、調べるファイル、秘密の値とみなす条件、移す時の各段を載せています。
要点は次のとおりです。

- シェルの起動ファイルと、そこから読み込むファイルを読みます。`git`にそれらの履歴を、`chezmoi`に元のファイルを尋ねます
- 値は一部も表示しません。値はスクリプトの中にとどまり、`security`コマンドには標準入力で渡すので、コマンドラインには載りません
- 選んだ値だけを既定のキーチェーンに保存し、同じ名前で別の値が入っている時は上書きしません
- 書き換えるのは移した値の行だけです。ファイルの権限とシンボリックリンクを保ち、書き換えた後に文法を確かめます
- ネットワークにはつながず、自分用のファイルも残しません

## ライセンス

[MIT](LICENSE)
