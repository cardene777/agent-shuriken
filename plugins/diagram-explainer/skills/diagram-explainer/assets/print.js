(function () {
  'use strict';

  // Paper and PDF. No header or contents list; every section in order, one section per page.
  //
  // Charts with buttons show every state on paper.
  // In a document with several pages, the PDF button offers "this page only" or "all pages".
  // Printing straight from the browser's print dialog prints all pages.
  //
  // The PDF is made by the reader's print dialog ("Save as PDF"). The document does not
  // assemble a PDF itself, so it stays one file that loads nothing from outside.

  var root = document.documentElement;
  var pages = document.querySelectorAll('.doc-page');
  var many = pages.length > 1;
  var chosen = null;

  // Interface text, chosen from the document language.
  var TEXT = {
    en: { button: 'PDF', label: 'Save as PDF', page: 'This page only', all: 'All pages' },
    ja: { button: 'PDF', label: 'PDFで保存', page: 'このページだけ', all: '全部のページ' }
  };
  var ui = TEXT[/^ja/i.test(root.lang || '') ? 'ja' : 'en'];

  function all(sel, el) { return [].slice.call((el || document).querySelectorAll(sel)); }

  // Under each time band chart, list every view button with its text. Runs once.
  function expand() {
    all('.chart-views').forEach(function (box) {
      if (box.nextElementSibling && box.nextElementSibling.classList.contains('doc-views-list')) return;
      var ul = document.createElement('ul');
      ul.className = 'doc-views-list';
      all('button', box).forEach(function (b) {
        var li = document.createElement('li');
        var head = document.createElement('b');
        head.textContent = b.textContent;
        li.appendChild(head);
        li.appendChild(document.createTextNode(' ' + (b.getAttribute('data-say') || '')));
        ul.appendChild(li);
      });
      box.parentNode.insertBefore(ul, box.nextSibling);
    });
  }

  function paperOn(mode) {
    var m = mode === 'page' && many ? 'page' : 'all';
    if (m === 'all' && typeof window.dxFillAllPages === 'function') window.dxFillAllPages();
    expand();
    root.setAttribute('data-paper', m);
  }
  function paperOff() {
    root.removeAttribute('data-paper');
    chosen = null;
  }

  window.addEventListener('beforeprint', function () { paperOn(chosen || 'all'); });
  window.addEventListener('afterprint', paperOff);

  // `?paper=1` (all pages) and `?paper=page` show the paper layout on screen for checking.
  var asked = (window.location.search.match(/[?&]paper=([a-z0-9]+)/) || [])[1];
  if (asked) paperOn(asked === 'page' ? 'page' : 'all');

  function print(mode) {
    chosen = mode;
    paperOn(mode);
    // Opening the dialog right away would fix the layout before figure heights settle.
    window.setTimeout(function () { window.print(); }, 120);
  }

  var bar = document.createElement('div');
  bar.className = 'printbar';
  var open = document.createElement('button');
  open.type = 'button';
  open.className = 'doc-pdf printbtn';
  open.setAttribute('aria-label', ui.label);
  open.setAttribute('aria-haspopup', many ? 'true' : 'false');
  open.setAttribute('aria-expanded', 'false');
  open.textContent = ui.button;
  bar.appendChild(open);

  function close() {
    bar.classList.remove('open');
    open.setAttribute('aria-expanded', 'false');
  }

  if (many) {
    var menu = document.createElement('div');
    menu.className = 'printmenu';
    menu.setAttribute('role', 'menu');
    ['page', 'all'].forEach(function (mode) {
      var b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('role', 'menuitem');
      b.setAttribute('data-print', mode);
      b.textContent = ui[mode];
      b.addEventListener('click', function () { close(); print(mode); });
      menu.appendChild(b);
    });
    bar.appendChild(menu);
    open.addEventListener('click', function () {
      var on = !bar.classList.contains('open');
      bar.classList.toggle('open', on);
      open.setAttribute('aria-expanded', on ? 'true' : 'false');
    });
    document.addEventListener('click', function (e) { if (!bar.contains(e.target)) close(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
  } else {
    open.addEventListener('click', function () { print('all'); });
  }

  // With several pages the button goes to the right of the header; otherwise above the contents list.
  var top = document.querySelector('.doc-top');
  var side = document.querySelector('.doc-side');
  if (top) top.appendChild(bar);
  else if (side) side.insertBefore(bar, side.querySelector('.doc-toc'));
  else document.body.appendChild(bar);
})();
