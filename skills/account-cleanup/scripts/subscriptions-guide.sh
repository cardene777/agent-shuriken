#!/bin/bash
# 有料の契約を見つけるための、開く画面と検索語を出す。
# どの画面も利用者が自分で開いて確かめ、有料のアカウントには候補表で「有料」の印を付ける。
# カードの明細と請求のメールの中身はAIに見せない。このscriptは何も読まず、画面の場所を出すだけ。

cat <<'EOF'
## 有料の契約を見つける画面

| どこで払っているか | 開く画面 |
|---|---|
| App Store (iPhone、Mac) | https://apps.apple.com/account/subscriptions (iPhoneでは 設定 → 自分の名前 → サブスクリプション) |
| Google Play | https://play.google.com/store/account/subscriptions |
| PayPal | https://www.paypal.com/myaccount/autopay/ (自動支払い) |
| クレジットカード | カード会社のアプリかWebの明細で、毎月同じ額が引かれている請求 |

App StoreとGoogle Playで払っている契約は、サービス側でアカウントを消しても止まらない。
AppleかGoogleの画面で先に解約する。

## Gmailで請求のメールを探す

Gmailの検索欄に1行ずつ入れ、出てきたメールの送り主のサービスを書き留める。

| 検索語 | 見つかる物 |
|---|---|
| `領収書 OR ご請求 OR 決済完了 OR お支払い` | 日本のサービスの支払い |
| `自動更新 OR 定期購入 OR サブスクリプション OR 月額` | 日本のサービスの契約の更新 |
| `receipt OR invoice OR "payment received"` | 海外のサービスの支払い |
| `"your subscription" OR renewal OR "will renew"` | 海外のサービスの契約の更新 |

メールの中身はAIに見せず、有料だったサービスに候補表で「有料」の印を付ける。
EOF
