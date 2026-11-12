# Init Projectの仕組み

[English](how-it-works.md) · 日本語

このページでは、プロジェクトの種類とローカルのポートの決め方、Dockerの各テンプレートが書く物、envファイルを1Passwordにつなぐ方法、プラグインが残す物を説明します。
ここに書いたことは全部`skills/init-project/scripts/init_project.py`が行い、Pythonの標準ライブラリと`git`だけを使います。

## コマンド

| コマンド | すること |
|---|---|
| `detect` | フォルダがどの種類のプロジェクトで、何がすでにあるかを表示します。何も書きません |
| `plan` | 行う変更を全部表示し、計画を保存します。プロジェクトには何も書きません |
| `apply <計画のID>` | 変更を1つずつもう一度確かめてから書き、ポートを記録します |
| `discard <計画のID>` | 書かずに計画を消します |
| `ports` | 割り当てたポートを並べます。`--forget <フォルダ>`でそのフォルダのポートを消します |
| `wait --port <番号>` | `http://127.0.0.1:<番号>/`が応答するまで、最大30秒(`--timeout`)待ちます |

どのコマンドも、`--dir`で指定したフォルダか、今いるフォルダを対象にします。

## プロジェクトの種類の見分け方

上から順に見て、最初に当てはまった規則で決めます。

| 種類 | 規則 |
|---|---|
| `smart-contract` | `foundry.toml`がある(Foundry)か、`hardhat.config.js`、`.ts`、`.cjs`、`.mjs`のどれかがある(Hardhat) |
| `cli` | `package.json`に`bin`の項目がある |
| `web-app` | `package.json`に`dev`か`start`のスクリプトがある |
| `library` | それ以外の`package.json` |
| `cli` | `Cargo.toml`に`[[bin]]`の節があるか、`src/main.rs`がある |
| `library` | それ以外の`Cargo.toml` |
| `web-app` | `requirements.txt`か`pyproject.toml`が、`django`、`fastapi`、`flask`、`uvicorn`のどれかを1つの名前として挙げている。そのため`flask-sqlalchemy`だけでは数えません |
| `library` | それ以外の`pyproject.toml`、`requirements.txt`、`setup.py` |
| `unknown` | これらのファイルがどれも無い |

Nodeのプロジェクトでは、次の物も読みます。

| 何を | どこから |
|---|---|
| フレームワーク | `dependencies`か`devDependencies`にある`next`、`nuxt`、`astro`、`vite`のうち最初の物。どれも無ければ素のNodeです |
| パッケージマネージャ | ロックファイルで決めます。`bun.lock`か`bun.lockb`ならbun、`pnpm-lock.yaml`ならpnpm、`yarn.lock`ならyarn、`package-lock.json`ならnpmです。無ければ`packageManager`の項目、それも無ければnpmです |
| Nodeのバージョン | `.nvmrc`か`.node-version`のメジャーバージョン。無ければ24です |
| 開発用のコマンド | `<パッケージマネージャ> run dev`。`dev`のスクリプトが無ければ`run start`です |

Pythonのプロジェクトでは、バージョンを`.python-version`から取り、無ければ3.13にします。
FastAPIのアプリは`main.py`、`app/main.py`、`src/main.py`の順に探し、どれも無ければ`main:app`と推測します。推測した時は`detect`がそう表示します。

## ローカルのポートの選び方

次のうち、最初に当てはまった物でポートが決まります。

1. `--port <番号>`。ほかのプロジェクトに割り当てられていない番号で、すでにこのプロジェクトのポートでない限り、空いている必要があります
2. 計画がそのまま残す、プロジェクトのcomposeのoverrideのファイルにあるポート
3. このプロジェクトのフォルダとサービスに記録したポート
4. `--from`(既定は3100)から上で、空いていて、ほかのプロジェクトに割り当てておらず、よく使われる道具の番号(3000、3001、3306、4000、4200、4321、5000、5173、5432、5672、6379、8000、8080、8443、8545、8888、9000、9090、9200、27017)でもない最初のポート

`127.0.0.1`と`::1`への接続に何も応答せず、`0.0.0.0`、`127.0.0.1`、`::`で一瞬だけ待ち受けられる時に、ポートが空いていると見ます。
新しく選んだポートと指定されたポートは、`apply`が書く直前にもう一度確かめます。使われ始めていたり、ほかに割り当てられていたりすれば、overrideのファイルと記録を飛ばします。

ポートはプラグインのフォルダの`ports.json`に、フォルダ、サービス、ポートの一覧として、形式のバージョンとともに記録します。
形式のバージョンが違う記録は読まずに断ります。間違った情報でポートを選ばないためです。

## Dockerのファイル

| プロジェクト | Dockerfile | コンテナの中のコマンド | コンテナの中のポート |
|---|---|---|---|
| NodeのWebアプリ | `node:<バージョン>-alpine`。bunなら`oven/bun:1`です。プロジェクトのパッケージマネージャで依存を入れます。pnpmは先に入れ、`packageManager`が版を挙げていればその版にします。yarnはイメージに無い時だけ入れます | `dev`か`start`のスクリプトです。`dev`のスクリプトでは、コンテナの外から届くよう、Vite、Astro、Nuxtに`--host 0.0.0.0`を付けます | Next.jsとNuxtは3000、Astroは4321、Viteは5173、ほかは3000 |
| PythonのWebアプリ | `python:<バージョン>-slim`。`requirements.txt`を入れるか、`pip install -e .`でプロジェクト自体を入れます | `uvicorn <アプリ> --host 0.0.0.0 --port 8000 --reload`、`flask run --host 0.0.0.0 --port 5000 --debug`、`python manage.py runserver 0.0.0.0:8000`のどれか | 8000。Flaskは5000 |
| Hardhat | 上と同じNodeのイメージ | `npx hardhat node --hostname 0.0.0.0`。bunなら`bunx`です | 8545 |
| Foundry | ありません。composeのファイルが`ghcr.io/foundry-rs/foundry:latest`を使います | `anvil --host 0.0.0.0` | 8545 |

| ファイル | 中身 |
|---|---|
| `Dockerfile` | 上の表のとおりです。依存を入れる前に、プロジェクト全体を`/app`に写します |
| `.dockerignore` | `.git`、`.env`、`.env.*`、`*.log`、`.DS_Store`。Nodeでは`node_modules/`、`dist/`、`.turbo/`(Next.jsは`.next/`と`out/`、Hardhatは`artifacts/`、`cache/`、`typechain-types/`を足します)、Pythonでは`__pycache__/`、`*.pyc`、`.venv/`、`venv/` |
| `docker-compose.yml` | サービスを1つ持ちます。名前は`app`、ローカルのチェーンなら`chain`です。プロジェクトのフォルダから組み立て、`/app`にマウントし、Nodeでは`node_modules`をコンテナの中に残します。FoundryのサービスはFoundryのイメージを動かします。NodeのWebアプリには`NODE_ENV=development`を付け、Foundry以外のサービスには、同じ計画が1Passwordにつなぐ、プロジェクトの直下のenvファイルの名前を並べます。`op run`が値を渡せるようにするためです。ポートは書きません |
| `docker-compose.override.yml` | サービスのポートを`127.0.0.1:<ローカルのポート>:<コンテナの中のポート>`の形で書きます |

`compose.yaml`、`compose.yml`、`docker-compose.yml`、`docker-compose.yaml`のどれかがあれば、composeのファイルがあると見ます。overrideのファイルはその名前に合わせ、`compose.yaml`の隣なら`compose.override.yaml`にします。
composeのファイルがあり、`--overwrite`で名前を挙げていない時は、それを残します。`Dockerfile`と`.dockerignore`は、どちらかを`--overwrite`で挙げた時だけ計画に入れます。
その時のoverrideのファイルは、`--service`で指定したサービス、composeのファイルにあればテンプレートのサービス、サービスが1つだけならそのサービスに向けます。複数あって`--service`が無ければ、`plan`は止まってサービスの名前を並べます。
コンテナの中のポートは、`--container-port`かテンプレートから取ります。

## すでにあるファイル

| 状態 | 計画がすること |
|---|---|
| ファイルが無い | `[create]`で全文を見せます |
| ファイルがある | `[skip]`でそのまま残します |
| ファイルがあり、`--overwrite`で名前を挙げた | `[overwrite]`で差分を見せます。挙げられるのは`Dockerfile`、`.dockerignore`、composeのファイル、overrideのファイルだけで、envファイルは決して挙げられません |
| `.gitignore`か`.tpl`のファイルがある | `[append]`で足りない行だけを見せます |

計画のファイルには、新しいファイルと置き換えるファイルの全文を入れます。置き換えるファイルと行を足すファイルについては、今の中身のSHA-256のハッシュだけを入れます。
`apply`は、新しいファイルならまだ無い時だけ、置き換えるファイルと行を足すファイルならハッシュが同じ時だけ書きます。そうでなければ理由を添えて飛ばします。
新しいファイルは既存のパスをたどらずに作り、置き換えるファイルは権限をそのまま残し、行はファイルの末尾に足します。

## envファイルを1Passwordにつなぐ

envファイルは、プロジェクトのフォルダと、`apps/`と`packages/`の下の各フォルダにある、`.env`と`.env.<名前>`のファイルです。
名前が`.tpl`、`.example`、`.sample`、`.template`、`.dist`、`.defaults`、`.schema`、`.vault`、`.keys`で終わるファイルは除きます。慣習として値を持たないためです。

各ファイルから、`NAME=`か`export NAME=`の形の行の名前を取ります。名前は英字、数字、`_`でできた物です。
行の残りは、引用符で囲んだ値がどこで終わるかを見つけるためだけに見ます。秘密鍵のような複数行の値の行を、名前と取り違えないためです。
値はどの部分も表示、保存、送信しません。

| 何を | 規則 | `packages/api/.env.dev`の例 |
|---|---|---|
| テンプレート | envファイルのパスに`.tpl`を足した物 | `packages/api/.env.dev.tpl` |
| セクション | 先頭の点を除いたパスで、英字、数字、`_`、`-`以外の文字を`_`にした物 | `packages_api_env_dev` |
| 参照 | `op://<保管庫>/<アイテム>/<セクション>/<NAME>`。空白を含む時は二重引用符で囲みます | `JWT_SECRET=op://Personal/shop/packages_api_env_dev/JWT_SECRET` |
| フィールドの種類 | `PORT`、`HOST`、`HOSTNAME`、`NODE_ENV`、`APP_ENV`、`ENV`、`LOG_LEVEL`、`TZ`、`DEBUG`、`_PORT`、`_HOST`、`_HOSTNAME`、`_REGION`で終わる名前、`NEXT_PUBLIC_`、`NUXT_PUBLIC_`、`VITE_`、`PUBLIC_`、`EXPO_PUBLIC_`、`REACT_APP_`で始まる名前は`text`です。ほかの名前は全部`concealed`です | `concealed` |

アイテムの名前は、`--item`が無ければプロジェクトのフォルダの名前にします。
参照が働くよう、保管庫とアイテムの名前に使えるのは英字、数字、空白、`.`、`_`、`-`です。ほかの文字を含む名前には、保管庫のIDを使います。
`.tpl`のファイルがすでにある時は、同じ方法で名前を読み、足りない名前だけを足します。
`op`が入っていない時、`--env`は終了コード3で止まります。`op`が無ければ参照は役に立たないためです。ただし、スクリプト自体は`op`を動かしません。

計画は、bashかzshであなたが動かすコマンドを表示します。最初の行でプロジェクトのフォルダに`cd`します。

```bash
cd ~/projects/shop
op item get shop --vault Personal >/dev/null 2>&1 || op item create --vault Personal --category 'Secure Note' --title shop --tags env >/dev/null
( set -a; . ./.env; set +a; op item edit shop --vault Personal "env.DATABASE_URL[concealed]=${DATABASE_URL-}" >/dev/null )
```

`op item get`の行は、アイテムが無い時に作ります。
その次の行は、envファイルを1つずつサブシェルで読み込み、値を`op item edit`に渡します。値は表示されずにファイルから1Passwordへ渡り、シェルの履歴には名前だけが残ります。
ファイルの読み込みは、`source .env`と同じくシェルのコードとして動かします。シェルとして正しくないファイルは、代わりに1Passwordのアプリでフィールドを足します。
エージェントはこれらのコマンドを動かしません。

## .gitignore

計画は、`# Added by init-project`の行の下に、次の行を`.gitignore`に足します。ファイルが無ければ作ります。

| 行 | 理由 |
|---|---|
| つなぐ各envファイル。例えば`.env` | 値をgitに入れないため |
| `!`と各`.tpl`のファイル。例えば`!.env.tpl` | `.env*`のような規則が参照を無視してしまう時も、gitに入れるため |
| overrideのファイル | 手元のポートをgitに入れないため |

gitのリポジトリの中では、`git check-ignore --no-index`がファイルを逆の状態と示した時だけ行を足します。プロジェクトの無視の設定を読み、ほかの人と共有しないあなた全体の無視の設定は除いて判定します。
gitのリポジトリの外では、同じ行がまだ無い時に足します。
gitがすでに追跡しているenvファイルは、追跡されたままです。計画はそのファイルを名指しし、値が履歴に残っているのでキーを取り替えるよう勧めます。

## 残す物

| 何を | どこに | いつまで |
|---|---|---|
| 割り当てたポートと、そのプロジェクトのフォルダとサービス | `~/.local/share/init-project/ports.json`。`INIT_PROJECT_HOME`があればその下です。あなただけが読めるフォルダに置きます | `ports --forget <フォルダ>`で消すか、ファイルを消すまで |
| 適用を待つ計画。計画したファイルの中身、既存のファイルのハッシュ、ポート、次の手順 | `~/.local/share/init-project/plans/<計画のID>.json`。あなただけが読めます | `apply`か`discard`、同じフォルダの新しい計画、または1日のどれかまで |

プロジェクトに書くファイルは、計画ごとに並べ、`apply`だけが書きます。

## しないこと

- envファイルの値を読む、表示する、保存する、送ること
- `op`を動かすこと、値を貼り付けるよう頼むこと
- 計画の後に変わったファイルを置き換えたり行を足したりすること、名前を挙げていない既存のファイルを置き換えること、envファイルを置き換えること
- プロジェクトのファイルを消すこと
- `127.0.0.1`と`::1`以外に接続すること。リポジトリを読むために動かすのは`git rev-parse`、`git check-ignore`、`git ls-files`だけです

## 環境変数

| 変数 | 用途 |
|---|---|
| `INIT_PROJECT_HOME` | ポートと計画を置く場所 |
| `INIT_PROJECT_OP` | 検査で、`PATH`の`op`の代わりに確かめるパス |
| `INIT_PROJECT_DOCKER` | 検査で、`PATH`の`docker`の代わりに確かめるパス |
