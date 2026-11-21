# Edit page

How `scripts/inject_edit_mode.py` turns a static slide page into an edit page: editable text, a toolbar, saving in the browser's localStorage, and JSON export.

## What the phase 1 page needs

The HTML written in phase 1 marks what the user will edit.

- Every editable element has `contenteditable="true"` and `data-key="<unique name>"`
- Each `data-key` is used once per page, for example `title`, `subtitle`, `bullet-1`, `bullet-2`, `footer`
- A photo is `<img data-key="avatar" src="...">`. The toolbar's **Photo** button replaces it

```html
<h1 contenteditable="true" data-key="title">About me</h1>
<p contenteditable="true" data-key="subtitle">Alex Kim / Support team lead</p>
<ul>
  <li contenteditable="true" data-key="bullet-1">Ten years in customer support</li>
  <li contenteditable="true" data-key="bullet-2">Runs the night shift</li>
</ul>
<img data-key="avatar" src="./assets/avatar.jpg">
```

## What the script adds

| Where | What |
|---|---|
| End of `<head>` | The toolbar's dictionary in `<script type="application/json" id="slide-forge-text">`, and the toolbar's script |
| End of `<body>` | The toolbar, fixed at the top right of the page |

Each addition sits between `<!-- slide-forge-inject-start -->` and `<!-- slide-forge-inject-end -->`, which `scripts/export_html_final.py` removes for the public page.
A page that already has the markers is written unchanged.

## The toolbar

| Control | What it does |
|---|---|
| **English** / **日本語** | The language switch at the left end. The toolbar starts in English |
| **Save** | Saves every `data-key` element in localStorage and shows "Saved in this browser" for two seconds |
| **Export JSON** | Downloads `content.json` with every `data-key` element; `bullet-1`, `bullet-2`, ... become the `bullets` list |
| **Photo** | Opens a file picker and replaces the `avatar` image with the chosen file as a data URL |
| **Reset** | Asks first, then removes the saved edits and reloads the page |

Edits are also saved 500 ms after the user stops typing, and loaded again when the page opens.

## The dictionary

Every string the toolbar shows comes from `scripts/edit-text.json`, which holds `en` and `ja` with the same keys.
`inject_edit_mode.py` refuses a dictionary whose two languages have different keys, and writes nothing.
The buttons are written with the English strings, so the page reads in English before its script runs.
The script reads the dictionary from `#slide-forge-text` and shows the chosen language; messages in `confirm` and `alert` come from it too.

To add a string, add the same key to both `en` and `ja`, and mark the element with `data-t="<key>"`.

## localStorage keys

| Key | What it holds |
|---|---|
| `slide-forge:<page path>` | The saved edits of that page, so two decks open from different paths do not share edits |
| `slide-forge:lang` | The toolbar language, `en` or `ja` |

Both stay in the user's browser. Nothing is sent anywhere.

## The photo

The **Photo** button reads the chosen file into a base64 data URL and puts it in the `avatar` image's `src`.
Export JSON writes that data URL to the `avatar` field of `content.json`, and `scripts/build_pptx.py` writes it to a temporary file before handing it to Pillow.

## When the page cannot be changed

`inject_edit_mode.py` writes nothing and exits 1 when the page has no `</head>` or `</body>`, so a toolbar is never added halfway.

## Related files

- `scripts/inject_edit_mode.py` and `scripts/edit-text.json`
- `references/pptx-build-spec.md`, with the `content.json` that the export reads
