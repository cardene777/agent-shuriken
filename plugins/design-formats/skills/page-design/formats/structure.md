# Structure of an explanation

This format sets the order in which a document or a report explains its subject.
It applies to Markdown documents, such as design documents, specifications, READMEs, and how-it-works pages, and to reports, whether an HTML page or a reply in the chat.
The look of the same document is in `look.md`, next to this file.

## Conclusion first

The first line answers the question or states the result.
A reader who stops after the first line knows what happened or what to do.

- Open with the result, the decision, or the answer, never with "This document explains" or with how the work started
- State what the reader gets, then how it works
- Write how things will work, not how they work today, and leave history and rejected options in the issue that decided them

## The whole picture before the details

Show every part and how the parts connect before explaining any one part.
A reader who reads only the start still sees the whole.

- Put one figure, or one table when a figure adds nothing, at the top: the parts, the flow between them, and where the data is kept
- Then explain each part in the order of the flow
- Give the details step by step: the summary on the page, the details in a tab, in the panel beside a list, or in a later section
- Prefer a figure to a paragraph that lists relations, and a table to a paragraph that lists values

## One glossary, linked from every use

Every term a reader may not know is defined once, and every use points to that definition.

- Keep the definitions in one Glossary section, or behind a ? help button on a page
- Link each use of a term to its definition instead of explaining it again
- Say what each part does, what each value means, and where and in what form the data is stored
- Use the names that people in the field use; do not coin a name the reader has to learn

## Steps with real output

A step the reader carries out is one action, with what they see and what it produces.

- Give steps one at a time, numbered from 1, each with the label the screen shows and a link to the place to open
- Show a real example of what the step produces: the command's output, the file it writes, or the screen it opens
- Put a step the reader does by hand last, after everything the tool does for them

## Only what to do

A rule says how to write or how to act, once.

- Write what to do, not lists of what not to do
- Write each rule in one place and point to it from others
- Leave out notes about the document itself: excuses, demo notices, and explanations of the layout

## Reports

A report tells the reader what happened, in this order.

1. The result: what was found or changed, with the numbers
2. What was done and what was skipped, with the reason for each skip
3. Values that could not be measured, written as not measured, never as 0 or none
4. Steps the user takes, last

## Order by kind

| Kind | Order |
|---|---|
| Design document or specification | Purpose, the whole picture, each part, decisions still open |
| Report page | Facts about the run, result numbers, the list with details beside it, how the values were measured |
| Approval sheet | What will happen, the items to choose, the text copied back to the chat |
| Explainer | The whole picture, sections in reading order, the glossary |
| Choice page | The request, today's version, the options side by side, the choice panel |
| Chat report | The result, what was done and skipped, what was not measured, the user's steps |
