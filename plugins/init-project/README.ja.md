# Init Project

プロジェクトを手元で動かす準備をします。空いているローカルのポート、Dockerの設定、1Passwordにつないだenvファイルを用意し、どのファイルも書く前に見せます。

[English](README.md) · 日本語

プロジェクトを始めるたびに、同じ手間がかかります。
ほかのプロジェクトとぶつからないポートを選び、Dockerfileとcomposeのファイルを書き、手元だけの物をgitに入れないようにし、本物のキーを平文の`.env`ファイルに置かないようにします。
このプラグインは、その手間を3つの部分に分けて引き受けます。まとめてでも、1つずつでも使えます。
書くファイルを全部見せ、あなたが承認してから書き、すでにあるファイルは、名前を挙げて置き換えを頼まない限りそのまま残します。
秘密の値はエージェントを通りません。エージェントは`op://`の参照を書き、値はあなたが自分の端末で動かすコマンドで保存します。

```
プロジェクトを見る ──> 何を用意するか尋ねる ──> 計画を見せる ──> 承認の後に書く ──> 値を1Passwordに保存する
 (エージェント)        (エージェントとあなた)    (エージェント)   (エージェント)     (あなたが自分の端末で)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install init-project@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add init-project@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install init-project@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/init-project/skills/init-project   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「このプロジェクトをDocker付きで準備して」「このリポジトリにDockerを足して」「.envを1Passwordに移して」のように、プロジェクトの準備を頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/init-project:init-project`を実行し、Codexでは`$`を入力して**Init Project**を選びます。
GitHub Copilot CLIでは依頼の中に`/init-project`と書き、Gemini CLIではやりたいことを伝えます。

| モード | 使う時 | 用意する部分 |
|---|---|---|
| `new` | プロジェクトを準備する時 | ポート。望めばDockerと1Passwordも |
| `add-docker` | 今あるプロジェクトにDockerを足す時 | Dockerとそのポート |
| `add-1password` | envファイルを1Passwordにつなぐ時 | 1Password |

1. エージェントがプロジェクトを見ます。種類、パッケージマネージャ、Dockerのファイル、envファイルを調べます。envファイルからは変数の名前だけを読みます
2. エージェントがどの部分を用意するか尋ねます。1Passwordを選んだ時は、値を置く保管庫(vault)も尋ねます
3. エージェントが計画を見せます。新しいファイルは全文を、今あるファイルには足す行を、残すファイルとその理由を、ローカルのポートを見せます
4. あなたが承認すると、エージェントがファイルを書きます。書く直前に、ファイルとポートをもう一度確かめます
5. Dockerを用意した時は、エージェントがプロジェクトを起動して応答を確かめるか尋ねます
6. 1Passwordを用意した時は、表示されたコマンドをあなたが自分の端末で動かして値を保存し、`op run`でアプリを起動します

pnpmを使うNext.jsのプロジェクトで、`.env`ファイルが1つあり、Next.jsが作る物と同じく`.env*`を無視する`.gitignore`がある時の計画は次のようになります。

```text
Plan 2760c3b6 for ~/projects/shop
  project  shop, web-app (next, pnpm)
  port     3100 for the app service (free)
  1Password vault Personal, item shop

[create] Dockerfile
    # Development image for shop, written by init-project.
    FROM node:24-alpine
    WORKDIR /app
    RUN npm install -g pnpm@9.12.0
    COPY . .
    RUN pnpm install
    EXPOSE 3000
    CMD ["pnpm", "run", "dev"]

[create] .dockerignore
    # Files kept out of the Docker build, written by init-project.
    .git
    .env
    .env.*
    *.log
    .DS_Store
    node_modules/
    dist/
    .turbo/
    .next/
    out/

[create] docker-compose.yml
    # Development services for shop, written by init-project.
    # The local port is set in docker-compose.override.yml, which stays out of git.
    services:
      app:
        build: .
        volumes:
          - .:/app
          - /app/node_modules
        environment:
          - NODE_ENV=development
          - DATABASE_URL
          - STRIPE_SECRET_KEY
          - NEXT_PUBLIC_SITE_URL

[create] docker-compose.override.yml
    # Local port for this machine, written by init-project. Keep it out of git.
    services:
      app:
        ports:
          - "127.0.0.1:3100:3000"

[create] .env.tpl
    # 1Password references for .env, written by init-project.
    # It holds no values, so it can be committed. Start the app with:
    #   op run --env-file .env.tpl -- pnpm run dev
    DATABASE_URL=op://Personal/shop/env/DATABASE_URL
    STRIPE_SECRET_KEY=op://Personal/shop/env/STRIPE_SECRET_KEY
    NEXT_PUBLIC_SITE_URL=op://Personal/shop/env/NEXT_PUBLIC_SITE_URL

[append] .gitignore
    + # Added by init-project
    + !.env.tpl
    + docker-compose.override.yml

After writing:
  Start it with: docker compose up --build
  Then open: http://localhost:3100
  Put the values into 1Password from your own terminal (bash or zsh). These commands read each env file in a subshell and print nothing:
    cd ~/projects/shop
    op item get shop --vault Personal >/dev/null 2>&1 || op item create --vault Personal --category 'Secure Note' --title shop --tags env >/dev/null
    ( set -a; . ./.env; set +a; op item edit shop --vault Personal "env.DATABASE_URL[concealed]=${DATABASE_URL-}" "env.STRIPE_SECRET_KEY[concealed]=${STRIPE_SECRET_KEY-}" "env.NEXT_PUBLIC_SITE_URL[text]=${NEXT_PUBLIC_SITE_URL-}" >/dev/null )
  Then start the app with: op run --env-file .env.tpl -- pnpm run dev
  Or in Docker: op run --env-file .env.tpl -- docker compose up
  Once that works, the plain env files are no longer needed. They still hold the values until you delete them.

Nothing has been written. To write these files, run: init_project.py apply 2760c3b6
```

## ポート

このプラグインは、3100から上で、手元のマシンで何も待ち受けておらず、3000、5173、8000、8080のようなよく使われる道具の番号でもなく、このプラグインで準備したほかのプロジェクトにも割り当てていないポートを選びます。
選んだポートを記録するので、次のプロジェクトには別のポートが割り当たります。同じプロジェクトでもう一度動かすと、同じポートを使います。
ポートを指定することも、探し始める番号を指定することもできます。
ポートは`127.0.0.1`だけで開くので、同じネットワークのほかのマシンからは開発用のサーバーに届きません。
記録の対象は、このプラグインで準備したプロジェクトです。すべてのプロジェクトをまたいだポートの台帳は、portmanのプラグインが持ちます。

## Dockerのテンプレート

| プロジェクト | ファイルが動かす物 | コンテナの中のポート |
|---|---|---|
| NodeのWebアプリ(Next.js、Nuxt、Astro、Vite、または`dev`か`start`のスクリプトを持つアプリ) | npm、pnpm、yarn、bunのどれかで`dev`か`start`のスクリプト | 3000。Astroは4321、Viteは5173 |
| PythonのWebアプリ(FastAPI、Flask、Django) | uvicorn、`flask run`、`manage.py runserver`のどれか。変更があると読み直します | 8000。Flaskは5000 |
| Hardhat | ローカルのチェーンを動かす`hardhat node` | 8545 |
| Foundry | Foundryのイメージから、ローカルのチェーンを動かす`anvil` | 8545 |

composeのファイルにはポートを書かないので、コミットできます。overrideのファイルに手元のポートを書き、gitには入れません。
プロジェクトにすでにcomposeのファイルがある時は、それを残し、指定したサービスのためのoverrideのファイルだけを足します。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | gitがすでに無視しているファイルと、コミットされているenvファイルを調べる時に使います。gitのリポジトリの外では、`.gitignore`の行を文字列のまま比べます |
| `docker` | Dockerの設定を動かす時に使います。ファイルを書くだけなら要りません |
| `op`(1PasswordのCLI) | 1Passwordの部分で、あなたのアカウントにサインインした状態で使います。無くても、ほかの部分は動きます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、プロジェクトの種類とポートの決め方、各テンプレートが書く物、envファイルのつなぎ方を載せています。
要点は次のとおりです。

- プロジェクトの`package.json`や`pyproject.toml`などの定義ファイル、Dockerのファイル、`.gitignore`と、envファイルの変数の名前だけを読みます。値は表示も保存も送信もしません
- 無視されているファイルとコミットされているファイルを読むために`git`を動かし、ポートを一瞬だけ待ち受けて空きを確かめ、`127.0.0.1`にだけ接続します。`op`は動かさず、インターネットにも接続しません
- プロジェクトの起動に同意すると、エージェントが`docker compose up -d --build`を動かし、元になるイメージと依存するパッケージをダウンロードします
- 1Password用のコマンドは、あなたが自分の端末で動かし、あなた自身のサインインで値を1Passwordに送ります
- 割り当てたポートとそのプロジェクトのフォルダ、承認を待つ計画(長くて1日)だけを`~/.local/share/init-project/`に置き、あなただけが読めるようにします

## ライセンス

[MIT](LICENSE)
