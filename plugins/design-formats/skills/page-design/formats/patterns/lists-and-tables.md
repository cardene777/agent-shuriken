# Lists and tables

This file decides how a page or document shows the facts about itself, its lists of items, its tables, its pages of rows, and its tabs.
An agent reads it before it builds a list, a table, a pager, a set of tabs, or the facts under a page title.
The details shown beside a list are in `details.md`, and the look of text and color is in `look.md`.

## Choose between

| You need | Use | Rule |
|---|---|---|
| To show the store, the period, counts, and when the page was generated | A facts table of row headers under the title | L1 |
| To compare the same attributes across many items | A table | L2, L10 |
| To show items that people read one at a time, each a whole on its own | Cards | L2 |
| To show a long list whose items fall into categories | One tab per category, each with its count | L2, L19, L20 |
| To show more than about 50 rows | Pages of 50 rows, with a pager above and below the list | L4, L6, L7 |
| To show 50 rows or fewer | One page with no pager | L4 |
| To show an amount for each row | The number in its own cell, with a bar beside it when a bar helps | L8 |
| To let people pick one item or several | Pressing the whole row or card | L9 |
| To help people find rows in a long list | A default order, a sort control in the header, and a search box in a toolbar | L16, L17, L18 |
| To show a wide table on a phone whose columns are compared | Sideways scrolling inside the table's own box | L23 |
| To show a table of records on a phone, read one record at a time | Each row stacked into labels above values | L24 |
| To lay out panels, cards, or a form | CSS grid or flex, never a table | L3 |

## Rules

### L1 Put facts about the page in a table of row headers

| Item | Value |
|---|---|
| Use when | A page or document has facts about itself under its title. Facts are the store, the period, counts, the data source, and when the page was generated. |
| Do not use when | The numbers are the results the page reports, such as total sales, and put them in the band of large numbers below the facts instead. For the details of one item, use the detail panel of `details.md` instead. |
| How | Put `<table class="facts">` directly under the page title, with a visually hidden `<caption>` such as "About this page". Give each fact its own `<tr>`, with the label in `<th scope="row">` and the value in `<td>`. Write dates in `<time datetime="2026-11-17T09:00">`. Give the label cells their own background, `.facts th { background: var(--label); font-weight: 600; text-align: left; white-space: nowrap; width: 1%; }`, so the value cell takes the rest of the width. Define the `--label` color token on `:root` for light, and again for dark under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])` and under `:root[data-theme="dark"]`, with label text at 4.5 to 1 contrast against it. Draw a 1px line between rows. Keep one fact per row in one column of pairs, and never put two label and value pairs side by side on one row. Keep the label and the value side by side at phone width too. Never put facts in one sentence or in a line of loose label and value text. Keep labels in the page dictionary for both languages. In a Markdown document, use a table with an Item and a Value column. |
| Sources | l-govuk-summary-list-1, l-govuk-summary-list-2, l-govuk-table-5, l-wcag-131-1, l-baymard-spec-sheets-1, l-baymard-spec-sheets-2, l-patternfly-dl |

### L2 Show lists as cards or tables, and split long lists by category into tabs

| Item | Value |
|---|---|
| Use when | A page shows a set of items. Use a table when people compare the same attributes across items or scan one column. Use cards when each item is read on its own and the items do not share one set of columns. Use tabs when a list of more than about 50 items falls into distinct categories that people read one at a time. |
| Do not use when | The items are steps in order, and use a numbered `<ol>` instead. When the items are facts about the page, use the facts table of L1 instead. When people need to compare categories side by side, keep them in one table with a category column instead of tabs. |
| How | Build a table as in L3 and L10, inside the `.list` container. Build cards as a `<ul>` whose `<li>` items each hold one card, laid out with `display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px`. Give each card its name as a heading and two to four key values, with the same labels in the same order on every card. Split a long list into one tab per category, as in L19 to L22, and give each tab panel its own table or cards and its own pager (L4). Keep a list of 50 items or fewer in one list with no tabs. |
| Sources | l-govuk-table-1, l-patternfly-table-1, l-nng-cards-1, l-fluent-card, l-govuk-tabs-3, l-nng-tabs-1, l-m3-tabs-1, l-dads-table-compare |

### L3 Use a table only for tabular data, with one record per row and no merged cells

| Item | Value |
|---|---|
| Use when | The content is data in rows and columns, where each row is one record and each column one attribute. |
| Do not use when | The content is a layout of panels, cards, or a form, and use CSS grid or flex instead. |
| How | Write `<table>` with `<thead>` and `<tbody>`, one `<tr>` per record. Use no `rowspan` or `colspan` in `<tbody>`, no table inside a cell, and no headings or form groups inside cells. When the data falls into groups, write several plain tables, each under its own `<h2>` or `<h3>`, instead of one table with merged group rows. Never set `role="presentation"` on a table to use it for layout. |
| Sources | l-govuk-table-2, l-govuk-table-3, l-wcag-131-2, l-sap-table-8, l-dads-table-layout, l-dads-merged-cells, l-dads-simple-structure |

### L4 Show about 50 rows per page, with the paging centered above and below the list

| Item | Value |
|---|---|
| Use when | A list or table holds more than 50 rows. |
| Do not use when | The list holds 50 rows or fewer, and show every row with no pager instead. There is no paging when the list fits on one page. |
| How | Count the rows first. With 50 or fewer, render all of them and render no pager, so there is no paging when the list fits on one page. With more, render 50 rows per page, and let the last page hold the rest. Keep 50 rows per page at every screen width. Put the same `<nav class="pager" aria-label="Pages">` above the list and below it, each laid out with `display: flex; justify-content: center; gap: 4px`. Make each page number a `<button type="button">` at least 40px wide and tall, and mark the current page with `aria-current="page"` and the accent fill. Pressing a page updates both pagers, scrolls to the top of the list, and moves focus to the list caption or heading, which has `tabindex="-1"`. In a tabbed list, each tab panel has its own pages and opens on page 1. |
| Sources | l-baymard-items-loaded, l-smashing-load-more-1, l-govuk-pagination-1, l-carbon-pagination-1, l-patternfly-pagination-1 |

### L5 Never load more rows automatically as the reader scrolls

| Item | Value |
|---|---|
| Use when | A list holds more rows than one page of L4 shows. |
| Do not use when | The list fits on one page, and show every row instead. |
| How | Do not add rows from an `IntersectionObserver` or a `scroll` listener. Change rows only when the reader presses a page in the pager of L4. Keep the footer and every control below the list reachable by the Tab key at all times. |
| Sources | l-govuk-pagination-2, l-govuk-pagination-3, l-nng-infinite, l-smashing-load-more-2 |

### L6 Show the total and the range of rows on view above the list

| Item | Value |
|---|---|
| Use when | A list is split into pages, filtered, or split into tabs. |
| Do not use when | The list is short and shown whole, and let the count in the facts table of L1 or the tab label of L20 say how many there are instead. |
| How | Put one line of text above the upper pager, such as "Rows 51 to 100 of 230", inside `<p class="count" aria-live="polite">`. Update it when the page, the tab, or the filter changes. With a filter on, say how many rows match, such as "12 of 230 rows match". Keep the Japanese text of the line in the page dictionary, and keep the numbers the same in both languages. |
| Sources | l-carbon-pagination-2, l-sap-table-1, l-dads-current-position |

### L7 Shrink the pager on phones and hide the links that lead nowhere

| Item | Value |
|---|---|
| Use when | A list has a pager (L4). |
| Do not use when | The list fits on one page, and show no pager at all instead (L4). |
| How | Below 600px of width, show in each pager only Previous, the first page, the current page with one page on each side, the last page, and Next, with an ellipsis where numbers are left out, never more than 5 numbers. On the first page, do not render Previous at all, rather than showing it disabled. On the last page, do not render Next. Write Previous and Next as words, not arrows alone. |
| Sources | l-govuk-pagination-4, l-govuk-pagination-5, l-carbon-pagination-3, l-patternfly-pagination-2, l-dads-hide-buttons |

### L8 Give each row its value as a number, and draw any bar beside it

| Item | Value |
|---|---|
| Use when | Rows or cards carry an amount, a count, a share, or a score. Give each row its value as a number, because a bar without a number does not say what it measures. |
| Do not use when | The value is a category or a state, and show it as a text label or a status tag instead. |
| How | Write the value as text in its own `<td>`, such as `1,240` or `38%`, and put the unit in the column header, such as "Sales (yen)". Right-align the value cells and their header with `text-align: right`, and set `font-variant-numeric: tabular-nums` and `white-space: nowrap` on them. Keep IDs and names left aligned. When a bar helps compare sizes, draw it in the next cell or behind the number, set `aria-hidden="true"` on it, and size it as the value over the largest value in the list. Never show a bar alone. On a card, show the number in large text next to its label. |
| Sources | l-govuk-table-4, l-sap-table-2, l-patternfly-table-2, l-wcag-131-3, l-dads-number-align |

### L9 Let people choose by pressing a row or a card, not by aiming at a small checkbox

| Item | Value |
|---|---|
| Use when | People pick one item to see its details, or pick several items for one action. |
| Do not use when | Nothing on the list is chosen, and show a plain table or cards with no pressed state instead (L2). |
| How | Make the whole row or card the target, at least 44px tall, with a hover background so it shows that it responds. Build each card as a `<button type="button">` that holds the card text. In a table, put a `<button type="button">` in the name cell, and let a click anywhere on the `<tr>` press it, so keyboard users reach it with Tab and press it with Enter or Space. When the press shows the item in `.detail`, mark it with `aria-current="true"`. When the press picks it for an action, toggle `aria-pressed="true"`. Mark a picked row with two cues, a background from a `--selected` token and a 3px accent border on its left edge. With several picked, show "3 selected" and the action buttons in the toolbar of L18. A check mark may show the state inside the row, but never make a checkbox the only place to press. |
| Sources | l-m3-lists, l-sap-table-3, l-fluent-card, l-nng-data-tables-1 |

### L10 Mark up header cells with scope and give every table a caption

| Item | Value |
|---|---|
| Use when | A page holds a data table. |
| Do not use when | The content is not a data table, and lay it out with CSS grid instead (L3). |
| How | Use a native `<table>`, never `<div>` elements with `role="table"`. Write column headers as `<th scope="col">` in `<thead>`, and the cell that names each row as `<th scope="row">`. Set header cells in weight 600 with a 2px line under the header row, so they look different from data cells. Make `<caption>` the first child of the table and let it name the table like a heading, such as "Sales by product". When a heading above the table already names it, point to that heading with `aria-labelledby` instead of a caption. |
| Sources | l-govuk-table-5, l-govuk-table-6, l-wcag-131-1, l-wcag-131-5, l-apg-table-1, l-dads-header-cells |

### L11 Separate rows with lines, and stripe only wide or dense tables

| Item | Value |
|---|---|
| Use when | A table or a list of rows has more than one row. |
| Do not use when | The items are cards with their own borders, and separate them with the grid gap instead (L2). |
| How | Draw a 1px line under each row from a `--line` color token. Add stripes, `tbody tr:nth-child(even) { background: var(--stripe); }`, only when the table has 6 or more columns or scrolls sideways. Give rows that can be pressed a hover background. Keep the line color at 3 to 1 contrast against every row background, plain, striped, hovered, or selected. Define `--line`, `--stripe`, and `--selected` for light and for dark. |
| Sources | l-govuk-summary-list-3, l-nng-data-tables-1, l-apple-tables-1, l-patternfly-table-3, l-carbon-table-1, l-dads-stripes, l-dads-border-contrast |

### L12 Keep column headers in view while a long table scrolls

| Item | Value |
|---|---|
| Use when | A table is taller than the screen. |
| Do not use when | The whole table fits on the screen, and leave the header in place instead. |
| How | Set `thead th { position: sticky; top: 0; z-index: 1; background: var(--surface); }`. When the page has a sticky header bar, set `top` to its height. When the table scrolls inside its own box (L23), the header sticks to the top of that box. |
| Sources | l-nng-data-tables-2, l-nng-mobile-tables-1, l-sap-table-4, l-smashing-responsive-1 |

### L13 Put the name column first and keep it in view when the table scrolls sideways

| Item | Value |
|---|---|
| Use when | Each row has a name or an ID that says which record it is. |
| Do not use when | The rows have no name, such as a log in time order, and keep the time as the first column instead. |
| How | Make the first column the name or ID, written as `<th scope="row">`. In a box that scrolls sideways (L23), set `position: sticky; left: 0; background: var(--surface);` on that cell in every row, with a 1px line on its right edge. At phone width, never hide this column. |
| Sources | l-sap-table-5, l-nng-mobile-tables-2, l-smashing-complex-1, l-nng-data-tables-2 |

### L14 Size columns to their content and wrap long text instead of cutting it off

| Item | Value |
|---|---|
| Use when | A table has columns of different kinds, such as names, numbers, and notes. |
| Do not use when | A cell holds very long text such as a log or a message body, and show its first lines with a button that opens the whole text (see `details.md`) instead. |
| How | Leave `table-layout: auto`. Keep number, date, and status columns as narrow as their content with `white-space: nowrap`, and let text columns take the remaining width and wrap with `overflow-wrap: break-word`. Do not set `text-overflow: ellipsis` or `-webkit-line-clamp` on cells. Set the table to `width: auto; max-width: 100%`, so spare width sits at the right of the table rather than between columns. Give cells 8px of padding above and below and 12px at the sides. |
| Sources | l-sap-table-6, l-carbon-table-2, l-smashing-complex-2, l-smashing-complex-3 |

### L15 Never align or spread text in cells with spaces, line breaks, or justification

| Item | Value |
|---|---|
| Use when | Labels or cells have text of different lengths, such as short Japanese labels next to longer ones. |
| Do not use when | The cells hold numbers, and line them up with right alignment and tabular figures instead (L8). |
| How | Do not put the ideographic space U+3000, runs of `&nbsp;`, or `<br>` between characters to line up text. Do not set `text-align: justify` or `text-align-last: justify` on `th`, `td`, `dt`, or labels, so a two-character Japanese label keeps its natural width. Line text up with `text-align` and with the column width. |
| Sources | l-wcag-131-4, l-dads-no-spaces, l-dads-no-justify |

### L16 Order rows by default in the order readers most need

| Item | Value |
|---|---|
| Use when | A list or table is first shown. |
| Do not use when | The order is itself the content, such as steps or a ranking the data already holds, and keep that order instead. |
| How | Sort by the column readers most need. Put the largest amounts first, the newest dates first, and on an approval page the items that need action first. Break ties by name. Show the order on the sorted column header with `aria-sort` (L17). |
| Sources | l-baymard-spec-sheets-3, l-dads-dashboard-order, l-dads-dashboard-order-example |

### L17 Make the header of a sortable column the sort control

| Item | Value |
|---|---|
| Use when | A table holds more than about 10 rows, and readers want them in another order. |
| Do not use when | The table is short or its order is fixed, and rely on the default order of L16 instead. |
| How | Put a `<button type="button">` holding the label and an arrow icon in the `<th>`, so the whole header text is the target. Set `aria-sort="ascending"` or `aria-sort="descending"` on the sorted `<th>` only. The first press sorts in the column's natural order, the largest first for numbers and A to Z for names. A second press on the same header reverses the order. Sort by one column at a time, and sort numbers as numbers, not as text. Return to page 1 after a sort. |
| Sources | l-apple-tables-2, l-apple-tables-3, l-patternfly-table-4, l-apg-table-2, l-dads-sort-target |

### L18 Put search, filters, and actions on many rows in a toolbar above the list

| Item | Value |
|---|---|
| Use when | A list holds more than about 50 rows, or people act on several picked rows at once. |
| Do not use when | The list is short and has no actions, and show the list alone instead. |
| How | Put a bar directly above the list, before the count line of L6. Give it an `<input type="search">` with a visible label, filters as a `<select>` or a group of buttons that show their counts, and the actions for picked rows. Filter the rows as the reader types, with no submit button, and return to page 1. Put nothing of this inside the rows. Above a set of cards, keep filters and sorting outside the cards in the same way. |
| Sources | l-patternfly-table-5, l-carbon-table-3, l-m3-cards, l-nng-data-tables-3, l-dads-table-control-actions, l-dads-table-control-search |

### L19 Keep to two to five tabs, and never show a single tab

| Item | Value |
|---|---|
| Use when | A long list is split by category into tabs (L2). |
| Do not use when | There is only one category, and show the list without tabs instead. With more than five categories, merge the smallest into an "Other" tab, or use a category filter in the toolbar of L18 instead. |
| How | Give each `role="tablist"` between 2 and 5 elements with `role="tab"`. Order the tabs in the order of the categories in the data, or by count, the largest first. |
| Sources | l-m3-tabs-2, l-nng-tabs-2, l-sap-icontabbar-1, l-carbon-tabs-1 |

### L20 Label each tab with one or two words and the count of its items

| Item | Value |
|---|---|
| Use when | Tabs split a list by category. |
| Do not use when | A tab does not hold a list, so a count says nothing, and use the label alone instead. |
| How | Name each tab with a short noun of one or two words, in the same grammatical form on every tab. Put the count after the label in plain text, such as "Open (12)", on every tab, not in a colored badge. Keep the labels in the page dictionary for both languages, and keep the count the same in both. |
| Sources | l-carbon-tabs-2, l-fluent-tablist-1, l-sap-icontabbar-2, l-sap-icontabbar-3 |

### L21 Keep tabs in one row that scrolls sideways when it does not fit

| Item | Value |
|---|---|
| Use when | The tab row may be wider than its box, as on a phone. |
| Do not use when | The tabs would need a second row even with short labels, and cut the number of tabs (L19) instead. |
| How | Set `display: flex; flex-wrap: nowrap; overflow-x: auto;` on the tablist and `white-space: nowrap` on each tab. When the row is wider than its box, let it scroll sideways and keep the cut tab visible at the edge, so people see that more tabs exist. Scroll the selected tab into view with `scrollIntoView({ block: "nearest", inline: "nearest" })`. Do not wrap tabs to a second row, and do not hide tabs in a menu. |
| Sources | l-carbon-tabs-3, l-m3-tabs-3, l-govuk-tabs-1 |

### L22 Build tabs with tab roles and arrow keys, and mark the selected tab with two cues

| Item | Value |
|---|---|
| Use when | A page has tabs (L2). |
| Do not use when | The sections are steps in order, or people need to see them side by side, and use headed sections on one page instead. |
| How | Write `<div role="tablist" aria-label="Categories">` holding `<button role="tab">` elements, each with an `id`, `aria-selected`, and `aria-controls` pointing at its `<div role="tabpanel" aria-labelledby="..." tabindex="0">`. Set `aria-selected="true"` and `tabindex="0"` on the selected tab only, and `tabindex="-1"` on the others. Move between tabs with Left and Right, and to the first and last with Home and End. Start each panel with a heading that names the category. Mark the selected tab with at least two cues, the accent text color and a 3px line under it, plus weight 600. Switch panels with a transition of 150 to 250ms, turned off under `@media (prefers-reduced-motion: reduce)`. |
| Sources | l-apg-tabs-1, l-apg-tabs-2, l-govuk-tabs-2, l-nng-tabs-3, l-m3-tabs-4 |

### L23 On a phone, scroll a wide table inside its own box when columns must stay comparable

| Item | Value |
|---|---|
| Use when | A table is wider than the screen, and readers compare its columns, as in a table of numbers. |
| Do not use when | The rows are records that people read one at a time, and stack them into labels above values instead (L24). |
| How | Wrap the table in `<div class="table-scroll" role="region" aria-labelledby="<caption id>" tabindex="0">` with `overflow-x: auto`, so keyboard users can focus it and scroll it with the arrow keys, and show a visible focus ring on it. Keep the page itself from scrolling sideways. Show a shadow on the edge where more columns are hidden, and keep the name column in view (L13). |
| Sources | l-wcag-reflow, l-nng-mobile-tables-3, l-smashing-responsive-2, l-smashing-responsive-3, l-smashing-responsive-4, l-dads-table-scroll |

### L24 On a phone, stack each record row into labels above values, keeping table semantics

| Item | Value |
|---|---|
| Use when | A table of records is shown below 600px of width, and people read one record at a time. |
| Do not use when | Readers compare a column across rows, and scroll the table inside its own box instead (L23). |
| How | Below 600px, show the records as a `<ul>` in which each `<li>` holds the record name as a heading and a `<dl>` of `<dt>` and `<dd>` pairs, each label above its value, built from the same data as the table. Show only one of the table and the stacked list at a time, hiding the other with `display: none`. Do not stack the table itself by setting `display: block` on `table`, `tr`, `th`, or `td`. Keep the pager, the count line, and the press to choose (L9) the same in both. |
| Sources | l-patternfly-table-6, l-sap-table-7, l-smashing-responsive-5, l-wcag-131-3 |

## Where the sources disagree

| Question | What the sources say | Took | Why |
|---|---|---|---|
| Facts about the page in a description list or in a table | GOV.UK shows key facts as a summary list, which is a description list, and WCAG technique H40 and PatternFly use description lists for terms and values. The Digital Agency design system says to use a description list for plain name and value pairs. | A table of row headers, `<table class="facts">` (L1) | The owner chose the table. A row of `<th scope="row">` and `<td>` gives the label its own cell to color with `--label` and keeps label and value on one line without grid CSS, and GOV.UK and WCAG F91 make row headers as clear to screen readers as `dt` elements. |
| Facts table at phone width | PatternFly and SAP Fiori put each label above its value at narrow widths. | Label and value stay side by side (L1) | Facts are short, so two columns fit a phone, and Smashing Magazine shows that changing `display` on table elements to stack them drops their table semantics. |
| Cards for lists | NN/g says card layouts are less scannable than lists and poor for comparing options, and Apple HIG says to prefer a list or table for text. Fluent 2 uses a card for one concept or object, and Material 3 warns against forcing content into cards. | Cards or tables, as the owner set (L2) | Cards stay for items read one at a time, and every list that people compare or scan goes in a table, which keeps the NN/g limit. |
| Tabs or headed sections for a long list | GOV.UK says tabs hide content and prefers headed sections on one page. The Digital Agency design system says not to use tabs for filtering. SAP Fiori uses a tab bar as a filter with a counter on every tab. | One tab per category, with its count (L2, L20) | The owner split long lists by category into tabs. Categories are distinct groups read one at a time, which NN/g and Material 3 ask for, and the count on every tab tells what each hidden tab holds. Narrowing by status inside a category stays a filter in the toolbar (L18). |
| How many rows on one page | GOV.UK and Carbon split content into pages only when it helps. Baymard found the best balance at 50 to 150 items, and the Baymard study on Smashing Magazine sets 50 to 100. SAP Fiori says its responsive table handles up to 200 items. | About 50 rows per page, and no paging when the list fits on one page (L4) | The owner set about 50, which sits at the low end of the Baymard range and keeps a page short enough to scan, and a list that fits needs no pager at all. |
| Fewer rows per page on phones | Baymard says mobile sites should load fewer products, typically 15 to 30. | About 50 rows at every width (L4) | A self-contained page already holds every row, so a smaller page saves no loading time and only makes phone readers turn pages more often. |
| Where the pager goes | Carbon says not to put the pager above the data table, and GOV.UK puts it after the content. PatternFly puts a pager both above and below on desktop, and on mobile never puts a full pager at both. No source read sets its sideways position. | Centered above and below the list, with a compact pager on phones (L4, L7) | The owner chose both places, so a reader can turn the page from the top without scrolling past 50 rows and from the bottom after reading them. The compact phone pager of L7 keeps two pagers from crowding a small screen, and centering matches the shared center line of the page. |
| Loading on scroll | SAP Fiori prefers loading more items when the reader scrolls. GOV.UK, NN/g, and the Baymard study on Smashing Magazine warn against infinite scroll and favor pages or a button. | Pages, with no loading on scroll (L4, L5) | Loading on scroll causes problems for keyboard users and keeps the footer out of reach, and a self-contained page has nothing to fetch. |
| Choosing rows with a checkbox | Carbon and PatternFly data tables pick rows for batch actions with a checkbox in the first column. | Pressing the whole row or card (L9) | The owner chose rows and cards as the target. A row or card is a far larger target than a 16px checkbox, especially on a phone, and a button with `aria-pressed` gives screen readers the same picked state. |
| Zebra stripes | NN/g, Apple HIG, Carbon, and PatternFly allow alternating row colors for wide or dense tables. SAP Fiori says not to use them. | Row lines always, stripes only for wide or dense tables (L11) | Stripes help most where a row is read across many columns or across a sideways scroll, and lines alone keep short tables quiet. |
| Truncating long cell text | Carbon truncates headers with a tooltip, Material 3 lists allow wrap or truncate, and Apple HIG suggests a middle ellipsis. SAP Fiori says to avoid truncation unless columns can be resized. | Wrap, never truncate (L14) | A page has no column resizing, and phones have no hover tooltips, so cut text would be lost. |
| How many tabs | Material 3 says no more than four, Apple HIG about five on a phone, Carbon allows up to eight, and PatternFly allows as many as needed but kept to a minimum. | Two to five (L19) | The page must fit a phone, where more than four or five labels with counts do not fit in one row. |
| Too many tabs for the width | PatternFly, Fluent 2, and SAP Fiori move extra tabs into an overflow menu, and Apple HIG says to avoid overflow tabs. Material 3 and SAP Fiori scroll the tab row, and Fluent 2 suggests an accordion. | A tab row that scrolls sideways (L21) | Keeping to few tabs avoids the problem, and a scrolling row needs no menu and keeps every tab one swipe away. |
| A wide table on a phone | PatternFly and SAP Fiori stack each row into label and value pairs. The Digital Agency design system and NN/g scroll the table sideways inside its own area, and WCAG Reflow allows that for data tables. | Scroll comparison tables in their box, stack record lists (L23, L24) | Sideways scrolling keeps columns comparable with native table semantics, and stacking suits records read one at a time when it is built as separate markup. |
