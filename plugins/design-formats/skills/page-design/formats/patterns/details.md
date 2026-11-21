# Details of a picked item

This file decides where the details of one item picked from a list or table appear, and how the reader opens them and gets back to the list.
It covers the panel beside the list, the single pane on narrow screens, the full-width view, rows expanded in place, expandable sections, and modal dialogs.
Read it when a page or document lets the reader pick an item and read more about it, and before you put anything in a dialog.

## Choose between

| You need | Use | Rule |
|---|---|---|
| Read one item at a time while the list stays in view, on a screen wider than 860px | A non-modal panel beside the list | D1, D2, D3, D5, D8, D9 |
| Read one item at a time on a phone or in a window 860px wide or narrower | One pane at a time, with a back button | D10, D11, D13 |
| Open an item from its row and reach it again from a link | One named control per row and a URL fragment | D4, D12 |
| Show the fields of one item | A facts table under the item's name | D6, D7 |
| Show long details, details in several steps, or details that lead to further views | A full-width view of its own | D14 |
| Add a few short lines to one row | The row expanded in place | D20 |
| Keep long raw data, such as a log, out of the way | An expandable section | D21, D22, D23 |
| Ask before a destructive or irreversible action | A modal dialog | D15, D16, D18 |
| Look at one figure or screenshot larger | A modal dialog that fills the window | D17 |
| Keep a comment the reader is writing in the details | A draft kept per item | D19 |

## Rules

### D1 On a wide screen, show the pressed row's details in a non-modal panel beside the list

| Item | Value |
|---|---|
| Use when | A page lists items and the reader opens one at a time to read or decide on it while the other items stay useful, on a screen wider than 860px. |
| Do not use when | The screen is 860px wide or narrower, so use D10 instead. For long details, steps, or further views use the full-width view of D14 instead, and for a few more lines about one row expand it in place with D20 instead. |
| How | Put `.list` and `.detail` side by side as siblings inside `.split`, with `.detail` after `.list` in the HTML. Make `.detail` a `<section aria-labelledby="detail-title">`, never a `<dialog>`, never `role="dialog"` or `aria-modal`, and with no backdrop over the list. Pressing a row fills `.detail` with that item while the list stays where it is, with a fade of 150 to 250ms that `@media (prefers-reduced-motion: reduce)` turns off. At wider than 860px, never place the details under the list and never open them in a dialog. |
| Sources | d-nng-tables-1, d-nng-tables-2, d-nng-modal-1, d-carbon-dialog-1, d-m3-side-sheets-1, d-sap-ios, d-fluent-layout |

### D2 Give the list a fixed width and the details the rest of the row

| Item | Value |
|---|---|
| Use when | The panel of D1 shows beside the list, on a screen wider than 860px. |
| Do not use when | The screen is 860px wide or narrower, where `.split` becomes one column, so use D10 instead. |
| How | Write `.split { display: grid; grid-template-columns: minmax(320px, 380px) minmax(0, 1fr); gap: 16px; align-items: start; }`, with the list in `.list` and the details in `.detail`. The list stays between 320 and 380px, so widening the window widens only `.detail`. The `minmax(0, 1fr)` track lets a wide table inside the details scroll in its own box instead of stretching the page. Never size the list in percent or with `1fr 1fr`, and keep the page's content width cap of about 1200px on the whole `.split`. |
| Sources | d-m3-expanded, d-sap-android-1, d-sap-android-2, d-apple-split-1 |

### D3 Keep the pressed row marked while its details are shown

| Item | Value |
|---|---|
| Use when | The details of one item show beside the list, or the reader comes back to the list from that item's details. |
| Do not use when | The reader picks several rows for a batch action, so use the row checkboxes of `lists-and-tables.md` instead, and keep this mark for the one row whose details are shown. |
| How | Set `aria-current="true"` on the control of the shown row and remove it from every other row, so exactly one row is marked. Draw the mark with more than color, such as a 3px bar on the row's leading edge plus a tinted background, and give the bar a contrast of at least 3 to 1 with what is next to it. Keep the mark while focus is in the details, while the list scrolls, and when the reader returns to the list on a narrow screen. Pressing another row moves the mark to it. |
| Sources | d-apple-split-2, d-android-canonical-1, d-patternfly-primary-1, d-sap-fcl-1, d-wcag-color, d-wcag-nontext, d-wcag-name-role |

### D4 Give each row one link or button that names the item

| Item | Value |
|---|---|
| Use when | A row of a table, an entry of a list, or a card opens an item's details. |
| Do not use when | The row shows facts only and opens nothing, so show it as plain text instead, with no control and no pointer cursor. |
| How | Put a `<button type="button">`, or an `<a href="#item-KEY">` when the page uses the fragments of D12, in the first cell, with the item's readable name as its text, never a generated ID. A press anywhere on the row or card may open the item too, by calling the same function, so the reader does not aim at a small target. Never wrap a `<tr>` in `<a>`, never give a `<tr>` `role="link"` or `role="button"`, and never make a row pressable without the named control inside it. End the row with a chevron icon with `aria-hidden="true"` to show that it opens. |
| Sources | d-nng-tables-3, d-apple-lists-1, d-wcag-name-role, d-dads-row-link |

### D5 Open an item in the details panel as soon as the page loads on a wide screen

| Item | Value |
|---|---|
| Use when | The page opens wider than 860px with a list and the panel of D1. |
| Do not use when | The page opens 860px wide or narrower, so show the list alone instead (D10). When the list is empty, show the empty state of `states-and-notices.md` in place of `.split` instead. |
| How | On load, open the item named in the URL fragment (D12), or else the first row of the list, so `.detail` is never blank. Mark that row (D3) and leave focus at the top of the page. When a filter leaves no rows, put one line in `.detail` that says no item matches and how to clear the filter, never an empty box. |
| Sources | d-sap-android-3, d-sap-fcl-2, d-patternfly-primary-2 |

### D6 Keep the item's name as the title of the details and put the details under it

| Item | Value |
|---|---|
| Use when | Any view shows one item's details, in the panel, the single pane, or the full-width view. |
| Do not use when | The view is about several items at once, such as removing three of them, so title it with the action and the count instead, such as Remove 3 payment methods. |
| How | Give `.detail` `aria-labelledby="detail-title"` and make its first heading `<h2 id="detail-title" tabindex="-1">` with the item's name exactly as its row shows it, never the word Details or a generated ID. Under the title put one line with the item's status or summary, then the facts table of D7, then the longer text, figures, and actions. Let a long name wrap onto more lines and never cut it with an ellipsis. Change the title together with the content when another row is pressed, and keep the same title in the single pane and the full-width view. |
| Sources | d-patternfly-primary-3, d-fluent-drawer-1, d-apg-dialog-1, d-carbon-overflow |

### D7 Lay out the item's fields as label and value rows

| Item | Value |
|---|---|
| Use when | The details show the fields of one item, such as its amount, status, owner, and dates. |
| Do not use when | The details compare several items or list many records, so use a table with one row per record from `lists-and-tables.md` instead. |
| How | Use `<table class="facts">` with one `<tr>` per field, a `<th scope="row">` label, and a `<td>` value, or a `<dl>` of `<dt>` and `<dd>` pairs. Never show one item as a table with a header row over a single data row. Write each value once, with its unit, and keep the labels in the page's dictionary so they switch language with the page. |
| Sources | d-govuk-summary, d-patternfly-table-1, d-nng-tables-4 |

### D8 Scroll the list and the details separately and never sideways

| Item | Value |
|---|---|
| Use when | The panel of D1 shows and the list or the details are taller than the window. |
| Do not use when | The screen is 860px wide or narrower, where one pane shows and scrolls with the page, so follow D10 instead. |
| How | Give `.list` and `.detail` each `position: sticky`, a `top` just under the page header, a `max-height` of the window height minus that header, such as `calc(100dvh - 96px)`, and `overflow-y: auto`, so each scrolls on its own. Keep the title and actions of the details in a header with `position: sticky; top: 0` and an opaque background token, and set `scroll-padding-top` on `.detail` to that header's height so a focused element is never hidden under it. Turn the sticky header off under `@media (max-height: 500px)`, and under the narrow query of D10 reset both panes to `position: static`, `max-height: none`, and `overflow: visible`. No pane gets `overflow-x: auto`; only a wide table scrolls sideways, inside its own wrapper `<div>` with `overflow-x: auto`. |
| Sources | d-sap-fcl-3, d-m3-side-sheets-2, d-m3-side-sheets-3, d-fluent-drawer-2, d-wcag-focus-obscured |

### D9 Keep the details panel in the page's Tab order and never trap focus in it

| Item | Value |
|---|---|
| Use when | The details sit in the non-modal panel of D1. |
| Do not use when | A short, focused task runs in a modal dialog, which keeps focus inside it, so follow D16 instead. |
| How | Keep `.detail` after `.list` in the HTML, with no `role="dialog"`, no `aria-modal`, no backdrop, and no script that wraps Tab inside it. On a wide screen, pressing a row leaves focus on that row so the reader can go on to the next one, and Tab past the list reaches the details. Give the list and the details each an `<h2>` so screen reader users can jump between them. A press outside the panel never closes it, and the list is never dimmed or blocked while the panel shows an item. |
| Sources | d-wcag-focus-order, d-wcag-keyboard-trap, d-carbon-dialog-2, d-fluent-dialog-1 |

### D10 Below 860px wide, show the list or the details, one at a time

| Item | Value |
|---|---|
| Use when | The page is 860px wide or narrower, such as on a phone or in a narrow window. |
| Do not use when | The page is wider than 860px, so show the panel beside the list of D1 instead. |
| How | Under `@media (max-width: 860px)`, the breakpoint the templates already use, set `.split { grid-template-columns: 1fr; }` and show only one of `.list` and `.detail`, for example with `.split[data-view="list"] .detail, .split[data-view="detail"] .list { display: none; }`. Pressing a row replaces the list with that item's details at the full width, scrolls to the top of the details, and moves focus to the details title, which has `tabindex="-1"`. Never place the details under the list. When the window widens while details are open, show both panes with the same item, and when it narrows, keep the details shown and hide the list. Nothing makes the page scroll sideways at 320px. |
| Sources | d-m3-medium, d-android-canonical-2, d-windows-1, d-patternfly-primary-4, d-m3-lists, d-android-canonical-3, d-wcag-reflow |

### D11 Keep a way back to the whole list from every details view

| Item | Value |
|---|---|
| Use when | The list is out of view, in the single pane of D10, in the full-width view of D14, or in any view opened from the details. |
| Do not use when | The list shows beside the details on a wide screen, where the list itself is the way back, so show no back button there and mark the row with D3 instead. |
| How | Put a `<button type="button" class="back">` first in the details, above the title, with a left arrow icon and the words Back to and the list's name from the page's dictionary, such as Back to payment methods. Pressing it, or the browser's Back (D12), shows the whole list again with its filter and scroll position as they were, calls `scrollIntoView({ block: "nearest" })` on the same row, and moves focus to that row's control, which keeps its mark (D3). The full-width view of D14 and any view opened from the details carry the same button, so no view is a dead end. |
| Sources | d-m3-list-detail-1, d-m3-list-detail-2, d-patternfly-primary-5, d-android-canonical-4, d-baymard-back-1, d-sap-fcl-4 |

### D12 Put the open item in the URL fragment

| Item | Value |
|---|---|
| Use when | The page lets the reader open an item's details in the panel, the single pane, or the full-width view. |
| Do not use when | The extra content is a row expanded in place (D20), which changes no view, so leave the URL as it is instead. |
| How | Give each item a stable `id` from its data, such as `item-` and its key, never its position in the list. Opening an item sets the fragment to `#item-KEY`, and on load the page reads `location.hash` and opens that item, so the link can be bookmarked and shared. While both panes show, switching items replaces the entry with `location.replace("#item-KEY")`, so Back leaves the page instead of stepping through every item viewed. When the details replace the list (D10) or open as a full-width view (D14), set `location.hash` to add an entry, so the browser's Back returns to the list, and have the back button of D11 call `history.back()` when this visit opened the details from the list, or else `location.replace("#list")`. Listen for `hashchange` and show the view the fragment names; these calls also work when the page is opened from a file. |
| Sources | d-sap-fcl-5, d-sap-nav-1, d-sap-nav-2, d-smashing-back-1, d-baymard-back-2 |

### D13 Put previous and next links in the details when the list is hidden

| Item | Value |
|---|---|
| Use when | The details fill the width, in the single pane of D10 or the full-width view of D14, and the reader goes through the items in order, such as when approving them. |
| Do not use when | The list shows beside the details on a wide screen, where the list itself moves between items, so hide these links and use the list instead. |
| How | Below the details, put a `<nav>` with an `aria-label` from the dictionary, holding a link to the previous item with `rel="prev"` and one to the next with `rel="next"`, each showing the word Previous or Next above the neighbor's name. Leave out Previous on the first item and Next on the last. Moving replaces the history entry (D12), moves the mark (D3), keeps the back button pointing at the list, and puts focus on the new title. Hide the `<nav>` in the two-pane layout. |
| Sources | d-sap-fcl-6, d-sap-nav-3, d-apple-lists-2, d-govuk-pagination-1, d-govuk-pagination-2 |

### D14 Open long details, steps, or further views as a full-width view of their own

| Item | Value |
|---|---|
| Use when | The details run longer than about 300 words, hold a wide table or a large figure, go through several steps, or lead to further views of the item. |
| Do not use when | The details are short enough to read beside the list, so use the panel of D1 instead. Never put such details in a dialog; use this view instead. |
| How | Build the view in the same file as a `<section class="page-view" aria-labelledby="page-view-title">` that replaces `.split`, which gets the `hidden` attribute, and keep the page header with the language and theme switches. Fill the page's content width, up to about 1200px, and start the view with the back button of D11 and the item's name as its title (D6). Give the panel header an Open full page button that opens the same item in this view, and give the view the fragment `#item-KEY/full` (D12). Show steps as numbered sections in order, such as Step 2 of 4, and never build the view as a `<dialog>` or as a panel sliding over the list. |
| Sources | d-carbon-dialog-3, d-nng-modal-2, d-smashing-modal-1, d-fluent-drawer-3, d-nng-bottom-sheet, d-sap-fcl-7 |

### D15 Use a modal dialog only for a short, focused task

| Item | Value |
|---|---|
| Use when | The reader must answer one question before going on, such as confirming a destructive or irreversible action, or looks at one figure or screenshot larger (D17). |
| Do not use when | The reader reads an item's details while the list stays in view, which is not such a task, so use the panel of D1 instead. Use the full-width view of D14 instead for long details, and the notices of `states-and-notices.md` instead for a finished action or a change of status. |
| How | Build it as a `<dialog>` opened with `showModal()`, with `aria-labelledby` pointing at its visible title. A confirmation names the action and the item in its title, such as Delete the card ending 4242?, says what will happen in at most three sentences, and has two buttons, Cancel and the action named with its verb, such as Delete, in the critical color. A dialog holds no table, no form of more than one field, and no link to another view. Never open an item's details in a dialog, at any width. |
| Sources | d-m3-dialogs-1, d-m3-dialogs-2, d-carbon-modal-1, d-patternfly-modal, d-apple-modality-1, d-nng-modal-3, d-fluent-dialog-2, d-dads-status-modal |

### D16 Move focus into a dialog, close it on Escape, and give focus back to the button that opened it

| Item | Value |
|---|---|
| Use when | A modal dialog of D15 or D17 opens. |
| Do not use when | The details sit in the non-modal panel, which keeps the page's Tab order, so follow D9 instead. |
| How | Open the dialog only from a button press, with `showModal()`, which keeps Tab inside the dialog, closes it on Escape, and dims the page behind with `::backdrop`. On open, focus the Cancel button of a confirmation, or the Close button of an enlarged figure. Keep a visible button that closes the dialog in its Tab order; in a confirmation that button is Cancel, so it gets no extra X. Before opening, store `document.activeElement`, and on the dialog's `close` event call `.focus()` on it. |
| Sources | d-apg-dialog-2, d-apg-dialog-3, d-apg-dialog-4, d-apg-dialog-5, d-carbon-dialog-4, d-apple-modality-2, d-dads-focus-return, d-dads-close-button |

### D17 Enlarge one figure or screenshot in a dialog that fills the window

| Item | Value |
|---|---|
| Use when | A figure, chart, or screenshot holds detail that is hard to read at its size in the page. |
| Do not use when | The reader needs the whole of an item's details larger, so open the full-width view of D14 instead. |
| How | Give each figure and screenshot a `<button type="button">` with an enlarge icon and an `aria-label` of Enlarge and the figure's caption. Pressing it opens a `<dialog>` with `showModal()` sized `width: calc(100vw - 32px); height: calc(100dvh - 32px); max-width: none; max-height: none;`, holding that one figure as a clone of its inline SVG or as the full-resolution image. Show the figure at least twice its width in the page, and let the dialog body scroll both ways with `overflow: auto`. Put a Close button with an icon and an `aria-label` at the top right, set the card's color as `--dragon-figure-background` on the view, and handle focus and Escape as D16 says. |
| Sources | d-nng-photos, d-baymard-zoom, d-apple-modality-3, d-wcag-reflow-2 |

### D18 Keep one dialog open at a time and one level of expandable sections

| Item | Value |
|---|---|
| Use when | A page has dialogs or expandable sections. |
| Do not use when | A task seems to need a second dialog or a section inside a section, so move it to the full-width view of D14, or split the content into sibling sections with their own headings, instead. |
| How | Put no `<dialog>` inside another, and call no `showModal()` while `document.querySelector("dialog[open]")` finds one. A dialog button that leads to another step closes the dialog first, or the task moves to the full-width view. Put no `<details>` inside a `<details>` and no expandable row inside an expanded row. |
| Sources | d-apple-modality-4, d-fluent-dialog-3, d-carbon-dialog-5, d-carbon-disclosures-1, d-govuk-accordion-1, d-dads-stacked-modes |

### D19 Keep what the reader typed in the details when they leave the item

| Item | Value |
|---|---|
| Use when | The details hold a field the reader fills in, such as an approval comment. |
| Do not use when | The details hold no field to fill in, so show them read only, with no draft handling, instead. |
| How | Keep a draft per item in a script object keyed by the item's ID, save it on every `input` event, and put it back when the item opens again, so pressing another row, the back button, or the browser's Back loses nothing. Show the word Draft beside the row's name while a draft is unsent. Add a `beforeunload` handler that asks before the page closes while any draft is unsent, and discard a draft only after the reader confirms in a short dialog (D15). |
| Sources | d-apple-modality-5, d-fluent-drawer-4, d-smashing-back-2 |

### D20 Expand a row in place only for a few short lines

| Item | Value |
|---|---|
| Use when | One row needs a few more lines, such as a note or a short reason, that the reader reads next to the neighboring rows. |
| Do not use when | The extra content runs longer than about 150 words, holds a table, or has actions, so use the panel of D1 or the full-width view of D14 instead. |
| How | Put a `<button type="button" aria-expanded="false" aria-controls="row-KEY-more">` with a caret icon at the start of the row, and the extra content in the next `<tr>`, in one `<td>` whose `colspan` spans every column, hidden until the button is pressed. Set `aria-expanded="true"` on open and turn the caret 90 degrees, with no turning under `prefers-reduced-motion: reduce`. Keep the extra content under about 150 words, with no table and no actions inside. |
| Sources | d-carbon-table, d-patternfly-table-2, d-nng-tables-5, d-smashing-modal-2 |

### D21 Never hide what most readers need in an expandable section

| Item | Value |
|---|---|
| Use when | You decide what the details show at once and what they fold away. |
| Do not use when | The content is long raw data that few readers open, such as a log, a full list, or raw text, so fold it with D22 instead. |
| How | Keep the status, the amounts, the decision asked for, deadlines, warnings, and the reason for the item in view without a press. Fold only long concrete data that few readers open, such as logs, full lists, and raw text of more than about 10 lines. Never fold only to save space, and when most readers would open a section, show its content open instead. |
| Sources | d-govuk-details-1, d-govuk-accordion-2, d-nng-accordions-1, d-carbon-disclosures-2, d-dads-disclosure-compact, d-dads-accordion-important |

### D22 Build each expandable section from details and summary, named for what it holds

| Item | Value |
|---|---|
| Use when | Long raw data in the details is folded away, as D21 allows. |
| Do not use when | A whole row's details are hidden, so use the row expansion of D20 or the panel of D1 instead. |
| How | Use `<details>` with a `<summary>`, or a `<button aria-expanded aria-controls>` where `<details>` cannot be used. Name what the section holds and how much, such as Raw log, 240 lines, never only More, Details, or Show more. Keep a caret or a plus before the name, pointing right when closed and down when open, and make the whole summary line the press target. |
| Sources | d-apg-disclosure, d-nng-accordions-2, d-apple-disclosure, d-govuk-details-2, d-dads-disclosure-details, d-dads-disclosure-title |

### D23 Let several expandable sections stay open and open them all for printing

| Item | Value |
|---|---|
| Use when | Two or more expandable sections sit together and the reader may compare them or print the page. |
| Do not use when | The sections are alternatives of which only one applies at a time, such as two views of the same data, so use tabs instead. |
| How | Give the `<details>` elements no shared `name` attribute, which would close the others, and close no sibling on `toggle`. When more than three sections sit together, put one Expand all button above them that becomes Collapse all. On `beforeprint`, set `open` on every `<details>`, and restore each one on `afterprint`. |
| Sources | d-nng-accordions-3, d-nng-accordions-4, d-govuk-accordion-3 |

## Where the sources disagree

| Question | What the sources say | Took | Why |
|---|---|---|---|
| How wide the list is beside the details | Material Design 3 fixes the list at 360dp in expanded windows, and SAP Fiori for Android keeps the list at a fixed width. SAP Fiori for Web opens the second column at a third of the width by default, Material Design 3 asks for equal halves in medium windows, Apple tvOS gives the list a third, and PatternFly allows halves, thirds, or quarters. | A list held between 320 and 380px with the details taking the rest (D2), as the owner decided | Readers spend their time in the details, so a fixed list keeps the same scanning width on any screen and a wider window adds room only where the reader reads. |
| Where the two panes start | Material Design 3 recommends one pane below 840dp. Windows shows both panes from 641 effective pixels, SAP Fiori for Web offers two columns on tablets, and PatternFly switches at its own breakpoint. | One pane below 860px (D10), the breakpoint the templates already use, as the owner decided | Below that width a 380px list leaves under about 450px for the details, too narrow for a facts table and a figure, and one breakpoint for the whole page is easier to keep. |
| Where the details go on a narrow screen | Material Design 3 lists, Android, Windows, and SAP replace the list with the details, and NN/g says not to show a detail page in a sheet. Material Design 3 side sheets prefer a modal sheet in compact windows, PatternFly slides the details over the list, and Baymard's quick views keep the list visible behind an overlay. | The details replace the list in the same page, with a back button and a URL fragment (D10, D11, D12) | The owner chose one pane at a time, which gives the details the full width, and the fragment lets the browser's Back return to the list as the page-based sources expect. |
| Whether an item's details may open in a dialog or overlay | Smashing Magazine says overlays and drawers keep access to the data behind them, and Baymard studies quick views that show product details in an overlay. NN/g says a modal covers the adjacent records, and Carbon says not to use a modal when information outside it must be consulted. | Never a dialog by default; a non-modal panel beside the list (D1, D15) | The owner ruled out dialogs as the way to show details, and the panel keeps the list in view without covering any of it, which is what the overlay was meant to give. |
| Whether a side panel is modal | The Digital Agency of Japan says a drawer always has a mode, and Fluent 2 overlay drawers are modal by default. Material Design 3 standard side sheets and PatternFly inline drawers leave the page usable. | A non-modal panel in the page's Tab order (D1, D9) | The reader must see and use the list while reading and deciding, and the Digital Agency's drawer is meant for navigation menus, not for item details. |
| Whether details may open under a row in the list | Carbon and PatternFly expand a table row in place to show more of it. NN/g says a row opened like an accordion makes it hard to refer to records that are not next to it. | Under the row only for a few short lines (D20), and never the full details under the list on a wide screen (D1) | The owner asked that details never sit under the list on wide screens, and content under a row pushes the other rows away from the one being read. |
| What the details panel shows before a row is pressed | Material Design 3 shows placeholder content, and PatternFly shows an empty state asking for a choice. SAP Fiori for Android opens the first item, and SAP Fiori for Web forbids an empty details column. | The item in the URL fragment, or else the first item (D5) | A report or an approval is read item by item, and an empty panel wastes the largest area of the page. |
| Whether the row stays marked when only one pane shows | Material Design 3 uses a selection state in two-pane layouts only. SAP Fiori for Web marks the item last opened at any width, and Baymard asks to return readers to where they were. | Keep the mark and focus the same row when the reader comes back to the list (D3, D11) | The owner asked for the same row focused on return, and a reviewer going through many items needs to see where they stopped. |
| Whether a whole row may open the details | The Digital Agency of Japan says a whole table row cannot be made a link. PatternFly treats hover and selectable rows as the cue, and Smashing Magazine opens details by tapping the row. | One button or link on the item's name, with a row press that only repeats it (D4) | One named control works from the keyboard and keeps the table valid, and the row press still gives a mouse a large target. |
| What the browser's Back does after the reader switches items | Android by default and SAP replace the history entry while the panes stay. Android also offers a mode where Back returns to the item viewed before. | Replace the entry while both panes show, and add one when the details replace the list (D12) | Stepping back through every item viewed makes leaving the page slow, which Smashing Magazine also warns against. |
| Whether several expandable sections may be open at once | PatternFly closes the open cell when another opens, and Carbon says expanding all rows defeats deferred loading. NN/g says to show everything when several are needed and to offer Expand All, and GOV.UK notes an accordion can show several sections at a time. | Several open, with Expand all and everything open for printing (D23) | Reviewers compare and print, and a self-contained page has no deferred loading to protect. |
| How to label an expandable section | Carbon names its control Show more. The Digital Agency of Japan says labels that only describe the action, such as see details, should be avoided, and GOV.UK asks for short descriptive text. | Name what the section holds (D22) | A label that names the content tells the reader whether opening it is worth the time. |
| Whether a confirmation dialog also has a close X | The Digital Agency of Japan uses no close button when there are action buttons, and Fluent 2 adds Close only when there is no Cancel. Carbon's transactional modal has both, Material Design 3 full-screen dialogs use an X, and the APG accepts a close icon or a cancel button. | Cancel and the action only, while an enlarged figure gets a Close button (D16, D17) | It removes the doubt over whether X means Cancel, and the visible Cancel meets the APG's need for a button that closes the dialog. |
| Whether a non-modal panel keeps Tab inside itself | The APG says modal dialogs, like non-modal dialogs, contain their tab sequence. WCAG's Understanding Focus Order puts a non-modal dialog's controls right after its button, with focus going on to the rest of the page. | Normal page Tab order with no wrap (D9) | A details panel that stays open is a region of the page, not a dialog. |
