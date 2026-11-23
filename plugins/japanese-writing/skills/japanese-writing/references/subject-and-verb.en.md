# Subjects and verbs

This file was written here, in this plugin. The upstream source does not have it.

In technical writing, the sentences that are hardest to read are **sentences where a thing stands as the subject and moves through a metaphor**.
A reader can read them without knowing a single term, yet cannot pull out who does what.

A machine can only point at suspects (§ What the machine checks), so read the sentence and decide whether to fix it.

## What happens

A sentence becomes hard to read when the two forms below occur together.

| # | Form | What happens to the reader |
|---|---|---|
| 1 | A non-living thing stands as the subject | The reader has to supply the actor themselves |
| 2 | An operation is described with a metaphorical verb | The reader has to translate what happens themselves |

Always fix a sentence that has both.
If it has only one, keep it by default, and fix it only when the metaphorical verb hides the operation (§ Sentences with only one).

One example that has both.

```
shared/ は 2 つの置き場の隣に立ち、技の実体を預かる。
```

("shared/ stands next to the two places and keeps the actual copies of the skills in custody.")

`shared/` is a directory, so it cannot `立つ` ("stand"), and there is nobody whose things it could `預かる` ("keep in custody").
The reader has to translate it themselves, all the way to 「実体を 1 つだけ置いてある」 ("only one actual copy is placed there").

The fixed form.

```
どちらの置き場からも使う技は shared/ に実体を 1 つだけ置き、2 つの置き場がそこへ繋ぎを張る。
```

("Skills that both places use keep a single actual copy in shared/, and the two places set up links to it.")

The subjects changed to `技` ("skill") and `置き場` ("place"), and the verbs became `置く` ("place") and `張る` ("set up").
Not a single point of meaning changed.

## The order of fixing

**Fix the subject first**. Changing only the verb twists the sentence.

1. Decide who actually moves in that sentence (a person / a process / the writer / the reader)
2. Change to a verb that fits the subject you decided
3. Check whether the new verb names the actual operation

When the actor is not in the sentence, **bring it in from outside the clause**.
In explanatory documents, the common case is an actor that already has a name on a box in the diagram, such as 「配る処理」 ("the distribution process"), 「取り込みの処理」 ("the import process"), or 「検査」 ("the check").
If you use the same name as the diagram, the text and the diagram also line up where they meet.

**When the sentences before and after do not have an actor to bring in either, do not invent one**.
Ask the writer, or note in 〔理由〕 ("reason") what is not written (`references/ai-smell.md` § 意味を足さない, "Do not add meaning").

When there truly is no actor (a description of a state), **change it to a sentence of existence**.

| Before | After |
|---|---|
| `my-config` は 2 つの置き場を持ち ("`my-config` holds two places") | この repo には 2 つの置き場があり ("this repo has two places in it") |
| この構成は 3 通りの経路を許す ("this structure allows three routes") | 経路は 3 通りある ("there are three routes") |

## Write appeals to the reader in three forms

When specifications and guides use the passive voice, who is being asked to do what disappears.
`導入が推奨されます` ("introduction is recommended") does not say who recommends it or who introduces it.

Split the sentence ending into three forms by what the sentence asks of the reader.

| Kind | Sentence ending | Before | Fixed form |
|---|---|---|---|
| Request (you want the reader to do it) | 〜してください ("please do ~") | 事前の承認が推奨されます ("prior approval is recommended") | 実行する前に、承認を取ってください ("before you run it, please get approval") |
| Capability (the reader can do it) | 〜できます ("can ~") | 設定画面からの変更が可能となっています ("changing it from the settings screen is made possible") | 設定画面から変更できます ("you can change it from the settings screen") |
| Policy (decided on the writer's side) | 〜する / 〜にする ("does ~ / makes it ~") | 古い記録は削除されます ("old records are deleted") | 古い記録は、片付けの処理が 30 日後に消す ("the cleanup process deletes old records after 30 days") |

Write 「30 日後」 ("after 30 days") and 「片付けの処理」 ("the cleanup process") in the third row only when the original text or the sentences around it say so.
If they do not, ask the writer.

`suspects.py` points at passive appeals such as `推奨されます` ("is recommended").

## Turn demonstratives back into nouns

Demonstratives such as `これ` ("this") / `両者` ("both") / `片方` ("one of them") / `前者` ("the former") cannot be understood without reading the sentence before.
Check whether the sentence can be read alone when only that one sentence is quoted in a pull request body or a summary.

| Before | Fixed form |
|---|---|
| 両者の差分を見る ("look at the difference between both") | repo の設定と、配備した先の設定の差分を見る ("look at the difference between the repo's settings and the settings where it was deployed") |
| これが重要 ("this is important") | 設定の読み込み順が重要 ("the order in which settings are loaded is important") |

Upstream tested a detector that counts how often demonstratives appear, as B7 (こそあど言葉の指示先不明, "unclear referents of ko-so-a-do demonstratives"), and withdrew it (it did not catch them even in low-quality human writing).
For that reason `suspects.py` does not count demonstratives either; check them by eye.

## Table of fixes

The left is the metaphor, the right is the operation. **This is not a table for direct replacement**.
The same metaphor can point to a different operation, so look at what actually happens and choose.

| Metaphor | Kind | Operation it often points to |
|---|---|---|
| `立つ` / `立ち上がる` ("stand" / "stand up") | 擬人 (personification) | 置く (place) / 作る (create) / 起動する (start) |
| `預かる` / `面倒を見る` ("keep in custody" / "look after") | 擬人 (personification) | 持つ (hold) / 保存する (store) / 実体がそこに在る (the actual copy is there) |
| `見張る` / `眠る` ("keep watch" / "sleep") | 擬人 (personification) | 検査する (check) / 使われていない (not used) |
| `迷う` / `困る` / `嫌がる` ("hesitate" / "be at a loss" / "dislike") | 擬人 (personification) | 判定できない (cannot decide) / 失敗する (fail) / 受け付けない (not accept) |
| `覚える` / `忘れる` ("remember" / "forget") | 擬人 (personification) | 記録する (record) / 記録が消える (the record is lost) |
| `知っている` / `話す` ("know" / "talk") | 擬人 (personification) | 参照できる (can refer to) / やり取りする (exchange data) |
| `踏み込む` / `引き返す` ("step in" / "turn back") | 擬人 (personification) | 実行する (run) / 中断する (stop partway) |
| `黙る` / `沈黙する` ("fall silent" / "keep silent") | 擬人 (personification) | 出力しない (output nothing) / 検知しない (detect nothing) |
| `効く` / `効かない` ("work" / "not work") | 操作 (operation) | 判定に入る (is included in the decision) / 判定に入らない (is not included in the decision) / 期待した結果が出る (gives the expected result) |
| `倒す` / `潰す` ("tip over" / "crush") | 操作 (operation) | 既定値にする (set to the default) / 1 つの値にまとめる (merge into one value) / 除外する (exclude) |
| `壊れる` ("break") | 操作 (operation) | 落ちる (crash) / 誤った結果を返す (return a wrong result) / 不整合が起きる (become inconsistent) |
| `溶かす` ("melt") | 操作 (operation) | 時間を要する (take time) / 減らす (reduce) |
| `着地させる` ("land") | 操作 (operation) | 完了させる (finish) / 合意する (agree) |

There are two kinds.
`擬人` (personification) is a word that becomes a metaphor only when a thing is the subject; with a person as the subject it makes an ordinary sentence (`読み手が知っている語`, "a word the reader knows").
`操作` (operation) is a word that rephrases and hides the actual operation even when a person is the subject (`バグを潰す`, "crush a bug", does not say what was done).

**This does not ban all metaphors**.
Use expressions established in the field (`安全側へ倒す`, "tip toward the safe side" / `待ち受ける`, "listen for") as they are.
Of the uses of `倒す`, keep only `安全側へ倒す`; write `残さない側に倒す` ("tip toward not keeping") or `共通側に倒す` ("tip toward the common side") as an operation, such as `除外する` ("exclude") or `共通部品に寄せる` ("move into a shared part").

The words in the table are also listed with the same kinds in `references/metaphor-words.tsv`, and a test checks that the two match.
When you add a word, add it to both.

## Metaphorical adverbs

Even when the verb names the operation, a metaphorical adverb makes what happened disappear.

| Metaphor | What it often points to |
|---|---|
| `静かに` ("quietly") | 記録を残さずに (without leaving a record) / error を出さずに (without raising an error) / 誰も気付かないまま (without anyone noticing) |
| `地味に` ("plainly") | 少しずつ (little by little) / 目立たない所で (where it does not stand out) |
| `ひっそり` ("stealthily") | 告知せずに (without announcing it) |

`黙って` ("silently") works the same way, but with a person as the subject it makes an ordinary sentence (`黙って待つ`, "wait silently"), so it goes under `擬人`, the same kind as `黙る` in the table of fixes.

```
設定の差分が静かに増えていく。
```

("The differences in the settings quietly keep growing.")

It does not say what is 「静か」 ("quiet").
What to fix depends on whether no check looks at the differences, or a record exists but nobody reads it.

```
設定の差分は検査の対象に入っていないため、差分が増えても誰も気付かない。
```

("The differences in the settings are not covered by any check, so nobody notices when they grow.")

## Forms that come from literal translation of English

Many metaphorical verbs and adverbs come from translating an English verb word for word.

| English | Literal translation | What the English was saying |
|---|---|---|
| `fails silently` | `静かに失敗する` | error を出さずに失敗する (fails without raising an error) |
| `X works for Y` | `X が Y に効く` | X を使うと Y が期待どおりに動く (Y works as expected when X is used) |
| `X breaks` | `X が壊れる` | X が落ちる / X が誤った値を返す (X crashes / X returns a wrong value) |

When fixing, recall what the English was saying, and you will find the word for the operation.
The fourth item (word-for-word translation of English phrasing) under the upstream text's 「読み手が何のことか分からない言い回しは、ふだんの言葉に戻す」 ("turn phrasing the reader cannot make sense of back into everyday words") covers forms where English syntax shows through; this section covers the choice of verbs and adverbs.

## Sentences with only one

A sentence whose subject is a person or a process, and whose only metaphor is the verb, is kept by default.
The subject is in the sentence, so the reader does not have to supply who acts.

However, fix it when the metaphorical verb hides the operation.

| Before | Fixed form | What was hidden |
|---|---|---|
| `調査に時間を溶かした` ("melted time on the investigation") | 原因の特定に 2 日を要した ("identifying the cause took two days") | How long it took |
| `判断できないものは残さない側に倒す` ("tip what cannot be judged toward not keeping it") | 採否を判断できない項目は除外する ("exclude items whose adoption cannot be decided") | The operation of excluding |

Decide whether to keep or fix by whether the reader learns something new when the verb is changed to the word for the operation.
If there is nothing new to learn, keep it.

## Forms you may keep

| Form | Example | Why keep it |
|---|---|---|
| A thing as the subject + a non-metaphorical verb | `この表が判定の根拠を持つ` ("this table holds the grounds for the decision") | There is no need to supply the actor |
| A person or process as the subject + a metaphorical verb that does not hide the operation | `判定を安全側へ倒す` ("tip the decision toward the safe side") | The actor is in the sentence, and the operation can be read |
| Expressions established in the field | `待ち受ける` ("listen for") / `口を開ける` ("open an opening") | Replacing them turns them into a different concept |
| Places that show the implementation's text as it is | The body of an error / text on a screen | Rewriting it gives text the implementation does not output |

The fourth happens especially often in documents.
If you rewrite the text of a running screen to be "easier to read", only the document disagrees with the implementation.

## What the machine checks

The only list of metaphor words is `references/metaphor-words.tsv`, and `scripts/suspects.py` reads it.

| script | Text it looks at | Condition it points at | Output |
|---|---|---|---|
| This skill's `scripts/suspects.py` | Text in general (Markdown and plain text) | `操作` (operation) verbs and metaphorical adverbs are pointed at whenever they appear in prose, whatever the subject. `擬人` (personification) verbs are pointed at only in sentences where `は` or `が` comes right after an identifier enclosed in backticks | Suspects per line. No pass or fail |

The list also holds patterns that exclude a match by the characters before and after the word.
This keeps it from catching non-metaphorical uses such as `お握り` ("rice ball") / `氷を溶かす` ("melt ice") / `卒倒` ("faint") / `主導権を握る` ("take the lead"); matched on the word alone, most of the list would hit even text that people wrote.

**Know the forms it misses**. A count of 0 cannot be read as "there are none".

| Form it misses | Example |
|---|---|
| Metaphors not on the list | The list holds only the words added by testing against real text |
| A problem with the subject only (the verb is not a metaphor) | `この構成は 3 通りの経路を許す` ("this structure allows three routes") |
| A `擬人` word whose subject is outside backticks | `my-config は 2 つの置き場の隣に立ち` ("my-config stands next to the two places") |

In one measurement, the same paragraph in two documents held 3 sentences it missed
(the detector pointed at only 1 of the 4 sentences).
**When you fix a sentence it pointed at, also read the rest of the same paragraph and check it again**.

## Use the upstream material

Two samples that upstream left can be used to practice this point of view.

| file | Contents |
|---|---|
| `scripts/fixtures/ai-smelly.md` | A sample of Japanese that reads as if a machine wrote it |
| `scripts/fixtures/natural.md` | A sample of Japanese written by people |

Both were inputs to an experiment that calibrated thresholds, and the script that calls them is not kept here.
They are kept as material to read.
