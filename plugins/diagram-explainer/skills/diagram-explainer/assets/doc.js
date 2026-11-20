(function () {
  'use strict';

  // Explainer layout. The left contents list picks a section; one section is shown at a time.
  //
  // A document with 2 or more topics is split into pages by tabs in the header.
  // The body of a page that is not shown is kept in a `template` and moved into the page
  // when it opens, so its charts are drawn only when the reader gets there.

  var root = document.documentElement;
  var pages = [].slice.call(document.querySelectorAll('.doc-page'));
  if (!pages.length) return;

  // Interface text, chosen from the document language.
  var TEXT = {
    en: { count: 'Section {i} of {n}', here: 'Current section: {name}' },
    ja: { count: '全{n}節中{i}節目', here: '今の節：{name}' }
  };
  var ui = TEXT[/^ja/i.test(root.lang || '') ? 'ja' : 'en'];
  function say(key, values) {
    return ui[key].replace(/\{(\w+)\}/g, function (_m, k) { return values[k]; });
  }

  var main = document.querySelector('.doc-main');
  var bar = document.querySelector('.doc-mbar');
  var menu = bar ? bar.querySelector('button') : null;
  var scrim = document.querySelector('.doc-scrim');
  var pageButtons = [].slice.call(document.querySelectorAll('.doc-pages button[data-page]'));
  var current = null;

  function all(sel, el) { return [].slice.call((el || document).querySelectorAll(sel)); }
  function keyOf(page) { return page.getAttribute('data-page'); }
  function pageOf(key) { return pages.filter(function (p) { return keyOf(p) === key; })[0]; }
  function sections(page) { return all('section.doc-sec', page); }
  function tocOf(key) { return document.querySelector('nav.doc-toc[data-page="' + key + '"]'); }

  // ---- Pages and sections ----

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
      var list = sections(current);
      var on = list.filter(function (s) { return s.classList.contains('on'); })[0];
      showSection(list.indexOf(on) + Number(b.getAttribute('data-step')), true);
    });
  });
  if (menu) menu.addEventListener('click', function () { openSide(!root.classList.contains('doc-side-open')); });
  if (scrim) scrim.addEventListener('click', function () { openSide(false); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { openSide(false); return; }
    if (e.target && e.target.closest && e.target.closest('input, textarea, select, button')) return;
    if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
    var list = sections(current);
    var on = list.filter(function (s) { return s.classList.contains('on'); })[0];
    showSection(list.indexOf(on) + (e.key === 'ArrowRight' ? 1 : -1), true);
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
