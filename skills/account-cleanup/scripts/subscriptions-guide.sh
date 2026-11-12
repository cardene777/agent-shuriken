#!/bin/bash
# Print the pages to open and the search terms for finding paid subscriptions.
# The user opens and checks every page themselves, and tells the AI which services they pay for.
# Card statements and the contents of billing emails are never shown to the AI. This script reads nothing; it only prints where to look.
# The Japanese search terms find billing emails from Japanese services, so they stay in Japanese.

cat <<'EOF'
## Pages that list paid subscriptions

| Where you pay | Page to open |
|---|---|
| App Store (iPhone, Mac) | https://apps.apple.com/account/subscriptions (on iPhone: Settings → your name → Subscriptions) |
| Google Play | https://play.google.com/store/account/subscriptions |
| PayPal | https://www.paypal.com/myaccount/autopay/ (automatic payments) |
| Credit card | Charges of the same amount every month, in your card company's app or online statement |

Subscriptions paid through the App Store or Google Play do not stop when you delete the account on the service.
Cancel them on Apple's or Google's page first.

## Finding billing emails in Gmail

Enter one line at a time in the Gmail search box and note the service that sent each email you find.

| Search terms | What it finds |
|---|---|
| `receipt OR invoice OR "payment received"` | Payments to English-language services |
| `"your subscription" OR renewal OR "will renew"` | Subscription renewals at English-language services |
| `領収書 OR ご請求 OR 決済完了 OR お支払い` | Payments to Japanese services |
| `自動更新 OR 定期購入 OR サブスクリプション OR 月額` | Subscription renewals at Japanese services |

Do not show the email contents to the AI; tell it only which services you were paying for.
EOF
