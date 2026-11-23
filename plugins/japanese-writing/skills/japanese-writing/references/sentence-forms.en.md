# Shaping sentences

This file is a reference written here, and the upstream does not have it.
It lists sentence shapes whose meaning shifts with the reader, and shapes that rely on symbols to show importance, next to examples before and after the fix.
When it conflicts with the upstream text in `UPSTREAM-SKILL.md`, follow the priority table in §1 of `references/rules.md` and use this file first.

Three of the shapes are counted by machine.
`scripts/suspects.py` points to them line by line as `URLの後の句点` ("full stop after a URL"), `目的の断片` ("purpose fragment"), and `括弧の長い補足` ("long note in parentheses").
The other shapes cannot be judged without reading the context, so trace them with this file when you write and when you fix.

## The eight shapes

### Write a bad thing with a predicate that shows it is bad

Do not write a bad thing with a predicate that can also be read as a good thing.
Readers take 「落ちない」 ("does not fail") as reassuring news and do not notice that it reports a miss.

| Before | After |
|---|---|
| patternが遅くなっても落ちない。 ("Even if the pattern gets slow, it does not fail.") | patternが遅くなった事を検知できない。 ("It cannot detect that the pattern got slow.") |

### State a purpose as a complete clause

Do not write a purpose as a fragment such as 「〜用に、」 ("for ~,"); state it fully as a clause with 「〜できるよう」 ("so that ~ can") or 「〜で使うため」 ("in order to use in ~").
Left as a fragment, it makes the reader fill in what the thing is for.

| Before | After |
|---|---|
| テスト用に、値を置く。 ("For tests, put a value.") | テストで同じ値を使えるよう、値を置く。 ("Put a value so that tests can use the same value.") |

### Do not use a vague word as the predicate of a purpose

As the predicate of a purpose clause, put a verb that shows what becomes possible.
「当たる」 ("hits, applies") and 「効く」 ("takes effect") do not say what becomes possible to check.

| Before | After |
|---|---|
| highlightが当たるよう、印を付ける。 ("Add a mark so that the highlight applies.") | highlightを判定できるよう、印を付ける。 ("Add a mark so that the highlight can be judged.") |

### Do not join two things after a reason

Do not line up two things after a reason with 「〜し、〜する」 ("do ~, and do ~"); split the sentence for each thing the reason applies to.
When they are lined up, the reader cannot tell whether the reason applies to one of them or to both.

| Before | After |
|---|---|
| 負荷が高いため、検査を絞り、結果を記録に残す。 ("Because the load is high, narrow the checks and keep the results in a record.") | 負荷が高いため、検査を絞る。絞った結果は記録に残す。 ("Because the load is high, narrow the checks. Keep the narrowed results in a record.") |

### Reread a copied sentence in the context where you pasted it

Reread a sentence copied from elsewhere together with what comes before and after it in the place where you pasted it.
Pointing words and omissions that assume the original context point to nothing in the place where it was pasted.

| Before | After |
|---|---|
| 上と同じ手順で直す。 ("Fix it with the same steps as above.") | `branch.sh`で作業場所を作る手順と同じ手順で直す。 ("Fix it with the same steps as the steps that create a work place with `branch.sh`.") |

### Do not show importance with emphasis marks

Do not use emphasis marks such as bold to show importance.
Convey importance through the choice of words, the firmness of the statement, and the position of the sentence.

| Before | After |
|---|---|
| **秘密の値は必ず`.env.local`に置く。** ("Always put secret values in `.env.local`.") | 秘密の値は`.env.local`だけに置く。commitする前に、ほかのfileに書いていないかを確かめる。 ("Put secret values only in `.env.local`. Before you commit, check that you have not written them in any other file.") |

### Do not add notes in parentheses

The only thing allowed in parentheses is a short gloss added to a term at its first use.
Put a note about a reason or a condition in a separate sentence or in a child bullet.
Delete parentheses that only state the meaning of the sentence turned inside out.
The restatement in parentheses at first use, which principle 4 of 「2. 書くときの原則」 ("2. Principles for writing") in the upstream text recommends, is used only in this short-gloss form.
A gloss for a term at first use becomes long if you split it into its own sentence, but a reason or a condition in parentheses breaks the build of the sentence, so these two are kept apart.

| Before | After |
|---|---|
| 値を分けて置く（置き場を分けると、読み手が迷わないため）。 ("Keep the values apart (because separate places keep readers from getting lost).") | 値を分けて置く。置き場を分けると、読み手が迷わない。 ("Keep the values apart. Separate places keep readers from getting lost.") |
| 記録を先に読む（読まないと古い値で判定する）。 ("Read the record first (if you do not, you judge with old values).") | 記録を先に読む。 ("Read the record first.") |

### Do not put a full stop on a line that ends with a URL

Do not put a full stop (句点) at the end of a line that ends with a URL.
Automatic links on GitHub and elsewhere can include the full stop in the URL, and opening it leads to a different page.

| Before | After |
|---|---|
| 起点はhttps://github.com/cardene777/agent-shuriken。 ("The starting point is" + the URL + a full stop) | 起点はhttps://github.com/cardene777/agent-shuriken ("The starting point is" + the URL) |

## Write in the affirmative

Write the action you want the reader to take in the affirmative.
With only the negative, the reader is left without knowing what to do instead.

| Before | After |
|---|---|
| 一時fileを`/tmp`に置かない。 ("Do not put temporary files in `/tmp`.") | 一時fileは`.context/`に置く。 ("Put temporary files in `.context/`.") |

In the following six cases, keep the negative.
If you rewrite them in the affirmative, what you want to stop, or the limit, no longer reaches the reader.
The "Before" column of the table lists sentences where rewriting the negative in the affirmative lost what was meant to be said.

| Case where the negative stays | Before | After |
|---|---|---|
| Prohibition | 秘密の値は`.env.local`に置く。 ("Put secret values in `.env.local`.") | 秘密の値をcommitしない。 ("Do not commit secret values.") |
| Instruction to avoid danger | 消す前に対象を確かめる。 ("Check the target before you delete it.") | 確かめていない対象を`rm -rf`で消さない。 ("Do not delete a target you have not checked with `rm -rf`.") |
| Exception | 全てのrepoで検査を回す。 ("Run the checks in every repo.") | 一覧に載せたrepoでは検査を回さない。 ("Do not run the checks in the repos on the list.") |
| Condition of use | 設定は管理者が変える。 ("Administrators change the settings.") | 管理者でなければ設定を変えられない。 ("If you are not an administrator, you cannot change the settings.") |
| Something that cannot be done | 消した記録は手で書き直す。 ("Rewrite deleted records by hand.") | 消した記録は元に戻せない。 ("Deleted records cannot be restored.") |
| Contrast | 正しさを取る。 ("Choose correctness.") | 速さではなく正しさを取る。 ("Choose correctness, not speed.") |
