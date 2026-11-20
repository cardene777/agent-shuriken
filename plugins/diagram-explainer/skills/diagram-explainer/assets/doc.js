(function () {
  'use strict';

  // Explainer layout. The left contents list picks a section; one section is shown at a time.
  //
  // A document with 2 or more topics is split into pages by tabs in the header.
  // The body of a page that is not shown is kept in a `template` and moved into the page
  // when it opens, so its charts are drawn only when the reader gets there.
  //
  // This file also holds the interface text of the whole page and the two switches in the
  // header: the language of that text, and light or dark colors. It is loaded before
  // charts.js and print.js, which take their text from `window.dxUi`.

  var root = document.documentElement;

  // Every interface string of the page: the frame that render.py writes, the section count,
  // the switches, the PDF menu (print.js), and the chart units (charts.js).
  // The document's own text stays in the language it was written in.
  // `{name}`, `{i}`, and `{n}` are filled in by `say`.
  var TEXT = {
    en: {
      contents: 'Contents', pageContents: '{name} contents', pages: 'Pages',
      prev: 'Previous section', next: 'Next section',
      count: 'Section {i} of {n}', here: 'Current section: {name}',
      language: 'Language', theme: 'Light or dark', light: 'Light', dark: 'Dark',
      pdf: 'PDF', pdfLabel: 'Save as PDF', pdfPage: 'This page only', pdfAll: 'All pages',
      hour: '{n}:00', year: '{n}', before: 'Before', after: 'After'
    },
    ja: {
      contents: '目次', pageContents: '{name}の目次', pages: 'ページ',
      prev: '前の節', next: '次の節',
      count: '全{n}節中{i}節目', here: '今の節：{name}',
      language: '表示の言語', theme: '画面の明るさ', light: '明るい', dark: '暗い',
      pdf: 'PDF', pdfLabel: 'PDFで保存', pdfPage: 'このページだけ', pdfAll: '全部のページ',
      hour: '{n}時', year: '{n}年', before: '前', after: '後'
    }
  };
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
    var s = TEXT[lang][key];
    if (s == null) s = TEXT.en[key] || '';
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
  // the contents list. On wide screens they go back to the header or above the contents list.
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

  // ---- Pages and sections ----

  var pages = [].slice.call(document.querySelectorAll('.doc-page'));
  if (!pages.length) return;

  var main = document.querySelector('.doc-main');
  var menu = bar ? bar.querySelector('button[aria-controls]') : null;
  var scrim = document.querySelector('.doc-scrim');
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
  }

  // Paper output needs the pages that have not been opened yet.
  window.dxFillAllPages = function () { pages.forEach(fill); };

  function showSection(index, byUser) {
    var list = sections(current);
    if (!list.length) return;
    var i = Math.max(0, Math.min(list.length - 1, index));
    list.forEach(function (s, j) { s.classList.toggle('on', j === i); });
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

  function showPage(key) {
    var page = pageOf(key) || pages[0];
    pages.forEach(function (p) {
      var on = p === page;
      if (on) fill(p);
      p.hidden = !on;
    });
    pageButtons.forEach(function (b) {
      if (b.getAttribute('data-page') === keyOf(page)) b.setAttribute('aria-current', 'page');
      else b.removeAttribute('aria-current');
    });
    all('nav.doc-toc').forEach(function (n) { n.hidden = n.getAttribute('data-page') !== keyOf(page); });
    current = page;
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

  function openSide(on) {
    root.classList.toggle('doc-side-open', on);
    if (menu) menu.setAttribute('aria-expanded', on ? 'true' : 'false');
  }

  pageButtons.forEach(function (b) {
    b.addEventListener('click', function () {
      showPage(b.getAttribute('data-page'));
      showSection(0, true);
    });
  });
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
  if (menu) menu.addEventListener('click', function () { openSide(!root.classList.contains('doc-side-open')); });
  if (scrim) scrim.addEventListener('click', function () { openSide(false); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { openSide(false); return; }
    if (e.target && e.target.closest && e.target.closest('input, textarea, select, button')) return;
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
})();
