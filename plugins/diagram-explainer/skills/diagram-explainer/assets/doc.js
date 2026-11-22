(function () {
  'use strict';

  // Explainer layout. A header band holds the title, the switches, and the help button; the left
  // contents list picks a section; one section is shown at a time.
  //
  // A document with 2 or more topics is split into pages by tabs in the header band.
  // The body of a page that is not shown is kept in a `template` and moved into the page
  // when it opens, so its charts are drawn only when the reader gets there.
  //
  // This file also shows the interface text of the whole page and runs the two switches in
  // the header: the language of that text, and light or dark colors. It opens figures enlarged
  // and the help in dialogs. It is loaded before charts.js and print.js, which take their text
  // from `window.dxUi`.

  var root = document.documentElement;

  // Every interface string of the page: the frame that render.py writes, the section count,
  // the switches, the dialogs, the PDF menu (print.js), and the chart units (charts.js).
  // The strings are defined once, in assets/ui.json, keyed by `en` and `ja`; build.py copies
  // that file into the JSON script element `dx-ui` of the page, and render.py and ladder.py
  // read the same file, so the page is built and relabeled with the same words.
  // The document's own text stays in the language it was written in.
  // `{name}`, `{i}`, and `{n}` are filled in by `say`.
  var TEXT = (function () {
    var source = document.getElementById('dx-ui');
    try { return JSON.parse(source.textContent) || {}; } catch (e) { return {}; }
  })();
  var THEME_KEY = 'diagram-explainer-theme';
  var LANG_KEY = 'diagram-explainer-lang';

  function all(sel, el) { return [].slice.call((el || document).querySelectorAll(sel)); }
  function known(l) { return l === 'en' || l === 'ja'; }
  // The reader's choices are kept in the browser. Storage can be blocked (a private window,
  // a browser setting); then a choice lasts until the page is closed.
  function stored(key) { try { return window.localStorage.getItem(key); } catch (e) { return null; } }
  function store(key, value) { try { window.localStorage.setItem(key, value); } catch (e) { /* kept for this visit only */ } }
  function listen(query, fn) {
    if (!query) return;
    if (query.addEventListener) query.addEventListener('change', fn);
    else if (query.addListener) query.addListener(fn);
  }

  // ---- Interface language ----
  //
  // `<html lang>` stays the document's language, because the text and its wording depend on it.
  // The interface language starts from it unless the reader chose one before.
  var docLang = /^ja/i.test(root.lang || '') ? 'ja' : 'en';
  var lang = known(stored(LANG_KEY)) ? stored(LANG_KEY) : docLang;
  root.setAttribute('data-ui-lang', lang);

  function say(key, values) {
    var s = (TEXT[lang] || {})[key];
    if (s == null) s = (TEXT.en || {})[key] || '';
    return s.replace(/\{(\w+)\}/g, function (_m, k) { return values && values[k] != null ? values[k] : ''; });
  }

  // Interface text is marked with the key it shows: `data-ui` (the text), `data-ui-label`
  // (aria-label), and `data-ui-title` (title). `data-ui-name` and `data-ui-n` fill `{name}` and `{n}`,
  // and `data-ui-icon` is a symbol kept in front of the text.
  function relabel(scope) {
    function values(el) { return { name: el.getAttribute('data-ui-name'), n: el.getAttribute('data-ui-n') }; }
    all('[data-ui]', scope).forEach(function (el) {
      var icon = el.getAttribute('data-ui-icon');
      el.textContent = (icon ? icon + ' ' : '') + say(el.getAttribute('data-ui'), values(el));
      if (lang === docLang) el.removeAttribute('lang');
      else el.setAttribute('lang', lang);
    });
    all('[data-ui-label]', scope).forEach(function (el) {
      el.setAttribute('aria-label', say(el.getAttribute('data-ui-label'), values(el)));
    });
    all('[data-ui-title]', scope).forEach(function (el) {
      el.setAttribute('title', say(el.getAttribute('data-ui-title'), values(el)));
    });
  }

  window.dxUi = { lang: function () { return lang; }, say: say, relabel: relabel };

  // ---- Frames wider than their box ----
  //
  // A chart or step ladder that would need text under 12px to fit its frame keeps its size and
  // scrolls sideways inside the frame (`.fig-scroll`), and a table wider than its box (`.tbl`)
  // scrolls there too. Then the frame names the sides where it continues in `data-more`
  // (doc.css fades that edge), and a line under a figure says it scrolls. A table keeps its first
  // column in place, so its left fade starts after that column (`--first`). A frame that is not
  // shown has no width and is looked at again when it opens.
  function cue(frame) {
    var room = frame.scrollWidth - frame.clientWidth;
    var more = [];
    if (room > 1) {
      if (frame.scrollLeft > 1) more.push('left');
      if (frame.scrollLeft < room - 1) more.push('right');
    }
    if (more.length) frame.setAttribute('data-more', more.join(' '));
    else frame.removeAttribute('data-more');
    var first = more[0] === 'left' ? frame.querySelector('tr > :first-child') : null;
    if (first) frame.style.setProperty('--first', first.getBoundingClientRect().width + 'px');
    if (frame.dxHint) frame.dxHint.hidden = room <= 1;
  }
  var frameWatch = window.ResizeObserver ? new ResizeObserver(function (entries) {
    entries.forEach(function (entry) { if (entry.target.clientWidth) cue(entry.target); });
  }) : null;
  function frames(scope) {
    all('.fig-scroll, .tbl', scope).forEach(function (frame) {
      if (!frame.clientWidth || frame.closest('dialog')) return;
      if (!frame.dxCue) {
        frame.dxCue = true;
        if (frame.classList.contains('fig-scroll')) {
          var hint = document.createElement('div');
          hint.className = 'fig-more';
          hint.setAttribute('data-ui', 'figMore');
          hint.hidden = true;
          frame.parentNode.insertBefore(hint, frame.nextSibling);
          frame.dxHint = hint;
          relabel(frame.parentNode);
        }
        frame.addEventListener('scroll', function () { cue(frame); }, { passive: true });
        if (frameWatch) frameWatch.observe(frame);
      }
      cue(frame);
    });
  }
  window.dxFrames = function (scope) { frames(scope || document); };
  if (!frameWatch) window.addEventListener('resize', function () { frames(document); });

  // ---- Light or dark ----
  //
  // Without a choice the page follows the system setting through the CSS in doc.css.
  // A choice sets `data-theme` on `<html>`; the head of the page applies a kept choice
  // before the first paint, and this file applies it again in case the head did not.
  var darkQuery = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  var keptTheme = stored(THEME_KEY);
  if (keptTheme === 'light' || keptTheme === 'dark') document.documentElement.dataset.theme = keptTheme;

  function shownTheme() {
    var t = root.getAttribute('data-theme');
    if (t === 'light' || t === 'dark') return t;
    return darkQuery && darkQuery.matches ? 'dark' : 'light';
  }

  var ctrl = document.querySelector('.doc-ctrl');
  var refresh = function () {};

  function pressed() {
    if (!ctrl) return;
    var t = shownTheme();
    all('button[data-lang]', ctrl).forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-lang') === lang ? 'true' : 'false');
    });
    all('button[data-theme-choice]', ctrl).forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-theme-choice') === t ? 'true' : 'false');
    });
  }

  function setTheme(mode) {
    if (mode !== 'light' && mode !== 'dark') return;
    document.documentElement.dataset.theme = mode;
    store(THEME_KEY, mode);
    pressed();
  }

  function setLang(next) {
    if (!known(next)) return;
    lang = next;
    root.setAttribute('data-ui-lang', lang);
    store(LANG_KEY, lang);
    relabel(document);
    pressed();
    refresh();
    // Axis units change width with the language, so the charts are drawn again.
    if (typeof window.dxCharts === 'function') window.dxCharts(document, true);
  }

  if (ctrl) {
    all('button[data-lang]', ctrl).forEach(function (b) {
      b.addEventListener('click', function () { setLang(b.getAttribute('data-lang')); });
    });
    all('button[data-theme-choice]', ctrl).forEach(function (b) {
      b.addEventListener('click', function () { setTheme(b.getAttribute('data-theme-choice')); });
    });
  }
  listen(darkQuery, pressed);
  relabel(document);
  pressed();

  // On narrow screens the switches join the top bar, so the reader sees them without opening
  // the contents list. On wide screens they go back to the header band.
  var bar = document.querySelector('.doc-mbar');
  var narrow = window.matchMedia ? window.matchMedia('(max-width: 860px)') : null;
  if (ctrl && bar && narrow) {
    var home = document.createComment(' doc-ctrl ');
    ctrl.parentNode.insertBefore(home, ctrl);
    var place = function () {
      if (narrow.matches) {
        if (ctrl.parentNode !== bar) bar.appendChild(ctrl);
      } else if (ctrl.previousSibling !== home) {
        home.parentNode.insertBefore(ctrl, home.nextSibling);
      }
    };
    place();
    listen(narrow, place);
  }

  // ---- Dialogs ----
  //
  // One dialog is open at a time, as a modal dialog (`showModal`), which keeps Tab inside it and
  // closes it on Escape. Its close button sits in a `form method="dialog"`, takes the focus when the
  // dialog opens, and the focus goes back to the button that opened it when it closes.
  function busy() { return !!document.querySelector('dialog[open]'); }

  // Wires the ways a dialog closes (its button, Escape, the browser) to one ending that runs
  // `after` once per opening, right away rather than when the browser's close event arrives.
  // Returns the function that opens it.
  function closing(dlg, after) {
    var shown = false;
    function shut(e) {
      if (e.type !== 'close') e.preventDefault();
      if (dlg.open) dlg.close();
      if (!shown) return;
      shown = false;
      after();
    }
    dlg.querySelector('.doc-close').addEventListener('click', shut);
    dlg.addEventListener('cancel', shut);
    dlg.addEventListener('close', shut);
    return function () { shown = true; dlg.showModal(); };
  }

  function dialogBar(title) {
    var head = document.createElement('div');
    head.className = 'doc-dialog-bar';
    head.appendChild(title);
    var form = document.createElement('form');
    form.method = 'dialog';
    var close = document.createElement('button');
    close.className = 'doc-close';
    close.value = 'close';
    close.autofocus = true;
    close.setAttribute('data-ui-label', 'close');
    close.setAttribute('aria-label', say('close'));
    close.textContent = '✕';
    form.appendChild(close);
    head.appendChild(form);
    return head;
  }

  // The help: how to move between sections, enlarge a figure, and save a PDF.
  var help = document.querySelector('.doc-help');
  var showHelp = null;
  function helpDialog() {
    var dlg = document.createElement('dialog');
    dlg.className = 'doc-helpbox';
    dlg.setAttribute('aria-labelledby', 'doc-helpbox-title');
    var title = document.createElement('h2');
    title.id = 'doc-helpbox-title';
    title.setAttribute('data-ui', 'helpTitle');
    dlg.appendChild(dialogBar(title));
    var list = document.createElement('ul');
    ['helpKeys', 'helpEnlarge', 'helpPdf'].forEach(function (key) {
      var li = document.createElement('li');
      li.setAttribute('data-ui', key);
      list.appendChild(li);
    });
    dlg.appendChild(list);
    document.body.appendChild(dlg);
    relabel(dlg);
    return closing(dlg, function () { help.focus(); });
  }
  if (help) {
    help.addEventListener('click', function () {
      if (busy()) return;
      showHelp = showHelp || helpDialog();
      showHelp();
    });
  }

  // ---- Enlarged figures ----
  //
  // Every figure gets a button at the right of its caption that opens a copy of its drawing in a
  // dialog filling the window: the copy is laid out at the figure's width and drawn at twice that
  // size (doc.css), and the reader scrolls around it. Pressing the drawing does the same.
  // The dialog is put inside the figure, so the figure's own CSS (the rules of an `html` block sit
  // under its id) draws the copy too, and it is removed when it closes.
  var ENLARGE_ICON = '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">' +
    '<path d="M9.5 2.5h4v4M13.5 2.5 9 7M6.5 13.5h-4v-4M2.5 13.5 7 9"/></svg>';
  // The parts of a figure that are not its drawing: the caption, controls, and the lines about them.
  var NOT_DRAWING = 'figcaption, button, script, style, dialog, .chart-views, .chart-ctrl, .tabtext, ' +
    '.fig-more, .doc-views-list, .paper-only';

  function drawing(fig) {
    return [].filter.call(fig.children, function (el) { return !el.matches(NOT_DRAWING); });
  }

  // A copy of one part of the drawing without ids (references inside an SVG, such as arrow heads,
  // still reach the figure's own), and without the scrolling frame's region, focus stop, and cue.
  function copyOf(part) {
    var copy = part.cloneNode(true);
    [copy].concat(all('[id]', copy)).forEach(function (el) { el.removeAttribute('id'); });
    all('.fig-more', copy).forEach(function (el) { el.parentNode.removeChild(el); });
    (copy.matches('.fig-scroll') ? [copy] : all('.fig-scroll', copy)).forEach(function (el) {
      ['role', 'tabindex', 'aria-label', 'data-more'].forEach(function (a) { el.removeAttribute(a); });
    });
    return copy;
  }

  function enlarge(fig, button) {
    var parts = drawing(fig);
    if (busy() || !parts.length) return;
    var cs = getComputedStyle(fig);
    var dlg = document.createElement('dialog');
    dlg.className = 'fig-zoom';
    dlg.setAttribute('aria-labelledby', 'fig-zoom-title');
    var title = document.createElement('p');
    title.className = 'fig-zoom-title';
    title.id = 'fig-zoom-title';
    var cap = fig.querySelector(':scope > figcaption');
    if (cap) [].forEach.call(cap.childNodes, function (n) { title.appendChild(n.cloneNode(true)); });
    dlg.appendChild(dialogBar(title));
    var view = document.createElement('div');
    view.className = 'fig-zoom-view';
    var stage = document.createElement('div');
    stage.className = 'fig-zoom-stage';
    stage.style.width = (fig.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight)) + 'px';
    parts.forEach(function (part) { stage.appendChild(copyOf(part)); });
    view.appendChild(stage);
    dlg.appendChild(view);
    var show = closing(dlg, function () {
      fig.removeChild(dlg);
      button.focus();
    });
    fig.appendChild(dlg);
    show();
  }

  function enlargers(scope) {
    all('figure.free, figure.chart', scope).forEach(function (fig) {
      var cap = fig.querySelector(':scope > figcaption');
      if (!cap || fig.querySelector(':scope > .fig-enlarge')) return;
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'fig-enlarge';
      b.setAttribute('data-ui-label', 'enlarge');
      b.setAttribute('aria-label', say('enlarge'));
      b.setAttribute('aria-haspopup', 'dialog');
      b.innerHTML = ENLARGE_ICON;
      fig.insertBefore(b, cap);
      b.addEventListener('click', function () { enlarge(fig, b); });
      // A press on the drawing, not on a link or control in it and not the end of a text selection.
      fig.addEventListener('click', function (e) {
        var t = e.target, picked = window.getSelection ? window.getSelection() : null;
        if (t.closest('a, button, summary, input, select, textarea, label, dialog') || (picked && String(picked))) return;
        if (drawing(fig).some(function (part) { return part.contains(t); })) enlarge(fig, b);
      });
    });
  }
  enlargers(document);

  // ---- Collapsed details ----
  //
  // A run of four or more collapsed blocks starts with buttons (render.py writes them) that open
  // or close every block of the run.
  document.addEventListener('click', function (e) {
    var b = e.target && e.target.closest ? e.target.closest('.details-all button[data-details]') : null;
    if (!b) return;
    var open = b.getAttribute('data-details') === 'open';
    for (var d = b.parentNode.nextElementSibling; d && d.matches('details.exp'); d = d.nextElementSibling) d.open = open;
  });

  // ---- Pages and sections ----

  var pages = [].slice.call(document.querySelectorAll('.doc-page'));
  if (!pages.length) return;

  var main = document.querySelector('.doc-main');
  var menu = bar ? bar.querySelector('button[aria-controls]') : null;
  var scrim = document.querySelector('.doc-scrim');
  var side = document.getElementById('doc-side');
  var tablist = document.querySelector('.doc-pages');
  var pageButtons = [].slice.call(document.querySelectorAll('.doc-pages button[data-page]'));
  var current = null;

  function keyOf(page) { return page.getAttribute('data-page'); }
  function pageOf(key) { return pages.filter(function (p) { return keyOf(p) === key; })[0]; }
  function sections(page) { return all('section.doc-sec', page); }
  function tocOf(key) { return document.querySelector('nav.doc-toc[data-page="' + key + '"]'); }

  function fill(page) {
    var t = page.querySelector('template[data-fill]');
    if (!t) return;
    page.insertBefore(t.content, t);
    page.removeChild(t);
    if (typeof window.dxCharts === 'function') window.dxCharts(page);
    enlargers(page);
  }

  // Paper output needs the pages that have not been opened yet.
  window.dxFillAllPages = function () { pages.forEach(fill); };

  function showSection(index, byUser) {
    var list = sections(current);
    if (!list.length) return;
    var i = Math.max(0, Math.min(list.length - 1, index));
    list.forEach(function (s, j) { s.classList.toggle('on', j === i); });
    // The section now has a width: its charts are drawn at it, and wide figures get their cue.
    if (typeof window.dxCharts === 'function') window.dxCharts(list[i]);
    frames(list[i]);
    var toc = tocOf(keyOf(current));
    if (toc) {
      all('button[data-sec]', toc).forEach(function (b) {
        if (b.getAttribute('data-sec') === list[i].id) b.setAttribute('aria-current', 'true');
        else b.removeAttribute('aria-current');
      });
    }
    var name = list[i].getAttribute('data-name') || '';
    all('.doc-here').forEach(function (el) {
      el.textContent = name;
      el.setAttribute('aria-label', say('here', { name: name }));
    });
    all('.doc-count').forEach(function (el) {
      el.textContent = (i + 1) + '/' + list.length;
      el.setAttribute('aria-label', say('count', { i: i + 1, n: list.length }));
      el.setAttribute('title', say('count', { i: i + 1, n: list.length }));
    });
    all('.doc-step button[data-step]').forEach(function (b) {
      var step = Number(b.getAttribute('data-step'));
      b.disabled = (step < 0 && i === 0) || (step > 0 && i === list.length - 1);
    });
    if (byUser) {
      if (main) main.scrollTop = 0;
      if (window.history && window.history.replaceState) {
        window.history.replaceState(null, '', '#' + list[i].id);
      }
    }
  }

  function shownIndex() {
    var list = sections(current);
    var on = list.filter(function (s) { return s.classList.contains('on'); })[0];
    return list.indexOf(on);
  }

  // A new interface language rewrites the section count and the current section label.
  refresh = function () { if (current) showSection(shownIndex(), false); };

  // The page tabs are tabs (`role="tab"`): only the chosen one is selected and in the Tab order,
  // and it is scrolled into view when the tabs do not all fit the header band.
  function showPage(key) {
    var page = pageOf(key) || pages[0];
    pages.forEach(function (p) {
      var on = p === page;
      if (on) fill(p);
      p.hidden = !on;
    });
    pageButtons.forEach(function (b) {
      var on = b.getAttribute('data-page') === keyOf(page);
      b.setAttribute('aria-selected', on ? 'true' : 'false');
      b.tabIndex = on ? 0 : -1;
      if (on) b.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    });
    all('nav.doc-toc').forEach(function (n) { n.hidden = n.getAttribute('data-page') !== keyOf(page); });
    current = page;
  }

  function choose(tab) {
    showPage(tab.getAttribute('data-page'));
    showSection(0, true);
  }

  // The tab that the left and right arrow keys, Home, and End move to from tab `i`, or -1.
  function tabStep(key, i) {
    var n = pageButtons.length;
    if (key === 'ArrowRight') return (i + 1) % n;
    if (key === 'ArrowLeft') return (i + n - 1) % n;
    if (key === 'Home') return 0;
    if (key === 'End') return n - 1;
    return -1;
  }

  function indexOf(id) {
    var list = sections(current);
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return i;
    return 0;
  }

  // The page that holds the element with this id, including pages still in a `template`.
  function ownerOf(id) {
    for (var i = 0; i < pages.length; i++) {
      var p = pages[i];
      if (p.querySelector('[id="' + id + '"]')) return p;
      var t = p.querySelector('template[data-fill]');
      if (t && t.content.querySelector('[id="' + id + '"]')) return p;
    }
    return null;
  }

  // On narrow screens the contents list is a drawer over the page. While it is closed it is inert,
  // so Tab does not reach its hidden buttons; while it is open the page behind it is inert. Opening
  // it moves the focus to the current section, and closing it gives the focus back to its button.
  var behind = all('.doc-top, .doc-mbar, .doc-main');
  function asDrawer() { return !!(narrow && narrow.matches); }
  function sideOpen() { return root.classList.contains('doc-side-open'); }
  function settle() {
    var drawer = asDrawer(), open = drawer && sideOpen();
    if (side) side.toggleAttribute('inert', drawer && !open);
    behind.forEach(function (el) { el.toggleAttribute('inert', open); });
  }
  function openSide(on) {
    var was = sideOpen();
    root.classList.toggle('doc-side-open', on);
    if (menu) menu.setAttribute('aria-expanded', on ? 'true' : 'false');
    settle();
    if (on === was || !asDrawer()) return;
    if (on) {
      var toc = tocOf(keyOf(current));
      var here = toc ? toc.querySelector('button[aria-current]') || toc.querySelector('button[data-sec]') : null;
      if (here) here.focus();
    } else if (menu) {
      menu.focus();
    }
  }
  listen(narrow, settle);

  pageButtons.forEach(function (b) {
    b.addEventListener('click', function () { choose(b); });
  });
  if (tablist) {
    tablist.addEventListener('keydown', function (e) {
      var i = pageButtons.indexOf(document.activeElement);
      var j = i < 0 ? -1 : tabStep(e.key, i);
      if (j < 0) return;
      e.preventDefault();
      pageButtons[j].focus();
      choose(pageButtons[j]);
    });
  }
  all('nav.doc-toc button[data-sec]').forEach(function (b) {
    b.addEventListener('click', function () {
      showSection(indexOf(b.getAttribute('data-sec')), true);
      openSide(false);
    });
  });
  all('.doc-step button[data-step]').forEach(function (b) {
    b.addEventListener('click', function () {
      showSection(shownIndex() + Number(b.getAttribute('data-step')), true);
    });
  });
  if (menu) menu.addEventListener('click', function () { openSide(!sideOpen()); });
  if (scrim) scrim.addEventListener('click', function () { openSide(false); });
  // The left and right arrow keys move between sections, except where they already do something:
  // in a control, in a dialog, and in a frame or table box that scrolls.
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { openSide(false); return; }
    if (e.target && e.target.closest && e.target.closest('input, textarea, select, button, dialog, .fig-scroll, .tbl')) return;
    if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
    showSection(shownIndex() + (e.key === 'ArrowRight' ? 1 : -1), true);
  });

  // Links inside the document. For a section on another page, show that page first.
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href^="#"]') : null;
    if (!a) return;
    var id = a.getAttribute('href').slice(1);
    var owner = id ? ownerOf(id) : null;
    if (!owner) return;
    e.preventDefault();
    showPage(keyOf(owner));
    var target = document.getElementById(id);
    var sec = target && target.closest ? target.closest('section.doc-sec') : null;
    showSection(sec ? indexOf(sec.id) : 0, true);
    if (target && target !== sec && target.scrollIntoView) target.scrollIntoView();
  });

  // When the page opens with a `#` fragment, show that section.
  var hash = window.location.hash.slice(1);
  var start = hash ? ownerOf(hash) : null;
  showPage(start ? keyOf(start) : keyOf(pages.filter(function (p) { return !p.hidden; })[0] || pages[0]));
  if (start) {
    var el = document.getElementById(hash);
    var sec = el && el.closest ? el.closest('section.doc-sec') : null;
    showSection(sec ? indexOf(sec.id) : 0, false);
  } else {
    showSection(0, false);
  }
  settle();
})();
