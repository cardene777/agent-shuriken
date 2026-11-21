#!/usr/bin/env python3
"""inject_edit_mode.py: adds the edit toolbar to a static slide page, so the user can edit its text
in the browser, keep the edits in the browser's localStorage, and export them as content.json.

Implements references/edit-mode-spec.md. Uses only the Python standard library.

Usage:
    python3 inject_edit_mode.py static.html edit-mode.html

Adds the toolbar's dictionary and script at the end of <head>, and the toolbar at the end of
<body>, each between the markers that export_html_final.py removes.
The toolbar is in English by default and has an English / Japanese switch; every string it shows
comes from edit-text.json next to this script.
Editable elements are marked in static.html beforehand with contenteditable="true" and a unique
data-key.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

TEXT_FILE = Path(__file__).resolve().parent / "edit-text.json"

TOOLBAR_HTML = """
<!-- slide-forge-inject-start -->
<div id="slide-forge-toolbar" lang="en" style="position:fixed;top:8px;right:8px;background:#1A1A1A;color:#fff;padding:8px 12px;border-radius:6px;display:flex;gap:8px;align-items:center;z-index:9999;font-family:sans-serif;font-size:12px">
  <span role="group" data-t-aria="language" aria-label="{language}" style="display:flex;gap:4px">
    <button type="button" data-lang="en" aria-pressed="true" style="cursor:pointer">English</button>
    <button type="button" data-lang="ja" aria-pressed="false" style="cursor:pointer">日本語</button>
  </span>
  <button type="button" data-action="save" style="cursor:pointer"><span aria-hidden="true">💾</span> <span data-t="save">{save}</span></button>
  <button type="button" data-action="export" style="cursor:pointer"><span aria-hidden="true">📥</span> <span data-t="export">{export}</span></button>
  <button type="button" data-action="avatar" style="cursor:pointer"><span aria-hidden="true">🖼</span> <span data-t="avatar">{avatar}</span></button>
  <button type="button" data-action="reset" style="cursor:pointer"><span aria-hidden="true">🔄</span> <span data-t="reset">{reset}</span></button>
  <span id="slide-forge-status" role="status"></span>
</div>
<!-- slide-forge-inject-end -->
""".strip()

SCRIPT_HTML = """
<!-- slide-forge-inject-start -->
<script type="application/json" id="slide-forge-text">{dictionary}</script>
<script>
(function () {
  const STORE_KEY = 'slide-forge:' + (location.pathname || 'default');
  const LANG_KEY = 'slide-forge:lang';
  let TEXT = { en: {} };
  let lang = 'en';
  let saveTimer;
  let statusTimer;

  // Every string the toolbar shows comes from the one dictionary in #slide-forge-text.
  function t(key) {
    return (TEXT[lang] && TEXT[lang][key]) || TEXT.en[key] || key;
  }

  function toolbar() {
    return document.getElementById('slide-forge-toolbar');
  }

  function readLang() {
    try {
      return localStorage.getItem(LANG_KEY) === 'ja' ? 'ja' : 'en';
    } catch (e) {
      return 'en';
    }
  }

  function render() {
    const bar = toolbar();
    if (!bar) return;
    bar.lang = lang;
    bar.querySelectorAll('[data-t]').forEach((el) => { el.textContent = t(el.dataset.t); });
    bar.querySelectorAll('[data-t-aria]').forEach((el) => { el.setAttribute('aria-label', t(el.dataset.tAria)); });
    bar.querySelectorAll('[data-lang]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  }

  function setLang(next) {
    lang = next === 'ja' ? 'ja' : 'en';
    try { localStorage.setItem(LANG_KEY, lang); } catch (e) { /* the choice lasts for this visit */ }
    render();
  }

  function showStatus(key) {
    const status = document.getElementById('slide-forge-status');
    if (!status) return;
    status.textContent = t(key);
    clearTimeout(statusTimer);
    statusTimer = setTimeout(() => { status.textContent = ''; }, 2000);
  }

  function load() {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return;
    try {
      const data = JSON.parse(raw);
      Object.entries(data).forEach(([key, value]) => {
        if (key === 'bullets' && Array.isArray(value)) {
          value.forEach((item, i) => {
            const el = document.querySelector(`[data-key="bullet-${i + 1}"]`);
            if (el) el.textContent = item;
          });
          return;
        }
        const el = document.querySelector(`[data-key="${key}"]`);
        if (!el) return;
        if (el.tagName === 'IMG') {
          el.src = value;
        } else {
          el.textContent = value;
        }
      });
    } catch (e) { console.warn('slide-forge: could not load the saved edits', e); }
  }

  // Reads every element with data-key; bullet-1, bullet-2, ... become the bullets list.
  function collect() {
    const data = {};
    document.querySelectorAll('[data-key]').forEach((el) => {
      const key = el.dataset.key;
      if (el.tagName === 'IMG') {
        data[key] = el.src;
      } else {
        data[key] = el.textContent;
      }
    });
    const bullets = [];
    Object.keys(data).filter((k) => k.startsWith('bullet-')).sort().forEach((k) => {
      bullets.push(data[k]);
      delete data[k];
    });
    if (bullets.length > 0) data.bullets = bullets;
    return data;
  }

  function save() {
    localStorage.setItem(STORE_KEY, JSON.stringify(collect()));
  }

  function exportJson() {
    const blob = new Blob([JSON.stringify(collect(), null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'content.json';
    a.click();
    URL.revokeObjectURL(url);
  }

  function reset() {
    if (confirm(t('confirmReset'))) {
      localStorage.removeItem(STORE_KEY);
      location.reload();
    }
  }

  function chooseAvatar() {
    const el = document.querySelector('[data-key="avatar"]');
    if (!el) {
      alert(t('noAvatar'));
      return;
    }
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        el.src = reader.result;
        save();
      };
      reader.readAsDataURL(file);
    };
    input.click();
  }

  const actions = { save: () => { save(); showStatus('saved'); }, export: exportJson, avatar: chooseAvatar, reset };

  // Edits are saved 500 ms after the last keystroke.
  document.addEventListener('input', () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 500);
  });

  document.addEventListener('DOMContentLoaded', () => {
    try {
      TEXT = JSON.parse(document.getElementById('slide-forge-text').textContent);
    } catch (e) { console.warn('slide-forge: could not read the toolbar text', e); }
    lang = readLang();
    load();
    const bar = toolbar();
    if (bar) {
      bar.addEventListener('click', (e) => {
        const choice = e.target.closest('[data-lang]');
        if (choice) {
          setLang(choice.dataset.lang);
          return;
        }
        const button = e.target.closest('[data-action]');
        if (button && actions[button.dataset.action]) actions[button.dataset.action]();
      });
    }
    render();
  });
})();
</script>
<!-- slide-forge-inject-end -->
""".strip()


def load_text() -> dict:
    """Reads the toolbar's dictionary, with the same keys in English and Japanese."""
    text = json.loads(TEXT_FILE.read_text(encoding="utf-8"))
    if sorted(text) != ["en", "ja"] or set(text["en"]) != set(text["ja"]):
        raise ValueError(f"{TEXT_FILE.name} needs en and ja with the same keys")
    return text


def inject(html: str, text: dict) -> str:
    """Adds the dictionary, script, and toolbar. Raises ValueError without </head> or </body>."""
    if "</head>" not in html:
        raise ValueError("<head> closing tag not found in HTML")
    if "</body>" not in html:
        raise ValueError("<body> closing tag not found in HTML")

    if "slide-forge-inject-start" in html:
        print("WARN: the page already has the slide-forge toolbar, so nothing was added", file=sys.stderr)
        return html

    # "</" inside the JSON would end the script element early.
    dictionary = json.dumps(text, ensure_ascii=False).replace("</", "<\\/")
    script = SCRIPT_HTML.replace("{dictionary}", dictionary)
    toolbar = TOOLBAR_HTML
    for key, value in text["en"].items():
        toolbar = toolbar.replace("{" + key + "}", value)
    html = html.replace("</head>", script + "\n</head>", 1)
    html = html.replace("</body>", toolbar + "\n</body>", 1)
    return html


def main() -> int:
    parser = argparse.ArgumentParser(description="add the slide-forge edit toolbar to a static slide page")
    parser.add_argument("input_html", help="input static HTML")
    parser.add_argument("output_html", help="output edit-mode HTML")
    args = parser.parse_args()

    in_path = Path(args.input_html)
    if not in_path.is_file():
        print(f"ERROR: input HTML not found: {in_path}", file=sys.stderr)
        return 1

    html = in_path.read_text(encoding="utf-8")
    try:
        injected = inject(html, load_text())
    except ValueError as e:
        print(f"ERROR: could not add the toolbar, so nothing was written: {e}", file=sys.stderr)
        return 1

    Path(args.output_html).write_text(injected, encoding="utf-8")
    print(f"OK: {args.output_html} generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
