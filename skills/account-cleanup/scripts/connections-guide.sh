#!/bin/bash
# パスワードを保存せずに作った登録を探すための、開く画面と検索語を出す。
# どの画面も利用者が自分で開いて確かめ、見つけたサービスを add-candidate.sh で候補に足す。
# このscriptは何も読まず、画面の場所を出すだけ。

cat <<'EOF'
## Google、Apple、GitHubでログインしたサービス

| どこ | 開く画面 | 見る所 |
|---|---|---|
| Google | https://myaccount.google.com/connections | 「サードパーティ製のアプリとサービス」に出るサービス |
| Apple | https://account.apple.com/ | 「サインインとセキュリティ」の「Appleでサインイン」に出るサービス (iPhoneでは 設定 → 自分の名前 → サインインとセキュリティ → Appleでサインイン) |
| GitHub | https://github.com/settings/applications | 「Authorized OAuth Apps」に出るサービス |
| GitHub | https://github.com/settings/apps/authorizations | 「Authorized GitHub Apps」に出るサービス |

## Gmailで登録のメールを探す

Gmailの検索欄に1行ずつ入れ、出てきたメールの送り主のサービスを書き留める。

| 検索語 | 見つかる物 |
|---|---|
| `ご登録ありがとうございます` | 日本のサービスの登録の完了 |
| `会員登録 OR アカウント登録 OR 仮登録` | 日本のサービスの登録の手続き |
| `メールアドレスの確認 OR メールアドレス確認` | 登録の時に届く確認のメール |
| `"verify your email" OR "confirm your email"` | 海外のサービスの登録の確認 |
| `"welcome to" OR "thanks for signing up"` | 海外のサービスの登録の完了 |
| `"your account has been created"` | 海外のサービスの登録の完了 |

Gmail以外のメールでも、同じ語で検索できる。
メールの中身はAIに見せず、サービスの名前とURLだけを伝える。
EOF
