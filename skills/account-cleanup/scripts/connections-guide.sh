#!/bin/bash
# Print the pages to open and the search terms for finding sign-ups that never saved a password.
# The user opens and checks every page themselves, and adds the services they find with add-candidate.sh.
# This script reads nothing; it only prints where to look.
# The Japanese search terms find sign-up emails from Japanese services, so they stay in Japanese.

cat <<'EOF'
## Services you signed in to with Google, Apple or GitHub

| Where | Page to open | What to look at |
|---|---|---|
| Google | https://myaccount.google.com/connections | Services listed under "Third-party apps & services" |
| Apple | https://account.apple.com/ | Services listed under "Sign-In and Security" → "Sign in with Apple" (on iPhone: Settings → your name → Sign-In & Security → Sign in with Apple) |
| GitHub | https://github.com/settings/applications | Services listed under "Authorized OAuth Apps" |
| GitHub | https://github.com/settings/apps/authorizations | Services listed under "Authorized GitHub Apps" |

## Finding sign-up emails in Gmail

Enter one line at a time in the Gmail search box and note the service that sent each email you find.

| Search terms | What it finds |
|---|---|
| `"verify your email" OR "confirm your email"` | Sign-up confirmations from English-language services |
| `"welcome to" OR "thanks for signing up"` | Completed sign-ups at English-language services |
| `"your account has been created"` | Completed sign-ups at English-language services |
| `ご登録ありがとうございます` | Completed sign-ups at Japanese services |
| `会員登録 OR アカウント登録 OR 仮登録` | Sign-up steps at Japanese services |
| `メールアドレスの確認 OR メールアドレス確認` | Email confirmations sent during sign-up at Japanese services |

The same terms work in email services other than Gmail.
Do not show the email contents to the AI; tell it only the service names and URLs.
EOF
