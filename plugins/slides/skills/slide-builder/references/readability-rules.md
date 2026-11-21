# Readability rules

The detailed rules behind slide-builder's first principle: the deck exists so the audience understands it.
Every outline (`slides-outline.md`) and every slide follows them.

## Where they apply

- Every deck slide-builder writes
- The titles, takeaways, explanations, and figure descriptions of `slides-outline.md`
- Any other text on a slide

## Rules

### 1. The default audience is non-engineers

Unless the user says otherwise, write for people like these.

- Managers and team leads
- Product owners and product marketers
- Sales and business development
- Legal, finance, and operations
- Investors and partners

What they share: they understand a product through how it is used, in real situations.
They do not need its inner workings in code terms.

When the user says the deck is for engineers, code words may stay. The validator still lists them as warnings, which the user can accept.

### 2. Banned words: general code words

Do not use these code words in the body of a slide. When a slide has to quote one, put it in a code block or in backticks, and explain it in everyday words.

| Banned | Say instead |
|---|---|
| function | step, task |
| method | way, step |
| class | kind, type |
| struct | record |
| variable | value, setting |
| API, endpoint | connection, the way other systems ask for data |
| SDK | development kit |
| query | lookup, question |
| repository | (leave it out) |

`scripts/validate.py` flags these words, and their plurals, as warnings.

The words of a deck's own field are added per deck.
A deck about payments for a sales team might ban `settlement` and `ledger`, and a deck about a factory might ban its machines' model numbers.
Pass each word to the validator with `--ban`, for example `--ban settlement --ban ledger`, and use the same words every time that deck is checked.

Explain an industry term at its first use in a short phrase, for example "SLA (the reply time we promise customers)". Later uses in the same deck can drop the phrase.

### 3. One slide, one message

Each slide says one thing. A message of the form "A, and B, and C" becomes three slides.

Test: ask someone who read the slide what it said. If they cannot answer in one sentence, split the slide.

### 4. One action per sentence

Keep sentences short: who does what, and at most one detail.

| Too much | Better |
|---|---|
| "The inbox reads the request's language, picks the desk that speaks it, and opens it to everyone after an hour" | "The inbox reads the language of each request. / The desk that speaks it sees the request first. / After one hour, everyone can take it." |

### 5. Concrete examples, not abstractions

An explanation of how something works is not enough. Give numbers, people, and situations.

| Abstract | Concrete |
|---|---|
| "Requests are spread across desks" | "London received 600 requests, Paris 300, and Berlin 100" |
| "The rule can change per request" | "A request in French goes to Paris first, and one in English goes to whoever is free" |

### 6. Numbers in everyday units

A technical figure on its own does not land. Add time, money, or a count of things people know.

| Technical only | With an everyday unit |
|---|---|
| "Reply time down 67%" | "Reply time down 67% (100 requests answered in 2 hours instead of 6)" |
| "Storage down 80%" | "The archive is a fifth of its size (five years of mail fit where one year did)" |

### 7. Explain terms at first use

Explain jargon, names of rules, and standards in a short phrase at first use.

| Unexplained | Explained |
|---|---|
| "We meet the SLA" | "We meet the SLA (the reply time we promise customers)" |
| "Requests go through triage" | "Requests go through triage (a first look that decides who answers)" |

Later uses in the same deck can drop the phrase. Explain it again when it comes back ten or more slides later.

### 8. The figure supports the text

Every slide must make sense from its text alone: when printed in black and white, or read by someone who cannot see the figure.
The figure speeds up understanding; it does not replace the text.

Avoid phrases that depend on the figure: "see the figure below", "as the chart on the right shows".
Say what happens in the text, and let the figure show the same thing.

### 9. At most five numbers per slide

A slide carries at most five numbers. A slide that needs six or more becomes two slides.

Why: people hold about seven things in mind at once. Five numbers and two pieces of context fill that.

### 10. Reveal step by step

Do not show a complex system on one slide. Add one part per slide.

| Step | Slide |
|---|---|
| Slide A | The whole, with the first of three parts in focus |
| Slide B | The second part added |
| Slide C | The third part added, and the whole picture |

More slides are not repetition when they let the audience follow.

### 11. Write as you would say it

Stiff report language keeps readers away. Use short active sentences addressed to the audience.

| Write | Avoid |
|---|---|
| "We answer in four hours" | "A response time of four hours is achieved" |
| "This is new" | "The novelty of this approach is noted" |
| "You can now see every request" | "Visibility of all requests is enabled" |
| "The slide shows the steps" | "The slide is a representation of the process flow" |

Use sentence fragments sparingly: a few in a row are hard to read.

### 12. No meta statements in the body

Do not put statements about the deck itself in the body: the talk length, the intended audience, or "this deck covers 27 items".
They are instructions for the presenter, not content.

| Meta statement | Content |
|---|---|
| "This deck takes 60 minutes" | (leave it out, or put it in a separate note) |
| "For managers and sales" | (leave it out) |
| "Ten improvements in one deck" | "With one inbox, a customer gets one answer" (say what happens) |
| "The deck has three parts" | (the outline table shows this; leave it out of the body) |

Exception: a title or questions slide (`type=hero`) may say what the whole deck is about in one sentence.

### 13. Define figures in words

The `### Figure` section says in words what the figure is for, what it should get across, and what it must show, in four parts.
No ASCII drawings, tables, or pixel shapes: leave the form to whoever draws the slide.

The four parts are purpose, message, elements, and what to avoid. `references/deck-format.md` shows an example.

Why no ASCII drawings: they fix the figure to the shapes of box-drawing characters. Words let whoever draws the slide choose a bar, a pie, nested boxes, or an icon breakdown.

### 14. Everyday names, not internal codes

Do not use internal short codes (`R2`, `T-Q3`, `P-M5a`) for products, projects, or rules. Use names a first-time reader understands.

| Internal code | Everyday name |
|---|---|
| `R2 routing` | Routing by language |
| `T-Q3` | The third-quarter trial |
| `P-M5a` | The rule that remembers a customer's last desk |

Exceptions.

- Common industry abbreviations (`FAQ`, `KPI`, `SLA`) are fine, explained at first use
- Names of parts of a system (`frontend`, `backend`) are fine
- Short codes made of a letter and a number (`R2`, `T-Q3`) are not

Test: if a first-time reader cannot guess what the code means from the code alone, use an everyday name.

## Checking each slide

Before and after writing each slide, check:

- [ ] The slide says one message
- [ ] No banned word (function, method, class, struct, variable, and the deck's own words)
- [ ] The style is spoken and active
- [ ] No meta statement (talk length, audience, "this deck covers N items")
- [ ] The figure is defined in words with four parts, without ASCII drawings
- [ ] No internal short codes; everyday names instead
- [ ] One action per sentence
- [ ] A concrete example (numbers, people, a situation)
- [ ] Numbers come with an everyday unit
- [ ] Terms are explained at first use
- [ ] The text makes sense without the figure
- [ ] At most five numbers

When every item holds, go on to the next slide. Otherwise, rewrite the slide.

## What the validator flags

`scripts/validate.py` flags banned words as warnings: the general code words above and every word given with `--ban`.
Text inside backticks, double quotes, and code blocks is not checked, so a slide can quote a term when it has to.
The other rules are checked by the writer, the person or the agent, with the list above.

## Exceptions

| Case | What to do |
|---|---|
| A technical deck for engineers | Keep the code words the audience uses, and accept the validator's warnings |
| A slide that must show a piece of code | One code block per slide at most, and the explanation in everyday words |
| A common industry term | Use it, explained at first use |

Even in these cases, every rule except the banned words still applies.
