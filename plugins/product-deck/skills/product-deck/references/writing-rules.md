# Writing rules (drawn from sentences that were pointed out)

Check the text of the slides against this list before writing it and after rendering.
Every item comes from a sentence that a reader of a real deck called machine-like or meaningless; none was written by guess.
The rules were written for decks in Japanese, and the examples are given in English translation. Where a check reads Japanese only, the rule says so.

The layout rules are in `layout-rules.md`; this file covers the text only.

**When a rule is added, add a check in the same change for whatever a machine can see.**
A rule without a check is passed over: five forms this file already forbade remained in a deck (eight pointing words, four pairs of words for one thing, two core words before their explanation, two shifted subjects, and one vague "thing"). They were plain to the writer, so nobody noticed until the text was scanned.

| Section | Check | Where |
|---|---|---|
| Do not leave the reader to fill in what a word points at | `banned word` | `audit.mjs` (rendered slides) |
| Words that only point at a place or a time | `banned word` | `audit.mjs` |
| When dropping jargon, keep what it points at | By eye | — |
| Make sentences, not strings of words | By eye | — |
| Do not use the deck's core words before explaining them | `a core word comes before its explanation` | `audit-text.mjs` (deck data) |
| Do not change the subject within a sentence | By eye | — |
| Do not end with a metaphor | By eye (`banned word` for metaphors already known) | `audit.mjs` |
| Match the subject to the action | `a person does a thing's action` (Japanese only) | `audit-text.mjs` |
| Keep the object in headings | By eye | — |
| Do not call one thing by different words | `the same thing is called by different words` | `audit-text.mjs` |
| Fewer passives and fewer heavy nouns | Listed only (the Japanese passive has the same form as the potential) | `audit-text.mjs` |
| End explanations as sentences | `explanation does not end as a sentence` | `audit.mjs` |
| Do not leave one letter on the last line | `last line of a wrapped explanation is too short` | `audit.mjs` |
| Do not write the slide text into the layout code | Seen on the editing screen (as items that match no value) | Editing screen |
| Open up loan words | Listed only (the words of the field are not shortened) | `audit-text.mjs` |
| Words to drop from the text | One check per kind of `prose-words.txt` | `audit-text.mjs` with `~/.product-deck/prose-words.txt` |

The last row has no section in this file: the words and their kinds live in the user's `prose-words.txt` (wordy phrases, words the reader does not know, the maker's notes, bare English words, and whatever kinds the list adds).
Writing them here too would put the same content in two places.

The deck's own terms live in the user's `writing-terms.txt`; pass another file with `--terms <path>` for another deck.
`docs/how-it-works.md` of the plugin shows how to write both lists.

## Do not leave the reader to fill in what a word points at

Do not use words such as "part", "thing", or "place" that leave the reader to fill in what they point at.
Write the thing itself.

| Before | After |
|---|---|
| The part a person approved and the part the agent passed line up in the same ledger | Transactions a person approved and transactions the agent passed stay in the same history |
| The part that was stopped also stays line by line | Requests that were stopped also stay line by line |
| Only three places come back to the company | The company keeps only the keys, the conditions, and the records at hand |

"The part that was done" is the most dangerous: plain to the writer, it reads to the reader as an amount or as somebody's share.

### Words that only point at a place or a time

"On the spot", "here", "this side", and "at that time" leave what they point at to the previous line or slide.
**A slide is read on its own**, so the reader cannot be expected to go back.

| Before | After |
|---|---|
| The reason for stopping stays on the spot | The reason for stopping stays on the device |
| Both come back from the same entrance | Signatures and reasons for stopping come back from the same call |
| If it matches a condition, it stops here | If it matches a condition, it stops before it reaches a person |

"The same" belongs here too, but **passes when it says the same as what**.

The check is `banned word`, with the words in `banned-words.txt`.

### When dropping jargon, keep what it points at

A deck for customers drops identifiers and error names. Drop the name only: **dropping the concept leaves the word put in its place pointing at nothing.**

| Original | Dropped too much | After |
|---|---|---|
| Send the request with a token that starts with the product's prefix | (this line may go) | Ask for a signature with a token |
| A request holds four things | One bundle is sent | A request for a signature holds four things |
| Sign EIP-712 typed data | Sign data of a fixed shape | Sign EIP-712 typed data |

The line is **whether the reader still thinks of the same thing once the word is gone**.
Dropping the prefix leaves "token", so it passes; replacing "request" with "bundle" leaves the reader unsure of what bundle, so it does not.

The complaint was "too machine-like; why abstract it so much": an instruction to drop implementation names had been taken as one to thin out the concepts.

## Make sentences, not strings of words

When three or more layers of modifiers stack, the reader cannot tell what modifies what.
Many sentences called machine-like have this form: the words are right, and the meaning is not put together.

| Before | What happens | After |
|---|---|---|
| Decide in advance only the conditions of the transactions that may pass | Unclear whether "that may pass" modifies the transactions or the conditions | Decide in advance which transactions may pass |
| The material to find out what happened, the means to fix, and the proof that nothing leaves | Fix what? What does not leave? | The material to find out what happened, the means to fix the conditions, and the proof that the keys do not leave |

**There are three fixes**: open it into a question ("the conditions of" becomes "which ... may"), bring back the dropped word ("the means to fix" becomes "the means to fix the conditions"), and keep the series in one form (start with "who ..." and continue with "which ...", "where ...").

## Do not use the deck's core words before explaining them

A deck has core words that recur. **Used on a slide before their first explanation, they cannot be understood.**
The writer knows their meaning and does not notice.

Example: "pass" (allow a signature) was a core word, used in 23 places, and its meaning came from the context of slide 3. The cover said "decide in advance which transactions may pass", and it was called meaningless.

| Slide | Before | After |
|---|---|---|
| Cover | Decide in advance which transactions may pass | Decide in advance which transactions to stop |

**The cover and the second slide are read by people who see the deck for the first time.** Use plain words only, and wait for core words until the slide whose context gives their meaning.

### How to check

List the core words, and the slide numbers each appears on. Compare the first slide with the slide whose context gives the meaning.

```bash
node -e "
import('./build/deck-data.mjs').then(({faces}) => {
  const WORDS = ['pass', 'check', 'condition', 'policy'];   // list them again for each deck
  const at = {};
  faces.forEach((f, i) => {
    const seen = new Set();
    const walk = (v) => {
      if (typeof v === 'string') { for (const w of WORDS) if (v.includes(w)) seen.add(w); return; }
      if (Array.isArray(v)) return v.forEach(walk);
      if (v && typeof v === 'object') Object.entries(v).forEach(([k, x]) => walk(x));
    };
    walk(f);
    for (const w of seen) (at[w] ??= []).push(i + 1);
  });
  for (const w of WORDS) console.log(w, (at[w] ?? []).join(' '));
});"
```

**When a word appears before its explanation, there are three fixes.**

| Fix | Example |
|---|---|
| Change the word on that slide to delay its first use | "keeping up with the standard" on slide 6 becomes "keeping up with changes of the specification", and "standard" first appears on slide 10 |
| Explain it where it first appears | Add what a background service is where the word first appears |
| Bring it to the slide of the word that explains it | Put "condition" into the explanation of "check" on slide 3, and tie the two on one slide |

Five words came before their explanation in one deck, and none was noticed until the text was scanned.

`audit-text.mjs` checks this with the `core` lines of the terms: `core  <word>  <slide number>`.

## Do not change the subject within a sentence

When the actor changes between the first and the second half, the reader loses whose story it is.

| Before | After |
|---|---|
| Hand the key to the agent, or have only the signature returned without the key | Hand the key itself to the agent, or keep the key at hand and hand over only the signature |
| The standard sets the shape of requests and responses. How to protect the key is left to each implementation | The standard sets the shape of requests and responses. Each implementation decides how to protect the key |

The second shows an active first half and a passive second half that drops the subject. **Making one half passive cuts off the subject that the sentence shared.**

## Do not end with a metaphor

A metaphor appears where the writer gave up explaining. Write what happens.

| Before | After |
|---|---|
| Here is the fork in the road | There are two means |
| A gate for signatures that writes the passing conditions first | Decide in advance which transactions may pass |
| Where the key lives | Where the key is kept |

## Match the subject to the action

A thing does not do what a person does, and a person does not do what a thing does.

| Before | After | What is wrong |
|---|---|---|
| The conditions written in advance press it | It is checked against the conditions written in advance | Conditions cannot press a button |
| What comes back to the agent | What is returned to the agent | The signature comes back; who returns it is lost |
| The key is made only inside the device | The device makes the key only inside itself | Who makes it is lost |

`audit-text.mjs` flags the Japanese form where a person or an agent is the subject of "remains", "returns", or "passes".

## Keep the object in headings

A heading without its object leaves the verb floating.

| Before | After |
|---|---|
| Write what to stop | Write first the transactions you want to stop |
| The path a person presses and the path the agent calls | The path a person approves and the path the agent calls directly |
| What to sign appears | What to sign appears on the screen |

## Do not call one thing by different words

Give one word to one thing in a deck, and do not change it along the way.

| Words that mixed | Word decided |
|---|---|
| AI / agent | agent |
| ledger / record | record (the screen's heading says "transaction history") |
| approval modal / approval screen | approval screen |
| reject / refuse | refuse |
| contract / smart contract | smart contract |

**Use the words on the product's screens.** Do not make up a word for the deck alone (one deck used a word for a "check layer" that appeared nowhere in the product).

**When adding a slide, look for the word already in the deck first.** Before writing a new word, search `deck-data.mjs` for a word that already names the same thing.

**Do not shorten the words of the field.** "Smart contract" shortened to "contract", or "blockchain" to "network", makes the reader think of something else. Shorten for length only when the word is not the subject of that slide.

`audit-text.mjs` checks this with the `synonym` lines of the terms: `synonym  <word decided>  <word that mixed> ...`.
Add the words decided against to the banned words of the deck as well, so that `audit.mjs` finds them on the rendered slides.

## Fewer passives and fewer heavy nouns

| Before | After |
|---|---|
| Two of the seven are left to implementations | Each implementation decides two of the seven |
| The risk is derived from the type of the transaction | The type of the transaction decides the risk |
| Signing and checking are completed within the device at hand | Signing and checking happen on the device at hand only |

## End explanations as sentences

A short explanation in a card may be a plain statement.
`lead` and `note` are full sentences.

| Place | Ending |
|---|---|
| Heading (`claim`) | A plain statement. In Japanese, no period and no comma |
| Explanation (`lead` / `note`) | A full sentence that ends with a period |
| Cards and table cells (`d` / `items`) | A plain statement. A period only when there are two sentences |

`audit.mjs` flags a `lead` or a `note` that does not end with a period (the Japanese period, or `.`, `!`, `?`).

## Do not leave one letter on the last line

When an explanation wraps and its last line holds one to three characters, they look left behind.
Fix it by shortening the sentence; widening the layout lets the same form come back when the sentence grows.

**An explanation's line is capped at 46 characters** (`max-width: 46em` on `.lead`). The cap is for reading and stays; cut the sentence when it passes 44.

`audit.mjs` also flags a katakana word split across two lines, which loses the reader at the break. Keep such a word together with a wrapper tag whose name has a hyphen (see the SKILL.md).

## Do not write the slide text into the layout code

Keep the text in one place, the text file. When the layout code holds the same words, **a fixed sentence does not appear on the slide**.

Four slides had this form: after the text was rewritten throughout, the slides still showed the old sentences, and nobody saw them by eye.
**They were found when the text became editable on the screen**: matching the values of the text file against the text on the slides showed them as items that match no value.

### When a sentence is too long for a figure

Keep the shortened sentence **as a separate field in the text file** (such as `items[].fig`).
Do not let the layout code cut the value: a cut value no longer matches.

| Way | Result |
|---|---|
| The layout cuts with `d.slice(0, 14)` | The cut string does not match the value, and cannot be edited on the screen |
| The layout uses the second half of `d.split(".")` | The same |
| The text file holds `fig` separately | Both can be edited on the screen. They are two sentences for two uses, not a duplicate |

## Order of checking

1. Write the text of the slides
2. **Read aloud** `claim`, `lead`, and `note` from top to bottom in one go, and fix where you stumble
3. List the short explanations of the cards, and check that no thing is called by different words
4. Check against each section of this file

Do not skip 3: looking at one slide at a time misses words that drift across the deck.

```bash
grep -o 'claim: \[[^]]*\]\|lead: "[^"]*"\|note: "[^"]*"' <text file>
```
