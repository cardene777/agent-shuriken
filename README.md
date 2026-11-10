# agent-shuriken

自分で作ったAIの技 (スキル) を集めた置き場です。
技の形は`SKILL.md`を持つフォルダで、Claude CodeとCodexのどちらでも読み込めます。

## 技の一覧

| 技 | 何をするか |
|---|---|
| [`account-cleanup`](skills/account-cleanup/SKILL.md) | 使わなくなったWebサービスのアカウントを、パスワードを読まずに洗い出し、解約と削除まで進める |

## 入れ方

### Claude Code

Claude Codeで次を打ちます。

```
/plugin install account-cleanup --marketplace cardene777/agent-shuriken
```

Claude Codeが2.1.275より前の時は、2行に分けて打ちます。

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install account-cleanup@agent-shuriken
```

### Codex

技のフォルダを`~/.codex/skills/`の下へ写すと、Codexが読み込みます。

```
git clone git@github.com:cardene777/agent-shuriken.git
cp -R agent-shuriken/skills/account-cleanup ~/.codex/skills/
```

## account-cleanup

使わなくなったWebサービスのアカウントを洗い出し、要らない物を解約して削除するまでを進めます。
1Password、Bitwarden、Chromeの保存パスワードから、パスワードを読まずにサービスの名前とURLと日付だけを集めます。
どのサービスに登録したか、どれが有料かを覚えていなくても使えます。

```
洗い出し ─> 理由と説明を付ける ─> 候補表でOKかダメか ─> OKの物から解約と削除 ─> パスワード管理を片付ける
 (AI)        (AI)                  (あなた)              (AI。二要素と回の承認はあなた)  (AI、戻せる形で)
```

### パスワードを読まない仕組み

| 出所 | 読む物 | 読まない物 |
|---|---|---|
| 1Password | 洗い出しでは`op item list`が返す名前、URL、更新日 | 洗い出しでは`op item get`を呼ばない。ログインでは`browser.sh login`が`op item get`で読んだ値を入力欄へ直に入れ、AIにもファイルにも渡さない |
| Bitwarden | `bw list items`の名前、URL、更新日 | パスワード、ユーザー名、メモはscriptの中で捨て、ファイルにもAIにも渡さない |
| Chrome | 保存パスワードの記録の写しの`origin_url`と日付 | パスワードの列は選ばない。写しは読み終えたら消す |
| Google、Apple、GitHubの連携とGmail | 開く画面と検索語を案内するだけ | 画面とメールの中身はAIに見せない |

ログインのIDとパスワードは、開いているページのドメインが1Passwordの項目のURLのドメインと一致した時だけ、scriptが入力欄へ入れます。
URLを持たない項目は、調べた公式のドメインを`--site`で名指した時だけ、そのドメインのページへ入れます。
AIが読む画面の情報からは入力欄の値を全部消すので、AIはパスワードを受け取りません。
二要素の確認と画像認証はあなたがブラウザの窓で行います。
最後の削除ボタンと解約ボタンは、削除を始める前にあなたがその回の分を1回承認した後にだけAIが押します。
AIがブラウザで行うのは、ログインの入力、支払いの確認、解約、支払い先の削除、アカウントの削除だけです。
候補のファイルと候補表は`~/.local/share/account-cleanup/`に、あなただけが読める権限で置き、整理が終わったら消します。
候補表のHTMLは外から何も読み込みません。

### 使い方

Claude Codeで`/account-cleanup:account-cleanup`を打つか、「使っていないアカウントを整理したい」と頼みます。

1. 洗い出す出所を選びます
2. AIが、長く更新していない物、サイトが無くなった物などに理由を付け、何のサイトかの短い説明を書いた候補表を開きます
3. 候補表で、行ごとに消してよければ「OK」、残すなら「ダメ」を押し、「OKの分をコピー」を押してチャットに貼ります
4. AIが、App Store、Google Play、PayPalの契約の一覧を1回開き、そこで払っている契約を先に解約します
5. 始める前に、その回に消す件数をあなたが1回承認します
6. AIが、OKの物から順に、1Passwordからログインを入れ、有料の契約を解約し、登録したカードと口座を消してからアカウントを削除します。二要素の確認はあなたが行います。消せなかった支払い先は、最後に一覧の画面で見せます
7. サイトが無くなった物と終了したサービスは削除を飛ばし、削除できないサービスには個人情報保護法に基づく消去の請求文を出します
8. 「終わった」と言うと、消した分の項目を、1Passwordはアーカイブへ、Bitwardenはごみ箱へまとめて移します

### 必要な物

| 物 | 要る時 |
|---|---|
| `jq` | いつも |
| Node.js | AIがブラウザで削除を進める時。初めて使う時に、ブラウザを動かす道具 (Playwright) とChromiumを置き場へ入れる |
| `sqlite3` | Chromeから洗い出す時 |
| `op` (1Password CLI) | 1Passwordから洗い出す時。1Passwordのアプリの設定で命令との連携をオンにする |
| `bw` (Bitwarden CLI) | Bitwardenから洗い出す時。AIを起動する前に端末で`export BW_SESSION="$(bw unlock --raw)"`を打つ |

### 同梱の削除ページの一覧

`skills/account-cleanup/data/sites.json`は、JustDeleteMeの公開データ (MIT) をそのまま写した物です。
出どころと利用許諾は[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)に書きました。
一覧に無いサービスは、AIが検索して見つけた削除ページを`~/.local/share/account-cleanup/additions.json`に足し、次からはそこを引きます。
