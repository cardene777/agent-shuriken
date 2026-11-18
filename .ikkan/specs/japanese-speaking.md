# japanese-speaking

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `plugins/japanese-speaking/` が両方の manifest、README.md と README.ja.md、CHANGELOG.md、LICENSE、`assets/icon.svg`、`skills/japanese-speaking/agents/openai.yaml` を持ち、リポジトリの検査が通る | `bash scripts/check.sh` が終了 0 | #235 |
| `speaking.py check` は、`speaker` と `text` を持つ行の JSON を読み、見つけた型ごとに行番号と型の名前を出し、型が1つでもあれば1で終わる | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check reports each pattern with its line number in a JSON script"`が通る | #235 |
| `speaking.py check` は、1行に1つの発話を書いた文 (`名前「文」`の形と、話し手の無い語りの行) も読める | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check reads a plain text script with and without speaker names"`が通る | #235 |
| `speaking.py check` は、2026-11-18 に本人が差し戻した台本の固定の写しから、専門家に尋ねる問い、助詞で終わる文、「か」を落とした問いの3つを、それぞれの行番号で出す | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check finds the three patterns in the rejected 2026-11-18 drafts"`が通る | #235 |
| `speaking.py check` は、くだけた縮約 (「ちゃう」「じゃあ」「もんね」) と、書き言葉の言い回し (「である」「であり、」「しており、」) を、行番号つきで出す | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check finds casual contractions and written-style phrases"`が通る | #235 |
| `speaking.py check` は、出典を挙げながら言い切る行 (「ドキュメントによると」で始めて「です。」で終える行) と、出典をあいまいに言う行 (「手引き」「ある記事」) を、行番号つきで出す | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check finds unhedged and vague sources"`が通る | #235 |
| `speaking.py check` は、台本全体の発話の長さの中央値と散らばり、短い発話の割合、相づちの数、同じ文末が3回続く所を `note` の行で出し、`note` だけの時は0で終わる | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check prints script-level notes without failing"`が通る | #235 |
| `speaking.py check` は、型の無い話し言葉の台本の固定の写しを0で通し、型の行を出さない | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check passes a natural spoken script"`が通る | #235 |
| `speaking.py check --source <file>` は、元の資料に無い数字と固有名詞 (カタカナの語と英字の語) を行番号つきで出して1で終わり、元の資料に在る語は出さない | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check lists numbers and names absent from the source"`が通る | #235 |
| `speaking.py check` は、読めない file と、形の合わない JSON を、何が違うかを1行で出して2で拒む | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"check rejects unreadable input with exit 2"`が通る | #235 |
| `SKILL.md` は、書く、`speaking.py check` を回して直す、書いた会話を引き継がない別の読み手に声に出した時の不自然な箇所を返させて直す、の順を指示し、元の資料に無い事実を足さないことを書く | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh`の検査`"SKILL.md orders write, check, fresh review, and fix and forbids new facts"`が通る | #235 |
