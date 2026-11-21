# Input and confirmation

This file decides how a page lets a person pick, type, confirm, and copy a text back to the chat.
Read it when a page has rows or cards to pick, a field to fill, a destructive action to confirm, or a text to copy.
The look of the page comes from `look.md`, and these rules add how its inputs behave.

## Choose between

| You need | Use | Rule |
|---|---|---|
| The person picks one answer from five or fewer | A named radio group shown as rows or cards, with nothing picked at the start | I1, I2, I5 |
| The person picks several items from a list | Rows that toggle a check mark when pressed | I1, I2, I4 |
| The person compares options with pictures and picks one | Cards that pick on a press, with an enlarge icon beside the select target | I2, I3 |
| A setting changes what the page shows at once | A switch or a segmented control | I6 |
| The person types a reason or a note | A labelled field on the page, in one column | I7, I8, I9 |
| An answer is missing or wrong when the main button is pressed | Error text above the field and a message beside the button | I10, I11, I12, I13, I14 |
| Buttons for the page, a panel, or a dialog | Short verbs, one primary button, a fixed place | I15, I16, I17 |
| The text or a button will delete, cancel, pay, or send | A review that names the action and every picked item | I18, I19, I21 |
| The page itself must confirm before it acts | A modal confirmation dialog with focus on Cancel | I19, I20, I22 |
| A change that stays inside the page, such as clearing the picks | Undo in place, with no confirmation | I23 |
| The page ends in a text for the chat | A copy button, a read-only text, and a status line | I24, I25 |

## Rules

### I1 Show every option at once as one group with a visible name

| Item | Value |
|---|---|
| Use when | The person answers one question from a short list, or picks items from a list of rows. |
| Do not use when | One answer comes from a long list that does not fit on the screen, such as a country, and use a `<select>` with a visible label instead. |
| How | Wrap the options in `<fieldset>` with a `<legend>` that asks the question, or give a custom group `role="radiogroup"` or `role="group"` and `aria-labelledby` pointing at a visible heading. Use radio behavior when only one answer counts, for up to five options. Use check marks when several can be picked. Stack the options one per line with the mark at the start of the line. Option cards with pictures may sit side by side in their own sideways-scrolling box, since they are compared. |
| Sources | i-gov-radios-1, i-m3-radio, i-nng-choice-1, i-hig-toggles, i-apg-radio, i-nng-choice-2, i-dads-radio-five, i-dads-radio-single, i-dads-checkbox-left |

### I2 Let the person pick by pressing the whole row or card

| Item | Value |
|---|---|
| Use when | The person picks items on an approval sheet or one option on a choice page. |
| Do not use when | The control is one setting that applies at once, and use a switch (I6) instead. |
| How | For several picks, make each row one `<button type="button" aria-pressed="false">`, or one `<label>` that wraps its `<input type="checkbox">`. For one answer, put `<input type="radio">` inside each card's `<label>`, or give each card `role="radio"` and `aria-checked` inside the group of I1, so Arrow keys move between options. The whole row or card is the target, never only the box. Show a mark on every selectable row or card, empty when off and filled with a check when on, and also tint the picked row and draw its edge in the accent, so color is not the only sign. In a list with a detail panel, the same press shows the row in `.detail` inside `.split`. |
| Sources | i-nng-choice-3, i-pf-card-1, i-carbon-tile-1, i-carbon-tile-2, i-pf-card-2 |

### I3 Keep each selectable card one target with enlarge as an icon beside it

| Item | Value |
|---|---|
| Use when | A selectable card holds a picture the person may want to see larger. |
| Do not use when | The card needs links or more actions than enlarge, and use a list row that shows those actions in the detail panel instead. |
| How | Never nest a button or a link inside the card's select target. Wrap the card in a `<div>` with `position: relative`, let the select `<label>` or `<button>` fill it, and place the enlarge `<button type="button">` as a sibling in the top right corner. The enlarge button shows an icon only, takes its `aria-label` from the page's dictionary, opens the picture in a dialog, and leaves the pick unchanged. A press anywhere else on the card picks it. |
| Sources | i-carbon-tile-3, i-pf-card-3 |

### I4 Make every target at least 24 px square and rows and main buttons 44 px tall

| Item | Value |
|---|---|
| Use when | Any button, row, card, mark, or icon can be pressed. |
| Do not use when | The target is a link inside running text, and keep it at the size of the text instead. |
| How | Give icon buttons, such as close, enlarge, and help, a `min-width` and `min-height` of at least 24px; 32px is the usual size. Give selectable rows and the main buttons `min-height: 44px`. Measure the box that takes the press, not the visible glyph. Keep a gap between neighboring icon buttons so a press never lands on the wrong one. |
| Sources | i-wcag-target, i-hig-buttons-1, i-dads-button-target |

### I5 Leave a decision unpicked and offer a keep-as-is option when no change is a valid answer

| Item | Value |
|---|---|
| Use when | The person decides between options, such as approve or reject, or picks a new version on a choice page. |
| Do not use when | The setting is low risk and has a usual value, such as the theme, and start it on that value instead. |
| How | Start every decision with nothing picked, and show "Nothing picked yet" from the dictionary where the pick is summed up. When keeping things as they are is a valid answer, add it as its own option with a plain name, such as "Keep today's board", last in the group. Since a picked radio group cannot be emptied, that option is also the way to take a pick back. The copied text names it with a fixed word, such as `pick today`, and writes `pick none` when nothing is picked. |
| Sources | i-carbon-forms-3, i-fluent-radio, i-gov-radios-2, i-dads-radio-none |

### I6 Use a switch or a segmented control only for a view setting that applies at once

| Item | Value |
|---|---|
| Use when | A setting changes what the page shows the moment it is pressed, such as the language, the theme, or showing only the picked rows. |
| Do not use when | The choice is part of the answer that waits for the main button or the copy, and use the rows or the radio group of I1 and I2 instead. |
| How | A switch is `<button role="switch" aria-checked="false">` with a short label naming what it shows when on, such as "Only picked rows", never a question and never "Turn on". A segmented control holds two to five buttons of the same kind and similar length, text only or icons only, each with `aria-pressed`. The change applies on the press, with no Save button. Keep the language and theme controls side by side in the header, as `look.md` asks. |
| Sources | i-nng-toggle, i-m3-switch, i-smashing-toggle, i-fluent-switch, i-m3-segmented, i-hig-segmented |

### I7 Put fields on the page in one column no wider than 720 px

| Item | Value |
|---|---|
| Use when | The page asks the person to type, such as a reason for rejecting or a note on which options to mix. |
| Do not use when | Two or three inputs form one value, such as the start and end of a date range, and put those on one line instead. |
| How | Place each field in the page body, in one column with `max-width: 720px`, never in a dialog and never in two columns at any width. A dialog holds at most a confirmation with one field, such as a typed name (I22). Keep everything the task needs on this one page, so the person finishes where they started. |
| Sources | i-nng-forms-1, i-baymard-columns-1, i-baymard-columns-2, i-carbon-forms-1, i-fluent-dialog-1, i-carbon-modal-1, i-dads-stacked-fields, i-dads-form-on-page |

### I8 Put a visible label above each field and its hint between the label and the field

| Item | Value |
|---|---|
| Use when | Any field, text area, or select asks for input. |
| Do not use when | The text is read-only output, such as the text to copy, and give it a `<label>` naming what it is instead. |
| How | Write a `<label for>` above the field as a short question or name. Put a hint, when one is needed, as a `<p>` between the label and the field, linked with `aria-describedby`, in one short sentence with no full stop. Set no `placeholder`; an example goes in the hint. Keep label and hint text in the dictionary, so both switch with the language. |
| Sources | i-gov-question-1, i-nng-placeholder-1, i-carbon-forms-2, i-wcag-labels-1, i-gov-question-2, i-nng-placeholder-2, i-dads-placeholder, i-dads-support-text |

### I9 Mark optional fields with the word optional in the label

| Item | Value |
|---|---|
| Use when | A page mixes fields the person must fill with fields they may leave empty. |
| Do not use when | Every field must be filled, and say so once above the first field instead. |
| How | Add "(optional)" from the dictionary to the end of the label of each optional field. Never use an asterisk as the only mark. Set `required` or `aria-required="true"` on each field that must be filled. Keep optional fields to one or two, and leave out any field the task does not need. |
| Sources | i-gov-question-3, i-baymard-required, i-nng-forms-2, i-pf-forms-1, i-wcag-labels-2, i-dads-required-optional |

### I10 Check the answers when the main button is pressed and clear each error once it is fixed

| Item | Value |
|---|---|
| Use when | A field must be filled or must follow a format before the text can be made. |
| Do not use when | Nothing on the page can be wrong, such as rows that are only picked, and make the text at once instead. |
| How | Run the checks in the click handler of the main button, not on `input`, `keyup`, or `blur`. When a check fails, make no text and copy nothing. After a field shows an error, check it again on each `input` event and remove the error text and `aria-invalid` the moment the value passes. Never add a new error while the person types. |
| Sources | i-gov-validation-1, i-baymard-inline, i-nng-errors-forms, i-smashing-inline-1, i-carbon-forms-4, i-dads-error-timing |

### I11 Show each error as text above its field and in a message beside the main button

| Item | Value |
|---|---|
| Use when | A check of I10 fails. |
| Do not use when | The problem is not tied to a field, such as the clipboard refusing the copy, and say it in the status line of I24 instead. |
| How | Put the error in a `<p>` after the hint and before the field, starting with an "Error" word from the dictionary and a warning icon, in the critical color. Set `aria-invalid="true"` on the field and add the error's id to its `aria-describedby`. Beside the main button, show a message that lists every error in the same words, each a link to `#field-id` that moves focus to its field. Give that message `tabindex="-1"` and move focus to it after the press. Start `document.title` with the same "Error" word until the errors are gone. |
| Sources | i-wcag-error-id-1, i-wcag-error-id-2, i-gov-error-message-1, i-gov-error-message-2, i-gov-error-summary-1, i-gov-error-summary-2, i-fiori-validation |

### I12 Write each error as what to do in plain words

| Item | Value |
|---|---|
| Use when | Writing the text of an error, in both languages of the dictionary. |
| Do not use when | The message reports a success, such as a finished copy, and say what happened (I25) instead. |
| How | Say what to do for this field, such as "Enter a reason for rejecting" or "Pick at least one item", never only "Required", "Invalid", or "This field is required". Leave out blame, jargon, error codes, apologies, "please", and "oops". Use the same words in the field message and in the message beside the button. Write the Japanese entry with the same meaning, not as a word-for-word copy. |
| Sources | i-gov-error-message-3, i-gov-error-message-4, i-nng-error-message-1, i-nng-error-message-2, i-wcag-error-suggestion, i-fiori-message-box, i-dads-error-content |

### I13 Keep every pick and every typed word when the page draws itself again

| Item | Value |
|---|---|
| Use when | The page re-renders, such as on a language or theme switch, a tab change, or an error. |
| Do not use when | The person asks to start over, and offer a "Clear" button with undo in place (I23) instead. |
| How | Keep the picks in one state object, such as a `Set` of item ids, and never rebuild a `<textarea>` or `<input>` from markup on render; update only the text around it. A language switch changes the labels and keeps the note, the cursor, and the picks. Never call `form.reset()` or clear a `value` when a check fails. Moving between tabs keeps the picks of the other tabs, and the count of picks covers every tab. |
| Sources | i-gov-validation-2, i-nng-forms-3, i-nng-error-message-3, i-wcag-error-prevention-1 |

### I14 Keep the main button enabled and say next to it what is still missing

| Item | Value |
|---|---|
| Use when | The main button, such as "Make the text" or "Copy", cannot make a useful text yet, for example with nothing picked. |
| Do not use when | The button can never act on this page, such as on a page of finished results, and leave it out instead. |
| How | Leave out `disabled`, so the button stays in the Tab order and keeps full contrast. Show next to it, in the docked bar or under it, a line that names what to do, such as "Nothing picked yet". A press that comes too early makes no text and shows the reason in that line, written as I12 asks. |
| Sources | i-gov-button-1, i-smashing-inline-2, i-carbon-forms-5, i-pf-forms-2, i-dads-disabled-reason |

### I15 Name each button with a short verb in sentence case

| Item | Value |
|---|---|
| Use when | Writing the label of any button that shows text. |
| Do not use when | The button closes, enlarges, or opens help, and use an icon with an `aria-label` from the dictionary instead. |
| How | Start with a verb that says what happens, such as "Copy", "Delete", or "Make the text", in at most three words, and add an object only when the verb alone does not say what it acts on. Never use "Submit", "OK", "Yes", "No", or "Done". Write in sentence case. Close is an icon button showing `&#x2715;`, enlarge is an icon button, and help is a ? icon, each with an `aria-label` that switches with the language. |
| Sources | i-gov-button-2, i-hig-buttons-2, i-fiori-button-1, i-fluent-button, i-nng-confirm-3 |

### I16 Give each page and each dialog one primary button

| Item | Value |
|---|---|
| Use when | A page or a dialog holds more than one action. |
| Do not use when | A dialog only shows content, such as an enlarged figure or the help, and give it only the close icon instead. |
| How | Fill the main action, such as "Make the text" or "Copy", with the accent color. Draw every other action with a border and no fill, or as a text button. In a destructive confirmation, the confirming button is the one filled button and takes the danger color of I21, but it is never the default button that Enter presses. |
| Sources | i-gov-button-3, i-carbon-button-1, i-m3-buttons, i-smashing-forms, i-dads-primary-button |

### I17 Put the main button after the last field and in the same place on every page

| Item | Value |
|---|---|
| Use when | Placing the buttons of a form, a panel, or a dialog. |
| Do not use when | The page has no fields and one action for the whole page, such as an approval sheet, and dock that button in a bar fixed to the bottom of the viewport instead. |
| How | In the page body, put the buttons under the last field, aligned to the start edge with the fields, never only at the top. In a bar docked to the bottom, put the count of picks at the start and the main button at the end. In a dialog, put Cancel and then the confirming button at the end of the bottom row. On screens under 480px wide, let the buttons fill the width and stack. Keep the same placement on every page the skill makes. |
| Sources | i-carbon-forms-6, i-pf-forms-3, i-gov-validation-3, i-nng-ok-cancel |

### I18 Name the action and every picked item before a destructive action runs

| Item | Value |
|---|---|
| Use when | A button or the copied text will delete, cancel, pay, send, or change anything outside the page. |
| Do not use when | The change stays inside the page, such as unpicking a row, and let it be undone in place (I23) instead. |
| How | Before the action runs or the text is copied, show a review in the dialog or panel that holds the final button. Its title is the verb, the count, and the object, such as "Delete 3 files" or "Take 2 items off the menu", never "Are you sure?". Under it, list every picked item by name, then one sentence on the consequence, such as whether the items can come back. The action and the copied text cover only the picked items, each named by its id, never "all" or a filter. On an approval sheet, the review sits in the dialog that shows the copied text, so one press still copies. |
| Sources | i-nng-confirm-2, i-m3-dialogs-1, i-pf-modal-1, i-fluent-dialog-2, i-wcag-error-prevention-2, i-hig-alerts-1 |

### I19 Label the confirming button with the verb of the title next to a Cancel that changes nothing

| Item | Value |
|---|---|
| Use when | A dialog or a panel asks the person to confirm an action. |
| Do not use when | The dialog only informs, and close it with the close icon instead. |
| How | Repeat the title's verb on the confirming button, such as "Delete" under "Delete 3 files", and never write "OK", "Yes", or "Done". Put a "Cancel" button beside it that closes the dialog and leaves the picks, the fields, and the page as they were. Escape does the same as Cancel; with `<dialog>`, handle its `cancel` event the same way. |
| Sources | i-hig-alerts-2, i-hig-alerts-3, i-fluent-dialog-3, i-carbon-modal-2, i-m3-dialogs-2, i-nng-confirm-3, i-apg-dialog-1, i-dads-close-button |

### I20 Build the page's own confirmation as a modal dialog that opens on a press and focuses Cancel

| Item | Value |
|---|---|
| Use when | The page itself is about to run an action that I18 asks to review. |
| Do not use when | The change stays inside the page and can be reversed, and offer undo in place (I23) instead. |
| How | Use `<dialog>` opened with `showModal()` from a click handler, never on load. Give it `role="alertdialog"`, `aria-labelledby` pointing at the title, and `aria-describedby` pointing at the consequence. `showModal()` keeps Tab and Shift+Tab inside; a dialog built without it needs `aria-modal="true"` and its own focus trap. On open, focus Cancel, not the destructive button. On close, return focus to the button that opened the dialog. |
| Sources | i-apg-alertdialog-1, i-apg-alertdialog-2, i-apg-dialog-2, i-apg-dialog-3, i-apg-dialog-4, i-hig-buttons-3, i-hig-alerts-4, i-dads-destructive-modal, i-dads-modal-on-press |

### I21 Give the danger color only to the button that performs the destruction

| Item | Value |
|---|---|
| Use when | A button deletes, cancels, or removes something that the page cannot bring back. |
| Do not use when | The button only opens the review or the confirmation, and give it the plain or primary style instead. |
| How | Fill the final confirming button with a critical color token, such as `--critical`, kept apart from the accent and defined for both themes, with text at a contrast of at least 4.5 to 1. Keep its verb label, so the color is never the only sign. The button that opens the confirmation stays neutral. |
| Sources | i-gov-button-4, i-pf-modal-2, i-carbon-button-2, i-hig-buttons-4 |

### I22 Ask for the name to be typed before the page removes one item that cannot come back

| Item | Value |
|---|---|
| Use when | The page is about to remove one item whose loss cannot be reversed, such as an account or a whole project. |
| Do not use when | Several items are picked, and list each of them by name in the review of I18 instead. |
| How | In the confirmation dialog, show the exact name in `<code>`, then a `<label>` that asks for it over an `<input type="text" autocomplete="off" spellcheck="false">`. Keep the confirming button enabled, as I14 asks. When the typed text does not match, the press does nothing and shows the error of I11, written as I12 asks. |
| Sources | i-smashing-danger, i-pf-modal-3, i-pf-actions |

### I23 Let a change inside the page be undone in place instead of confirmed

| Item | Value |
|---|---|
| Use when | The person changes only what the page holds, such as clearing every pick or emptying the note. |
| Do not use when | The change reaches outside the page, and name it in a review (I18) instead. |
| How | Apply the change at once, with no dialog. Show next to where it happened a line such as "Picks cleared" with an "Undo" button that brings back the exact earlier state. Keep the line until the person undoes, makes another change, or closes it with the close icon, and never hide it on a timer. Picking and unpicking a row need no undo, since a second press reverses it. |
| Sources | i-nng-undo, i-m3-snackbar-1, i-nng-confirm-1, i-hig-alerts-5, i-m3-snackbar-2, i-dads-undo-restore |

### I24 Copy the text for the chat with one press and select it when the clipboard is refused

| Item | Value |
|---|---|
| Use when | The page ends in a text the person pastes into the chat, as on an approval sheet or a choice page. |
| Do not use when | The page asks for nothing back, such as a report, and end it with its results and no copy panel instead. |
| How | Build the text in one function, such as `copyText()`, from fixed English words, item ids, and the person's note as typed, never from the dictionary, so it is the same in English and Japanese. Put a first line that names the skill and the verb, then one item per line. Show the text in a labelled `<textarea readonly>`, never with `user-select: none`. One press of the primary button calls `navigator.clipboard.writeText()`. When that is refused, focus the text area, call `select()`, and say in the status line to press Command+C or Ctrl+C. |
| Sources | i-pf-copy-1, i-pf-copy-2, i-pf-copy-3, i-carbon-snippet-1 |

### I25 Confirm the copy in a status line beside the button that stays until the text changes

| Item | Value |
|---|---|
| Use when | A copy, or another press that works without moving the person, needs to say it worked. |
| Do not use when | The press failed on a field, and show the error of I11 instead. |
| How | Put a `<p role="status">` next to the copy button and write "Copied. Paste it in the chat." from the dictionary on success. Do not move focus. Never use a toast that fades; keep the line until the next press. Clear it as soon as the picks or the note change, so it never claims that an older text was copied. |
| Sources | i-carbon-snippet-2, i-pf-copy-4, i-wcag-status, i-m3-snackbar-3, i-smashing-errors, i-fiori-button-2 |

## Where the sources disagree

| Question | What the sources say | Took | Why |
|---|---|---|---|
| How to mark required fields | Material 3, PatternFly, Fluent 2, and SAP Fiori put an asterisk after the label; GOV.UK says "Never mark mandatory fields with asterisks." and Carbon and the Digital Agency of Japan use words | The word "(optional)" on the few optional fields (I9) | A word needs no legend that a reader on a phone may scroll past, and a screen reader reads it with no extra markup. |
| Whether to pre-pick a radio option | NN/g, Material 3, Fluent 2, and Carbon offer a default; GOV.UK says "Do not pre-select radio options" | Nothing picked on a decision, and a default only for view settings (I5) | An approval must be a deliberate answer, and a pre-filled one can be copied without being read. |
| When to check a field | Carbon, PatternFly, and SAP Fiori check when the field loses focus; GOV.UK and the Digital Agency of Japan check on submit | On the press of the main button, then clear each error live (I10) | The pages have few fields, and errors that appear on blur shift the layout under a phone keyboard. |
| Whether to disable the main button until the input is complete | Apple HIG, Fluent 2, and Material 3 dialogs disable it, and Smashing Magazine blocks a type-to-confirm button until the name matches; GOV.UK, Smashing Magazine on forms, and Carbon and PatternFly for long forms avoid it | Keep it enabled and say next to it what is missing (I14, I22) | A disabled button is skipped by Tab and has poor contrast, and a press that only shows the reason does no harm. |
| Which side the main button goes | GOV.UK, Fluent 2, and PatternFly put it at the start under the fields; Apple HIG, Material 3, and Carbon dialogs put it at the trailing end | The start edge under the fields in the page body, and the end edge in a docked bar or a dialog (I17) | The body is read down the left edge of the fields, while in a bar or a dialog the summary of what happens is read first and the button ends the line. |
| Whether a placeholder may hold an example | Fluent 2, PatternFly, Baymard, and Apple HIG allow a short example as placeholder; NN/g calls placeholders in form fields harmful | No placeholder, and the example goes in the hint (I8) | The example disappears once the person types, which is when they compare against it. |
| Where the hint goes | GOV.UK, Carbon, and the Digital Agency of Japan put it after the label; PatternFly, Fluent 2, and Material 3 put it below the field | Between the label and the field (I8) | It is read before typing and is neither covered by the phone keyboard nor replaced by the error. |
| Where the error text goes | GOV.UK and Smashing Magazine put it above the input; Material 3, PatternFly, and Fluent 2 put it below, in place of the helper text | Above the field, after the hint (I11) | A person zoomed in on a phone sees the message before reaching the field. |
| Several pages or several columns | GOV.UK asks one question per page; SAP Fiori uses two columns on large screens; NN/g, Baymard, Carbon, and PatternFly ask for one column | Every field on one page, in one column (I7) | The owner wants the page to finish the task in place without leaving it, and the same file must work on a phone. |
| What to say for an empty required field | PatternFly accepts "Required"; GOV.UK lists "This field is required" among the messages to avoid | A specific instruction, such as "Enter a reason for rejecting" (I12) | The message says what to do without making the person read the label again. |
| Whether to confirm a destructive action that is easy to undo | Apple HIG, NN/g, and PatternFly say not to confirm undoable actions and to offer undo; SAP Fiori still confirms easy-to-undo deletions | Confirm every action that changes anything outside the page (I18), and use undo only for changes inside it (I23) | The owner wants a destructive action to run only on the picked items after a confirmation that names it, and such actions run later through the agent, where an undo on the page cannot reach. |
| Where focus starts in a destructive confirmation | Carbon focuses the primary button; Fluent 2 and the WAI-ARIA dialog pattern focus the first control; the WAI-ARIA pattern advises the least destructive action for irreversible ones, and Apple HIG sets no default button | Cancel (I20) | A stray Enter or Space then cannot perform the destruction. |
| Which button gets the red danger style | PatternFly keeps red off the button that opens a confirmation and puts it on the confirm button; GOV.UK and Smashing Magazine put red on the dangerous action itself | Neutral on the button that opens the confirmation, and red only on the final confirm (I21) | Red then means that this press does it, and the page does not alarm before the person has decided. |
| Whether a warning dialog may say OK | SAP Fiori warning boxes and Carbon acknowledgement modals use "OK"; Apple HIG, Material 3, Fluent 2, and Carbon's modal guidance name the action | A named verb, and never "OK" (I19) | A reader skimming on a phone sees the consequence on the button itself. |
| How many segments a segmented control holds | Material 3 allows two to five; Apple HIG allows about five to seven in a wide interface | Five at most (I6) | The same control must fit a phone, where Apple HIG also says about five. |
| Capitals in button labels | GOV.UK, Material 3, and Fluent 2 use sentence case; Apple HIG uses title case | Sentence case (I15) | Most sources agree, and it matches the running text of the page. |
| How long a button label is | Smashing Magazine asks for labels such as "Create my account" or "Subscribe to weekly offers"; SAP Fiori and Apple HIG use a single imperative verb | A short verb, with an object only when the verb alone is unclear (I15) | The owner names buttons with a short verb, and the title and the review already say what the verb acts on. |
| Whether a selectable card may hold other controls | Carbon says to avoid other click targets inside a clickable tile, and PatternFly stops a card that is both selectable and clickable from picking on a body press | One enlarge icon, as a sibling of the select target in the card's corner (I3) | A choice page compares pictures that must open larger, and keeping the icon outside the select target leaves one target per press. |
| Where the list of errors goes | GOV.UK puts the error summary at the top of the page and moves focus to it; PatternFly and Carbon add an inline alert to the form | Beside the main button, and it takes focus (I11) | On an approval sheet the main button sits in a bar docked to the bottom, where the person is looking, while the top of the page may be scrolled away. |
| How a finished copy is confirmed | Carbon and PatternFly confirm in a tooltip on the copy button; Material 3 says a message that hides itself must also appear inline | A status line beside the button that stays until the text changes (I25) | A tooltip disappears on its own, and a line in `role="status"` is read out without moving focus. |
