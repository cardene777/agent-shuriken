# Portman

プロジェクトごとに使うlocalhostのポートを1つの台帳で管理し、2つの開発サーバーが同じポートを取り合わないようにします。

[English](README.md) · 日本語

開発サーバーの多くは、3000、5173、8000、8080のような同じいくつかのポートで起動します。
1台のマシンで複数のプロジェクトを動かすと、2つ目が「address already in use」で失敗するか、黙って別のポートへ移り、そのポートを次のプロジェクトが取ろうとします。
このプラグインは、どのプロジェクトがどのポートを使うかを1つの一覧に記録し、今それぞれのポートを何が使っているかを示し、よく使われる既定のポートを避けた空きポートを提案し、プロジェクトの`.env.local`とDocker Composeのoverrideにポートを書きます。
一覧とプロジェクトのファイルは、示した変更をあなたが承認した後にだけ変えます。

```
ポートを見る ──> 空きポートを選ぶ ──> 登録する ──> プロジェクトに書く
 (エージェント)    (あなた)            (エージェント)  (承認の後にエージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install portman@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add portman@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install portman@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/portman/skills/portman   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「3000番ポートがもう使われている」「新しいプロジェクトに、ほかと重ならないポートを割り当てて」「自分のプロジェクトはどのポートを使っている？」のように、ポートで困った時に始まります。
呼び出して始めることもできます。Claude Codeでは`/portman:portman`を実行し、Codexでは`$`を入力して**Portman**を選びます。
GitHub Copilot CLIでは依頼の中に`/portman`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、登録したポートと、今それぞれを何が使っているかを見せます
2. 新しいプロジェクトでは、エージェントが空きポートを提案し、あなたが1つ選ぶと、エージェントが登録します
3. ポートが使われている時は、どのプログラムかコンテナが使っているか、それがそのプロジェクト自身かをエージェントが伝えます
4. エージェントが、プロジェクトの`.env.local`とComposeのoverrideに書く内容を見せ、あなたが承認すると書きます
5. ポートを外す時は、エージェントが対象を見せ、あなたが承認すると外します

一覧は次のようになります。

```text
project  name  port  state
shop     web   3101  in use: pid 4242 node (this project)
shop     db    5433  in use: container shop-db-1 (this project)
blog     app   3102  in use: pid 5120 node (another program)
blog     api   3103  free
```

`this project`は、プロジェクトのフォルダで動いているプロセスか、プロジェクトのComposeプロジェクトのコンテナであることを表します。
`another program`は衝突です。ほかの何かがプロジェクトのポートを取っています。

全体の確認は次のようになります。

```text
Registry    ~/.local/share/portman/registry.json, 2 projects, 4 ports
Listeners   read with lsof, which names only your own programs; other ports are tested one by one
Docker      running

[Duplicates] none

[Collisions] 1
  blog/app  3102  pid 5120 node. Free instead: 3104

[In use by its own project] 2
  shop/web  3101  pid 4242 node
  shop/db  5433  container shop-db-1

[Unregistered] 2 ports in use outside the registry
  5000   pid 611 ControlCenter
  7000   pid 611 ControlCenter

1 problem found.
```

プロジェクトにポートを書く時は、先に変更を見せます。

```text
Project shop, folder ~/projects/shop

.env.local (new file)
  --- .env.local
  +++ .env.local after apply
  @@ -0,0 +1,5 @@
  +# >>> portman >>>
  +PORT=3101
  +PORT_WEB=3101
  +PORT_DB=5433
  +# <<< portman <<<

docker-compose.override.yml (new file)
  --- docker-compose.override.yml
  +++ docker-compose.override.yml after apply
  @@ -0,0 +1,8 @@
  +# Written by portman from its registry. portman apply rewrites this file.
  +services:
  +  web:
  +    ports: !override
  +      - "3101:3000"
  +  db:
  +    ports: !override
  +      - "5433:5432"

Nothing was written. To write these changes, run:
  portman.py apply --project shop --dir '~/projects/shop' --confirm e299b178f6eb
```

## 空きポート

提案するポートは、登録されておらず、このマシンで使われておらず、よく使われる道具が既定で取るポートでもない物です。既定のポートには、3000と3001(Node.jsの開発サーバー)、4200(Angular)、5000と7000(macOSのAirPlayレシーバー)、5173(Vite)、5432(PostgreSQL)、6379(Redis)、8000(Django)、8080などがあります。
こうした既定のポートでも、名前を挙げて頼めばエージェントは提案します。
提案は32768未満に限ります。そこから上は、OSが一時的なポートとして配る範囲です。

## プロジェクトに書く物

`.env.local`には、`# >>> portman >>>`と`# <<< portman <<<`の間の行だけを書きます。`app`という名前のポート(無ければプロジェクトの最初のポート)を表す`PORT`と、登録したポートごとの`PORT_<NAME>`です。
ほかの行は一切変えず、同じ変数をほかの行でも設定している時は、その行を確認画面で示します。
ファイルのほかの行には秘密の値がよく入っているため、確認画面には出しません。

プロジェクトにComposeのファイルがある時は、その隣に`docker-compose.override.yml`のようなoverrideを書き、登録した各ポートをそのサービスで公開します。
Composeはoverrideのポートを元のファイルのポートに足すため、そのままでは古いポートが使われたまま残ります。そこでoverrideは`ports: !override`で置き換えます。これにはDocker Compose 2.24以降が要ります。
portmanが書いていないoverrideは置き換えず、代わりに手で足す行を確認画面に出します。

開発サーバーが`.env.local`からポートを読むかどうかは、道具によって違います。
読まない場合は、ファイルを読み込んだ後に`--port $PORT_APP`のように、コマンドでポートを渡します。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に。macOSかLinuxで動きます |
| `lsof` | ポートを使っているプログラムの名前を出す時。macOSには最初から入っています。無い時、Linuxでは`/proc/net`を読み、ほかのシステムではポートを1つずつ試します。プログラムは名前を出せない物として表示します |
| `docker` | 任意です。入っていて動いている時は、コンテナが公開しているポートの持ち主を示し、入っているComposeのバージョンを確かめます |
| `git` | 任意です。プロジェクトのフォルダを見つける時と、`.env.local`がgitの無視の対象になっていない時に知らせるために使います |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、ポートの試し方、持ち主の見分け方、`apply`が書く物を詳しく載せています。
要点は次のとおりです。

- 台帳、`lsof`(または`/proc/net`)から得る待ち受け中のTCPポート、`docker ps`から得る動いているコンテナを読みます。プロジェクトにポートを書く時は、そのプロジェクトの`.env.local`とComposeのファイルも読みます
- 試すポートで、このマシンの中だけのソケットを開いてすぐ閉じます。データは送りません
- 台帳と、プロジェクトの`.env.local`とComposeのoverrideだけを、示した変更をあなたが承認した後に書きます
- プログラムやコンテナを止めることはなく、ネットワークには何も送りません
- 台帳は`~/.local/share/portman/`に置き、あなただけが読めるようにします。消すまで残ります

## ライセンス

[MIT](LICENSE)
