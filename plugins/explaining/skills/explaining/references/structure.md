# How to build an explanation

This file holds the way to build an explanation of how something works: a protocol, a system, a process, or a piece of research.
A skill that writes an explanation reads it before deciding what its sections say, and applies its own format for the page, the figures, and the language.

Decide the parts below before writing any sentence.
Write down which part of the explanation uses each technique, so a reviewer can check each technique is placed on purpose and none is used for show.

## One running example

Use it when the explanation covers more than one step or more than one role.
Pick one concrete case with names and values, such as one transfer of 100 USD from Alice to Bob, and use it in every section, from the first paragraph to the closing table.
Name the things the example changes (for example contract C0 becomes C1) once at the start, and refer to them by the same names in every section and figure.
Do not switch to another example halfway; when a second case is needed to show a failure, change one value of the same example.

## A map of the stages

Use it when the thing works through three or more stages in order.
Before the sections dig into the stages, show a numbered map of every stage with one line each, and draw it as a figure that steps through the stages with the running example.
Then give each later section one stage of the map, in the same order and with the same number or name, so the reader always knows where they are.

## Pairs told apart

Use it when two or more things have similar names or roles and a reader is likely to treat them as one.
Put them side by side in a table whose rows ask the same questions of each: what it shows, who makes it, and what it does not decide.
Say in one sentence after the table where the difference matters in the running example.

## Misreadings ruled out

Use it when a role is easy to over-read, such as a part that passes data along being taken for a part that checks it.
State what the part does not do in a negative sentence ("The Sequencer does not decrypt the views"), next to what it does.
Rule out a misreading where it would arise, not in a separate list of warnings at the end.
Mark the point where an intermediate result is not yet final ("This approval is not the commit yet").

## Every combination of conditions

Use it when a result depends on two or more conditions, such as which parties approve and whether they answer in time.
Lay out every combination in a table with its result, including the ones that fail and the one where an answer never arrives.
Add a figure that takes input, where the reader chooses the conditions and sees the result change, when the combinations are more than a reader can hold from the table.

## A closing table and one sentence

Use it when the explanation reaches its end, which is in every explanation.
Close with a table of roles that says what each part did in the running example, then one sentence the reader should take away.
The sentence answers the question the explanation opened with, in plain words, without introducing anything new.

## Figures by what they do

Choose each figure by what it has to show, not by what is easy to draw.
A figure that does not move is for parts and their relations; whenever order, a change of state, or a dependence on conditions is the point, use one of the figures below.

| Figure | dragon kind | Use it for |
|---|---|---|
| A figure that steps | `sequence` | Messages or work passing between parts in order, such as the map of the stages |
| A figure that takes input | `try` | A result that depends on conditions the reader chooses, such as which parties approve |
| A figure of the state before and after | `state` | Things that change state, such as a contract that is active before and archived after |

Every figure carries the running example: the same names, values, and things as the text around it.
Each step of a figure says in one or two sentences what happens in that step, so the figure reads without the text.

## Order of the parts

Open with the question the explanation answers and the running example.
Show the map of the stages, then one section per stage, each headed by the question the section answers.
Place pairs, misreadings, and combinations in the section where the reader meets them.
Close with the table of roles and the one sentence.
