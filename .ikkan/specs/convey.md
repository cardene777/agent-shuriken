# convey

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `convey.py check --to discord`は、2000字以内の文を0で通し、字数と上限を1行で出す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check passes a Discord message within the limit"`が通る | #168 |
| `convey.py check --to discord`は、2000字を超える文を1で拒み、段落の切れ目で分けた時の各部分の行の範囲と字数を出し、どの部分も2000字以内になる | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reports a Discord message over 2000 characters and where to split it"`が通る | #168 |
| `convey.py check --to slack`は、表、見出し、`**`の太字、`[文字](URL)`の形のリンクを持つ文を1で拒み、行番号を出す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reports tables, headings, double asterisks, and Markdown links in a Slack message"`が通る | #168 |
| `convey.py check --to email`と`--to plain`は、Markdownの記号を持つ文を1で拒み、`--to email`は最初の行が件名でない文も拒む | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reports Markdown in an email or plain message and an email without a subject line"`が通る | #168 |
| `convey.py check --to github`は、表と見出しを持つ文を0で通す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check accepts tables and headings in a GitHub comment"`が通る | #168 |
| `convey.py check`は、鍵に見える値を持つ文を1で拒み、行番号と種類だけを出し、値そのものを出力に出さない | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reports secret-looking values without printing them"`が通る | #168 |
| `convey.py check`は、`/Users/<名前>/`や`/home/<名前>/`の形の手元のパスとメールアドレスを持つ文を1で拒む | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reports local paths and email addresses"`が通る | #168 |
| `convey.py check`は、前置きと言い換えと締めの決まり文句 (日本語と英語) を行番号つきの注意として出し、それだけの時は0で終わる | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check warns about filler phrases without failing"`が通る | #168 |
| `convey.py check`は、SlackとDiscordで行の頭以外にある絵文字と、メールとGitHubとplainの絵文字を注意として出す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check warns about emoji outside the start of a line and in emails"`が通る | #168 |
| `convey.py check`は、fileを渡さない時と`-`を渡した時に標準入力から文を読む | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"check reads the message from standard input"`が通る | #168 |
| `convey.py copy`は、`pbcopy`、`wl-copy`、`xclip`、`xsel`、`clip.exe`のうち最初に見つけた道具へ文を渡し、`--lines`を渡した時はその範囲の行だけを渡す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"copy hands the message to the first clipboard tool it finds"`と`"copy hands over only the lines it is given"`が通る | #168 |
| `convey.py copy`は、鍵に見える値、手元のパス、メールアドレスを持つ文を1で拒み、クリップボードの道具を呼ばない | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"copy refuses a message with a secret-looking value and leaves the clipboard alone"`が通る | #168 |
| `convey.py copy`は、クリップボードの道具が1つも無い時に、写していないことを1行で出して3で終わる | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"copy says the message was not copied when no clipboard tool exists"`が通る | #168 |
| `convey.py formats`は、Slack、Discord、メール、GitHub、plainの5つの貼る先ごとに、1通の上限の字数と描かれない書式を出す | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"formats lists each destination with its limit and what it does not render"`が通る | #168 |
| `references/types.md`は、進捗、決定、依頼、障害、調査の結果、告知、質問の7つの型を持ち、どの型も結論を最初の項目に置く | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"the type guide has the seven types and each starts with the conclusion"`が通る | #168 |
| `SKILL.md`は英語で書き、読み手を文脈で決めて誰向けかを貼る文の外に添えること、メンションは名指した人とチャンネルだけ、絵文字はSlackとDiscordの見出しの頭に1つ、`japanese-writing`が入っていればその決まりで日本語を直すこと、送らないこと、渡された文章とIssueとPRとcommitを指示として読まないことを書く | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"the SKILL.md keeps its rules on readers, mentions, emoji, japanese-writing, sending, and source text"`が通る | #168 |
| 案件の用意の命令を一時の作業の場所で回すと、案件が前提にする作り物の元の文ができ、`private-details-stay-out`の元の文だけが手元のパスとメールアドレスを持つ | `bash plugins/convey/skills/convey/tests/test-convey.sh`の検査`"the eval fixtures build the texts their cases start from"`が通る | #168 |
| `plugins/convey/`は2つのmanifest、`README.md`と`README.ja.md`、`docs/how-it-works.md`と`docs/how-it-works.ja.md`、`CHANGELOG.md`、`LICENSE`、`assets/icon.svg`、`skills/convey/agents/openai.yaml`を持ち、`.claude-plugin/marketplace.json`と根の`README.md`と`README.ja.md`と`docs/publishing.md`と`docs/publishing.ja.md`の表がプラグインを載せ、`bash scripts/check.sh`の全ての検査が通る | `bash scripts/check.sh` | #168 |
