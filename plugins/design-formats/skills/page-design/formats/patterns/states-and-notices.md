# States and notices

This file decides how a page shows that a region is empty, loading, failed, saved, or unsaved, and how it tells the reader about it.
Read it when a page or document has a region that can be empty or still loading, a form that can fail, a notice, a status label, or changes the reader can lose.
Every rule keeps the look rules in `look.md`, which this file does not repeat.

## Choose between

| You need | Use | Rule |
|---|---|---|
| A list, table, or section has nothing to show | A message in its place that names what is missing, with one next step | S1 |
| A search or filter finds nothing | A no-match message with a button that clears the filter | S2 |
| Part of the page is not ready yet | One indicator in the center of that part, named and announced | S3, S4, S5 |
| A save or submit is running | Progress inside the button that started it | S6 |
| Something failed or an answer cannot be used | A plain message at the place it applies, with a summary after submit | S7, S8, S9, S10, S11 |
| The whole page cannot work | A page-level message that replaces the content | S12 |
| Something needs the reader's attention | Inline text, a separate warning block, or one banner under the title | S13, S14, S15 |
| A quick action finished | A short toast, also shown in place | S16 |
| The reader wants to read past notices again | The notifications panel from a header button with a count badge | S17, S18 |
| Writing the words of any notice | A title that states the point, read out without moving focus | S19, S20 |
| An item has a state such as approved or overdue | A short status label with text, an icon, and a fixed color | S21, S22, S23 |
| The reader has changes not yet saved | Save state at the top right and a prompt on leaving | S24, S25 |

## Rules

### S1 Put a short message and one next step in place of an empty list, table, or section

| Item | Value |
|---|---|
| Use when | A list, table, chart, or section has no items after loading has finished, such as no orders yet or nothing to approve |
| Do not use when | A search or filter emptied the list, and use S2 instead; while the content is still loading, use S3 instead |
| How | Replace the element that would hold the data (the whole `<table>` with its `<thead>`, or the `.list`) with one `<div class="empty">` in the same place, centered in that area, its text at most 480px wide. Keep the section heading above it. Write a 16px heading that names the specific missing thing ("No orders yet", "Nothing to approve this week"), never "No data" or "Nothing here". Under it, one sentence on why it is empty or what will appear there. Add at most one primary button or link that fills the area ("Add an order") and at most one secondary link. Hide filters, sort controls, and search boxes that have nothing to act on. Never leave the area blank or show table headers with no rows |
| Sources | s-nng-empty-1, s-carbon-empty-1, s-carbon-empty-2, s-carbon-empty-6, s-pf-empty-1, s-pf-empty-2, s-apple-writing-1, s-sap-illustrated |

### S2 Say that nothing matched and offer to clear the search or filter

| Item | Value |
|---|---|
| Use when | A search box or filter on the page leaves no rows |
| Do not use when | The data is empty before any filter, and use S1 instead |
| How | Keep the search box and filters visible with their current values, so the reader sees the cause. In place of the rows, show "No orders match 'tea'" with the term or filter named, then `<button type="button">Clear filters</button>` that restores the full list and moves focus to the search box. Add at most one line suggesting a broader term. Write the new count ("0 results") into a `role="status"` region that is in the HTML from load. Never offer tips alone without the button |
| Sources | s-pf-empty-3, s-carbon-empty-5, s-baymard-no-results, s-wcag-status-1 |

### S3 Show loading in the center of the area that is loading, and only there

| Item | Value |
|---|---|
| Use when | A section, panel, figure, or the whole page waits more than about 1 second for its content |
| Do not use when | The content is already in the page or arrives within about 1 second, and show it at once instead; for work started by a button, use S6 instead |
| How | Keep the area at the size of the content it will hold (at least 120px tall) and center one indicator in it with `display: grid; place-items: center`. Use a 24px ring turning once a second (32px when the whole page loads), with its label under it (S4). Start showing it only when the wait passes 1 second, with a `setTimeout` of 1000ms cleared when the content arrives, so fast loads do not flash. Show one indicator per region; when several parts load together, show one on their shared container. Leave the other sections usable and draw no overlay across the page. Draw no skeleton frames or gray placeholder bars. When loading ends, replace the indicator with the content, the empty message (S1), or the error (S9), never with nothing. Under `prefers-reduced-motion: reduce` the ring stops and the label stays |
| Sources | s-m3-progress-1, s-pf-spinner-1, s-pf-spinner-2, s-fluent-spinner, s-carbon-loading-1, s-nng-progress-1, s-nng-skeleton, s-nng-empty-2, s-dads-no-skeleton |

### S4 Name what is loading and tell screen readers when it starts and ends

| Item | Value |
|---|---|
| Use when | A loading indicator from S3 or S5 is on screen |
| Do not use when | The wait is under about 1 second and no indicator shows, and add no label or announcement instead |
| How | Put a 14px label under the indicator that names the content ("Loading approval history"), never "Loading" alone, taken from the `TEXT` dictionary. Give the indicator `role="progressbar"` and an `aria-label` with the same words, or use `<progress>` with a `<label>`. Set `aria-busy="true"` on the region while it loads and remove it when done. Keep one empty `role="status"` region in the HTML from load, and write "Approval history loaded" or the failure message into it when loading ends. Do not move focus |
| Sources | s-m3-progress-2, s-nng-progress-2, s-carbon-loading-pattern, s-fluent-skeleton, s-wcag-status-2 |

### S5 Show a percent or step count when progress can be measured, and a stop button for long waits

| Item | Value |
|---|---|
| Use when | The page knows how much of the work is done, such as files, steps, or bytes, or the wait may pass 10 seconds |
| Do not use when | The amount done is unknown and the wait is short, and use the turning ring of S3 instead |
| How | Use `<progress max="100" value="40">`, or an element with `role="progressbar"`, `aria-valuemin="0"`, `aria-valuemax="100"`, and `aria-valuenow`, at least 4px tall and up to 480px wide, centered in the area. Show the value as text beside it ("40%" or "Step 2 of 5"). Switch from the ring to the bar as soon as the total becomes known. Advance the bar as work proceeds, so a stall is visible. When the wait may pass 10 seconds, put `<button type="button">Stop</button>` under the bar, and after a stop say what was kept and what was not |
| Sources | s-apple-progress-1, s-apple-progress-2, s-fluent-progressbar, s-m3-progress-4, s-nng-response, s-nng-progress-4, s-dads-progress-text |

### S6 Show progress inside the button while a save or submit runs, and block a second press

| Item | Value |
|---|---|
| Use when | The reader pressed Save, Approve, Send, or another button whose work takes time |
| Do not use when | The wait is for content in a region rather than for an action, and use S3 instead |
| How | Fix the button's width with `min-width` at its current width, and center a 16px turning ring in it, or put the ring before a changed label such as "Saving". Set `aria-disabled="true"` and ignore further presses until the work ends; keep focus on the button, which the `disabled` attribute would drop. When the work ends, restore the label and update the save state (S24). On failure, show the error next to the button (S9). Under reduced motion the ring stops and the label stays |
| Sources | s-m3-progress-1, s-m3-progress-3, s-carbon-loading-2, s-nng-progress-3, s-nng-visibility-1 |

### S7 Say what went wrong and what to do next, never the raw error text

| Item | Value |
|---|---|
| Use when | Anything fails, such as an answer, a save, a load, a copy, or the whole page |
| Do not use when | Nothing failed and the reader only needs to know about a condition, and use a notice from S13 instead |
| How | Write the message in plain words in two parts, what happened in terms of the reader's task ("The file is larger than 10 MB") and what to do now ("Choose a file under 10 MB"). Put the control that fixes it right after the text, a button or link such as "Try again" or "Choose another file". Never show stack traces, exception names, `undefined`, `null`, `NaN`, `[object Object]`, HTTP status numbers, or error codes. Never use "Error" or "An error occurred" alone as a title. Keep every message in the `TEXT` dictionary in both languages |
| Sources | s-gov-error-1, s-nng-error-1, s-pf-errors, s-apple-alerts-1, s-fluent-msgbar-1, s-wcag-suggestion, s-sap-messaging-2, s-baymard-adaptive, s-dads-error-content |

### S8 Leave out apologies, excuses, jokes, demo notices, and blame

| Item | Value |
|---|---|
| Use when | Writing any text on the screen, including errors, empty states, notices, and labels |
| Do not use when | The text quotes the reader's own data, such as a comment they wrote, and show it unchanged instead |
| How | Delete "Sorry", "Oops", "Uh-oh", "Unfortunately", and "please". Delete any line that excuses or explains a limit of the page, such as "This is a demo", "Sample data", or "Not implemented yet". Do not use words that blame the reader, such as "invalid", "illegal", "forbidden", "prohibited", "incorrect", or "you forgot"; say what the answer needs instead ("Enter a date after 1 April"). Use no humor and no exclamation marks in errors and empty states |
| Sources | s-gov-error-2, s-gov-404, s-nng-error-2, s-apple-writing-2, s-carbon-empty-4, s-pf-empty-5 |

### S9 Show each error where it applies

| Item | Value |
|---|---|
| Use when | An error concerns one field, one section, or one action |
| Do not use when | The whole page cannot work, and use S12 instead |
| How | Put a field error directly under the field, in `<p class="field-error" id="date-error">` linked from the field with `aria-describedby`, and mark the field `aria-invalid="true"`. Start the message with an error icon and a hidden prefix, `<span class="visually-hidden">Error.</span>`, with no colon. Put a section error at the top of that section under its heading, and an error about an action next to the button that started it. Put a page-wide problem in the banner place of S15. Use the `--critical` color with the icon and a 2px left border, at 14px or larger. Keep the message until the input is fixed |
| Sources | s-nng-error-3, s-apple-writing-3, s-m3-textfields, s-pf-alert-1, s-wcag-identification, s-gov-error-4 |

### S10 After a failed submit, show an error summary at the top of the form and move focus to it

| Item | Value |
|---|---|
| Use when | The reader submits a form or an approval and one or more answers have errors |
| Do not use when | The failure is not about an answer, such as a failed save, and show it next to the button with S9 instead |
| How | Insert `<div class="error-summary" tabindex="-1" aria-labelledby="error-summary-title">` at the top of the form, below the page title and above the first field, with a 2px `--critical` border and 16px padding. Its 16px heading names the count ("2 answers need fixing"). List each error as `<a href="#field-id">` with the same words as the message at the field; following a link focuses that field. Call `.focus()` on the summary after the submit. Prefix `document.title` with "Error - " until every error is fixed, then restore it. Keep the messages at the fields as well (S9) |
| Sources | s-gov-summary-1, s-gov-summary-2, s-gov-summary-3, s-pf-alert-2, s-fluent-msgbar-2, s-smashing-errors-1 |

### S11 Check answers on submit, keep everything entered, and clear each error as soon as it is fixed

| Item | Value |
|---|---|
| Use when | A page has fields the reader fills in |
| Do not use when | A field has a meter that guides while typing, such as a character count or password strength, and update that meter live instead |
| How | Show no error while the reader is typing, and none when focus leaves a field the reader has not changed. Check every answer on submit. Once an error shows, recheck that field on each `input` event, and remove its message, its `aria-invalid`, and its summary link the moment the answer is valid. Never clear or reset any field when showing errors, including the fields that were right. Keep entered values when the reader switches tabs or closes a dialog |
| Sources | s-nng-error-5, s-smashing-errors-3, s-baymard-inline, s-carbon-forms, s-gov-error-3, s-nng-error-4, s-dads-error-timing |

### S12 When the whole page cannot work, replace its content with a plain message and a way forward

| Item | Value |
|---|---|
| Use when | The page cannot show its main content at all, for example its data cannot be read or its script fails |
| Do not use when | Only one section failed, and show the error in that section with S9 instead |
| How | Keep the header with its title and switches. Replace the content of `<main>` with `<section class="page-error">` whose `<h2 tabindex="-1">` says what cannot be done ("The approval list cannot be shown"), and move focus to it. Add one sentence on what happened to the reader's work ("Your choices so far are kept in this browser"). End with one to three ways forward as buttons or links, such as Try again or Copy what you have. Follow S7 and S8 for the words |
| Sources | s-gov-problem, s-gov-error-5, s-pf-empty-4, s-carbon-empty-3 |

### S13 Match the notice to how far it reaches and how urgent it is

| Item | Value |
|---|---|
| Use when | The page must tell the reader something outside its main content, such as a condition, a result, or a risk |
| Do not use when | The text explains how the page or a figure works, and write it as body text with S14 instead |
| How | Put text about one item or control inline, next to it. Put a condition of the whole page, such as data that is a week old or an approval that closes Friday, in one banner under the title (S15). Confirm an action the reader just took in place, and with a toast only when the place may be out of view (S16). Use a `<dialog role="alertdialog">` only when the reader must decide before going on, such as discarding changes; never open a dialog that only informs. Every banner and toast also goes into the notifications panel (S17) |
| Sources | s-apple-feedback-1, s-carbon-notif-pattern-1, s-m3-snackbar-1, s-gov-banner-1, s-apple-alerts-2, s-apg-alertdialog |

### S14 Keep explanations and warnings apart, and warn sparingly

| Item | Value |
|---|---|
| Use when | A page holds both text that explains and text that warns of a risk or a needed action |
| Do not use when | The text reports a failure, and use the error of S7 and S9 instead |
| How | Write explanations as plain body paragraphs in the text color, with no icon, border, or tinted box; supplementary help goes behind the ? button. Put each warning in its own block after the explanation it belongs to, never inside a paragraph, as `<div class="caution">` with a warning icon, a title that names the risk ("Approving sends the order"), and one or two sentences, on `--warn-soft` with `--warn` text. Warn only where the reader can lose work, money, or access, or must act. Show at most two warning blocks on the first screen and combine the rest. Do not show a warning again after the reader acted on it. A warning already in the page at load gets no `role="alert"` (S20) |
| Sources | s-apple-alerts-2, s-fluent-msgbar-3, s-gov-banner-3, s-carbon-notif-pattern-4, s-apg-alert-4, s-smashing-notif, s-sap-messaging-3, s-wcag-interruptions-1 |

### S15 Show at most one page banner, directly under the page title, in the page flow

| Item | Value |
|---|---|
| Use when | A condition affects the whole page, such as stale data, a deadline, a page-wide error, or a step the reader must take before approving |
| Do not use when | The message concerns one field, row, or section, and put it there with S9 or S14 instead |
| How | Place one `<div class="banner">` as the first element of `<main>`, directly under the header that holds the title, as wide as the content. Give it a 20px icon, a title that names the point, one or two sentences, and a link or button when there is something to do. Combine several page-wide messages into one banner, the most severe first, colored by the most severe. Keep it in the flow so it scrolls with the page; never use `position: fixed` or `sticky`, and never cover content. A warning or error banner stays until its cause is fixed and has no close button. An information banner may have a close icon button with `aria-label="Close"`; store the close in `localStorage` inside try and catch, and keep the notice in the notifications panel (S17) |
| Sources | s-pf-alert-1, s-gov-banner-2, s-carbon-notif-pattern-2, s-carbon-notif-1, s-pf-alert-3, s-fluent-msgbar-5, s-apg-alert-3, s-dads-banner-top, s-dads-banner-parts, s-dads-banner-close |

### S16 Use a toast only for a short confirmation that is also shown in place

| Item | Value |
|---|---|
| Use when | An action the reader just took has finished and its result may be out of view, such as "Copied" or "Saved" |
| Do not use when | The message is an error or a warning, or it needs an action, and use S9 or S15 instead |
| How | Keep one empty `<div class="toast" role="status">` in the HTML from load, fixed at the bottom center (`left: 50%; transform: translateX(-50%)`), 16px above the bottom edge or above a fixed action bar, at most `min(480px, 100vw - 32px)` wide, never over the action buttons. Show one toast at a time; a new one replaces the old one, and similar results merge ("3 items copied"). Put text only, with no button or link. Remove it after 8 seconds, pause the timer on `mouseenter` and `focusin`, and restart it on `mouseleave` and `focusout`. Show the same result in place too (the button reads "Copied", the save state reads "Saved"), and add it to the notifications panel (S17). Fade it in over 150 to 250ms, with no motion under reduced motion |
| Sources | s-m3-snackbar-2, s-m3-snackbar-3, s-m3-snackbar-a11y-1, s-sap-toast-1, s-pf-alert-4, s-fluent-toast-1, s-fluent-toast-3, s-nng-indicators-1, s-smashing-errors-2, s-carbon-notif-pattern-3 |

### S17 Keep every notice readable again in a panel opened from a header button

| Item | Value |
|---|---|
| Use when | The page shows banners, toasts, or other notices the reader may want to read again after they fade or close |
| Do not use when | The page shows no notice at all, and leave the button out instead |
| How | Put `<button type="button" class="icon" aria-haspopup="dialog" aria-controls="notices">` with an inline bell icon in the header `.controls`, before the language switch. Pressing it opens `<dialog id="notices">` with `showModal()`, titled "Notifications", at most `min(480px, 100vw - 32px)` wide. List every notice newest first, each with its time, its title, its full text, and a link to the place on the page it concerns. Escape and the close icon close the panel, and focus returns to the bell button. Show the unread count as a badge on the button (S18) and clear it when the panel opens. Never make a toast the only place a result or an action appears |
| Sources | s-fluent-toast-2, s-carbon-notif-2, s-pf-alert-5, s-nng-indicators-2, s-wcag-timing, s-pf-badge, s-apple-notifications |

### S18 Cap badge counts at 99+ and name what they count

| Item | Value |
|---|---|
| Use when | A button or tab shows how many new or waiting items it leads to |
| Do not use when | The exact number does not matter to the reader, and show an 8px dot with an accessible name such as "Notifications, new" instead |
| How | Place the badge on the top right corner of the button, or right after a tab label. Use 12px bold text, 18px height, 18px minimum width, 5px side padding, and a 9px radius, with text and background at 4.5:1 or more. Show "99+" above 99. Mark the visible badge `aria-hidden="true"` and put the count and what it counts in the button's accessible name ("Notifications, 3 unread"). Update the number as soon as items are read, and remove the badge at zero instead of showing "0" |
| Sources | s-carbon-status-6, s-carbon-status-7, s-m3-badges-1, s-m3-badges-2, s-fluent-badge-2, s-wcag-status-5, s-apple-notifications |

### S19 Write the notice title as the point itself, and say exactly what changed

| Item | Value |
|---|---|
| Use when | Writing the title and text of a banner, toast, warning, or confirmation |
| Do not use when | The text is an error message, and write it with S7 instead |
| How | Make the title the fact itself in about six words or fewer, such as "Data is from 14 November", "Request approved", or "3 items copied", never "Warning", "Info", "Notice", or "Success". Keep the body to one or two short sentences with the key word first. Name the object and the change with a past verb in a confirmation ("Order deleted"), and leave out "successfully" and "has been". Confirm only actions that matter or whose result is not already visible. Include the number or name the reader would check |
| Sources | s-fluent-msgbar-4, s-fluent-msgbar-6, s-pf-alert-6, s-carbon-notif-3, s-apple-feedback-3, s-sap-toast-2 |

### S20 Announce notices that appear after load without moving focus

| Item | Value |
|---|---|
| Use when | A notice, status, or error appears or changes after the page has loaded |
| Do not use when | The reader submitted a form with errors, and move focus to the error summary with S10 instead |
| How | Keep each live region in the HTML from load, empty, and change only its text later; a region inserted together with its text is often not read. Use `role="status"` for progress, results, saves, and confirmations. Use `role="alert"` only for an urgent failure the reader must hear now, such as a failed save, and never for information or success. Do not call `.focus()` on a toast, banner, or status. A notice already in the page at load is plain content with a heading and no live role |
| Sources | s-wcag-status-3, s-wcag-status-4, s-apg-alert-1, s-apg-alert-2, s-m3-snackbar-a11y-2 |

### S21 Show every status with text and an icon or shape, never with color alone

| Item | Value |
|---|---|
| Use when | A row, card, or field carries a state such as approved, overdue, failed, or saved |
| Do not use when | The state is a count of new items, and use the badge of S18 instead |
| How | Write the status as text, `<span class="tag">Overdue</span>`, with a 14 to 16px inline SVG icon before it marked `aria-hidden="true"`, a check for good, a triangle for warning, a cross in a circle for critical, and an "i" in a circle for information. The text carries the meaning, so a reader who cannot see color still reads it. Give status text a contrast of 4.5:1 or more with its background, and icons, dots, and borders 3:1 or more, in both light and dark themes. A colored row edge or dot is never the only sign of a status. A field in error gets an icon and a border, not only a red outline |
| Sources | s-wcag-color, s-wcag-nontext, s-carbon-status-1, s-carbon-status-3, s-carbon-status-8, s-pf-status-1, s-gov-tag-1, s-apple-color, s-smashing-errors-4, s-dads-contrast |

### S22 Give each status color one meaning, and keep it apart from the accent color

| Item | Value |
|---|---|
| Use when | The page colors states, notices, or errors |
| Do not use when | The color marks a link, a selected row, or the primary button, and use the accent color instead |
| How | Define `--good` (green), `--warn` (amber), and `--critical` (red), each with a `-soft` background, on `:root` and again for dark, and use the `--sub` gray for information. Never use `--accent` for a state, and never use a status color for links, selection, or buttons. Keep each meaning the same across the page, so the same label always has the same color and no color stands for two opposite states. When the accent is blue, information stays gray rather than blue |
| Sources | s-carbon-status-2, s-pf-status-2, s-sap-colors, s-gov-tag-2, s-nng-forms-errors, s-dads-color-meaning |

### S23 Name states with one or two describing words, keep them few, and order them by severity

| Item | Value |
|---|---|
| Use when | A page lists items that each carry a state |
| Do not use when | The text tells the reader what to do, such as "Approve now", and make it a button instead |
| How | Write each state as one or two words that describe it ("Approved", "Overdue", "Waiting"), not a verb or a sentence. Never wrap a status tag in `<a>` or `<button>`; put the action next to it. Use about five distinct states or fewer on one page. When a group or a folded row holds several states, show its most severe state and color. Order mixed states from the most severe to the least |
| Sources | s-gov-tag-3, s-gov-tag-4, s-fluent-badge-1, s-carbon-status-4, s-carbon-status-5, s-pf-status-3 |

### S24 Show the save state at the top right of the page as text that stays

| Item | Value |
|---|---|
| Use when | The reader can change anything on the page that is kept, such as choices, answers, or notes |
| Do not use when | The page only shows content and nothing in it can change, and leave the save state out instead |
| How | Put `<p class="save-state" role="status">` at the right of the sticky header, as the first item in `.controls` before the notifications button and the switches, so it stays in view while the reader scrolls. It reads "Unsaved changes" in `--warn` with a filled dot, "Saving" with a 12px turning ring, "Saved 14:05" in `--sub` with a check, or "Not saved" in `--critical` with its icon and a "Try again" button beside it. Use 13px text and never an icon alone. Change it the moment the state changes, never only in a toast. At phone width keep it in the header, shortened to "Unsaved" or "Saved" |
| Sources | s-nng-autosave, s-nng-visibility-2, s-m3-snackbar-a11y-3 |

### S25 Warn before the reader leaves the page with unsaved changes

| Item | Value |
|---|---|
| Use when | The save state reads "Unsaved changes" or "Not saved" |
| Do not use when | Everything is saved, and let the page close without a prompt instead |
| How | While changes are unsaved, keep a `beforeunload` listener that calls `event.preventDefault()` and sets `event.returnValue = ""`, and remove it as soon as the save state reads "Saved". The browser shows its own text. When the reader leaves edits inside the page, such as closing a dialog, open a `<dialog>` titled "Discard your changes" with "Keep editing" focused first and "Discard" beside it |
| Sources | s-sap-messaging-1, s-apple-feedback-2, s-wcag-interruptions-2 |

## Where the sources disagree

| Question | What the sources say | Took | Why |
|---|---|---|---|
| Should a loading region show a skeleton | NN/g, Carbon, Fluent 2, PatternFly, and Apple recommend skeletons or placeholders when the layout is known; the Digital Agency of Japan forbids skeleton screens | No skeleton; one indicator in the center of the area (S3) | Loading belongs in the center of the area that is loading, and a self-contained page carries its content inline, so a gray frame only looks broken |
| Where a loading indicator sits | Material 3 and PatternFly center it on the area or button that is loading; Carbon also allows it near the button that started it; Apple asks only for a consistent place | The center of the area that is loading, or of the button (S3, S6) | One place for every region keeps the reader's eyes where the content will appear |
| Turning or still indicator | The Digital Agency of Japan uses a still hourglass when part of the screen is busy; NN/g warns against static indicators, and WCAG 2.2.2 counts a preload animation as essential | A turning ring with a text label, still under reduced motion (S3) | Movement shows that the work has not stalled, and the label keeps the meaning when the page turns motion off |
| When to start showing an indicator | Material 3 from 200ms; NN/g, Fluent 2, PatternFly, and SAP Fiori at about 1 second; Carbon at 3 seconds | About 1 second (S3) | Most sources agree on it, and it avoids a flash for the fast work a self-contained page does |
| Whether "Loading" is too vague | Apple and Fluent 2 avoid vague words such as loading; Material 3, NN/g, and Carbon label indicators "Loading" plus the content | "Loading" with the content named (S4) | Naming the content answers Apple's concern while keeping the word every reader knows |
| When field errors appear | Carbon checks when a field loses focus; Baymard and NN/g favor live checks for error-prone fields; the Digital Agency of Japan and Smashing prefer checking on submit | Check on submit, then clear each error live (S11) | The pages have few fields, so checking on submit avoids errors shown too early, and clearing live confirms each fix |
| Where the error summary goes | GOV.UK, PatternFly, and Fluent 2 put it at the top of the form and move focus there; Carbon puts form notices above the submit buttons; Smashing puts it above the button when the page does not reload | The top of the form, with focus moved to it (S10) | The templates keep the action buttons in a fixed bottom bar, where a summary would cover content, and moving focus brings the top summary into view |
| Whether an error can go in a toast | Fluent 2 has error toasts and PatternFly uses toasts for actions completed with errors; NN/g, Smashing, SAP Fiori, and Carbon for critical messages reject them | No error or warning in a toast (S16) | A toast fades while the reader may be looking elsewhere, and an error must stay at its cause until it is fixed |
| Where toasts appear | Carbon, Fluent 2, and PatternFly on desktop use the top right; Material 3 uses the bottom, and SAP Fiori the bottom center | The bottom center (S16) | The top right holds the save state and the notifications button, and one bottom spot works at phone width |
| How long a toast stays | SAP Fiori at least 3 seconds; WCAG's example 5 seconds; Fluent 2 7 seconds; PatternFly 8 seconds; the APG says to avoid alerts that disappear | 8 seconds with a pause on hover and focus, only for results also shown in place (S16) | The longest common value gives slow readers time, and the copy in place and in the panel answers the APG's concern |
| How many toasts at once | Material 3 one; PatternFly three; Fluent 2 four | One (S16) | A phone-width page has room for one, and these pages rarely produce several results at once |
| How many page banners, and where | GOV.UK allows one, placed before the h1; Fluent 2 stacks several by severity; PatternFly puts it below the title, Carbon below the main header | One combined banner, first in the main content under the title (S15) | The templates keep the title in a sticky header, and one banner keeps the first phone screen usable |
| Whether a warning banner can be closed | Carbon leaves out the close button on critical notices; Fluent 2 lets readers close warnings and shows them again next session; the Digital Agency of Japan and SAP Fiori keep a closed banner hidden | Warnings and errors have no close button; information can be closed and stays in the panel (S15) | A warning closed before it is resolved hides a real risk, while information read once should not keep taking space |
| How errors are marked for screen readers | GOV.UK starts the page title with "Error" and a colon and puts a hidden "Error" and a colon before each field message; the look rules of this skill forbid a colon in a title and between a label and a value | "Error - " before the title and a hidden "Error." before each message (S9, S10) | `verify` flags the colon, and the word Error still comes first for screen readers |
| Moving focus to a notice | Material 3, the APG, and WCAG 4.1.3 say not to move focus; Carbon focuses notices with actions; GOV.UK and Fluent 2 move focus to the error summary | No focus move, except to the error summary after a failed submit (S10, S20) | The reader keeps their place, yet lands on what blocks the submit |
| Saying "Success" | Fluent 2, PatternFly, and SAP Fiori drop "success" and "successfully"; GOV.UK titles green banners "Success" so color is not the only sign | A title that names the outcome, such as "Request approved" (S19) | It gives the label beyond color that GOV.UK wants, without the filler the others reject |
| Badge count cap | Material 3 allows four characters ("999+"); Carbon allows three ("99+") | "99+" (S18) | A narrow badge fits a phone header, and beyond 99 the exact count rarely changes what the reader does |
| Apologies on a failure page | GOV.UK titles its failure page "Sorry, there is a problem with the service"; NN/g allows an apology during severe outages; Apple and Carbon reject jokes | No apology and no humor, a plain heading (S8, S12) | An apology takes the place of what the reader needs, which is what happened to their work and what to do now |
| Error codes on the screen | NN/g allows codes for technical diagnosis; Apple rejects codes as a title; GOV.UK asks for plain English | No codes or raw error text on the screen (S7) | The readers of these pages act on the message and do not debug the script, so a code only sends them searching |
| Where an empty message sits | Carbon left-aligns the empty state block; PatternFly centers it in tables and cards | Centered in the area it replaces (S1) | The empty message then appears where the loading indicator stood, so the eyes do not jump |
| Where the save state sits | SAP Fiori puts the draft switch next to the page title; Material 3 changes the Save button label; Apple puts status near the items it describes; no source names the top right | The top right of the page in the sticky header (S24) | One fixed place that stays in view while scrolling lets the reader check the state from anywhere, and the button label can still change as a second sign (S6) |
| Color for information and success | NN/g allows green or blue for success, and blue is also the usual accent hue of these pages; Carbon names red, orange, yellow, and green for states | Gray for information; green, amber, and red only for states, never the accent (S22) | When a state shares the accent color, readers cannot tell a state from a link, a selected row, or the primary button |
| Where past notices can be read again | Material 3 repeats a result inline near the action; Fluent 2 and Carbon say it must be findable elsewhere without naming where | In place and in the panel from a header button (S16, S17) | A header button is reachable from any scroll position and keeps every notice in one list, so a faded toast loses nothing |
