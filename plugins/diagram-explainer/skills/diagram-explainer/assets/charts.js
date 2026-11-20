(function () {
  'use strict';

  // Charts drawn inside the document: time bands, capped bars, bar charts, and periods.
  // Each chart is an svg with `data-chart` (the kind) and `data-spec` (the id of a
  // `<script type="application/json">` element holding what to draw).
  // Example numbers and short notes are drawn in the chart; hovering a dot or bar shows its tip.
  //
  // Everything is drawn by this file alone, so the document loads nothing from outside.

  var NS = 'http://www.w3.org/2000/svg';
  // Interface text, chosen from the document language. `{n}` is a number.
  var TEXT = {
    en: { hour: '{n}:00', year: '{n}', before: 'Before', after: 'After' },
    ja: { hour: '{n}時', year: '{n}年', before: '前', after: '後' }
  };
  var ui = TEXT[/^ja/i.test(document.documentElement.lang || '') ? 'ja' : 'en'];
  function unit(key, n) { return ui[key].replace('{n}', n); }
  var COLORS = {
    gray: '#64748b', blue: '#0369a1', orange: '#c2410c', violet: '#6d28d9',
    violet2: '#8b5cf6', green: '#047857', red: '#b91c1c'
  };
  function col(c) { return COLORS[c] || c || COLORS.gray; }
  function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
  function el(tag, attrs, parent, text) {
    var e = document.createElementNS(NS, tag);
    Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (text != null) e.textContent = text;
    if (parent) parent.appendChild(e);
    return e;
  }

  var tip = null;
  function hover(node, text) {
    if (!text) return;
    if (!tip) {
      tip = document.createElement('div');
      tip.className = 'ftip';
      document.body.appendChild(tip);
    }
    node.addEventListener('mousemove', function (e) {
      tip.textContent = text;
      tip.style.left = Math.min(e.clientX + 14, innerWidth - 280) + 'px';
      tip.style.top = (e.clientY + 16) + 'px';
      tip.style.opacity = 1;
    });
    node.addEventListener('mouseleave', function () { tip.style.opacity = 0; });
  }

  var R = {
    // Time bands. Each lane has bands for open hours and dots for moments in the day.
    timeband: function (svg, s) {
      var from = s.from != null ? s.from : 0, to = s.to != null ? s.to : 24;
      var step = s.step || 3, gap = s.gap || 64, L = s.labelWidth || 120, Rx = 985, top = 46;
      function hx(h) { return L + (Rx - L) * (h - from) / (to - from); }
      var last = top + (s.lanes.length - 1) * gap;
      svg.setAttribute('viewBox', '0 0 1000 ' + (last + 76));
      for (var h = from; h <= to; h += step) {
        el('line', { x1: hx(h), x2: hx(h), y1: top - 30, y2: last + 30, stroke: css('--line'), 'stroke-width': 1 }, svg);
        el('text', { x: hx(h), y: last + 54, 'text-anchor': 'middle', 'font-size': 13, fill: css('--ink-3') }, svg, unit('hour', h));
      }
      s.lanes.forEach(function (lane, i) {
        var y = top + i * gap;
        var g = el('g', { 'data-lane': lane.key || ('lane' + i) }, svg);
        el('text', { x: 0, y: y + 5, 'font-size': 15, 'font-weight': 700, fill: css('--ink') }, g, lane.name);
        el('line', { x1: L, x2: Rx, y1: y, y2: y, stroke: css('--line-2'), 'stroke-dasharray': '3 4' }, g);
        (lane.bands || []).forEach(function (b) {
          var r = el('rect', { x: hx(b.from), y: y - 13, width: hx(b.to) - hx(b.from), height: 26, rx: 7, fill: col(b.color), opacity: 0.16 }, g);
          hover(r, b.tip);
          if (b.label) hover(el('text', { x: hx(b.from) + (b.labelPad != null ? b.labelPad : 10), y: y + 5, 'font-size': 12.5, fill: css('--ink-2') }, g, b.label), b.tip);
        });
        (lane.spans || []).forEach(function (p) {
          var a = hx(p.from) + 10, z = hx(p.to) - 10, dy = p.dy != null ? p.dy : 20;
          el('path', { d: 'M' + a + ' ' + (y + dy) + ' L' + z + ' ' + (y + dy), stroke: col(p.color), 'stroke-width': 1.5, 'stroke-dasharray': '5 4', fill: 'none' }, g);
          el('text', { x: (a + z) / 2, y: y + dy + 17, 'text-anchor': 'middle', 'font-size': 12.5, fill: col(p.color) }, g, p.label);
        });
        (lane.dots || []).forEach(function (d) {
          var dg = el('g', {}, g);
          el('circle', { cx: hx(d.at), cy: y, r: 7, fill: col(d.color), stroke: '#fff', 'stroke-width': 2 }, dg);
          var anchor = d.align === 'end' ? 'end' : d.align === 'start' ? 'start' : 'middle';
          var tx = anchor === 'end' ? hx(d.at) + 9 : anchor === 'start' ? hx(d.at) - 9 : hx(d.at);
          el('text', { x: tx, y: d.pos === 'down' ? y + 27 : y - 15, 'text-anchor': anchor, 'font-size': 13, 'font-weight': 600, fill: col(d.color) }, dg, d.label);
          hover(dg, d.tip);
        });
      });
    },

    // Capped bar. Buttons switch between before and after trimming to the cap.
    capbar: function (svg, s) {
      function px(p) { return 1000 * p / 100; }
      svg.setAttribute('viewBox', '0 0 1000 150');
      var buttons = s.buttons || [ui.before, ui.after];
      var ctrl = document.createElement('div');
      ctrl.className = 'chart-ctrl';
      buttons.slice(0, 2).forEach(function (label, i) {
        var b = document.createElement('button');
        b.type = 'button';
        b.setAttribute('data-k', i === 0 ? 'before' : 'after');
        b.textContent = label;
        ctrl.appendChild(b);
      });
      svg.parentNode.insertBefore(ctrl, svg);
      [0, 25, 50, 75, 100].forEach(function (p) {
        el('text', { x: px(p), y: 14, 'text-anchor': p === 0 ? 'start' : p === 100 ? 'end' : 'middle', 'font-size': 11.5, fill: css('--ink-3') }, svg, p + '%');
      });
      el('rect', { x: 0, y: 30, width: 1000, height: 52, rx: 10, fill: '#f1f1f4' }, svg);
      var held = s.held || { label: '', value: 0 };
      hover(el('rect', { x: 0, y: 30, width: px(held.value), height: 52, rx: 10, fill: col('gray') }, svg), held.tip);
      if (held.label) el('text', { x: 16, y: 62, 'font-size': 15, 'font-weight': 600, fill: '#fff' }, svg, held.label + ' ' + held.value + '%');
      // The cap line is drawn behind the bar, visible only above and below it, so it never covers a label.
      var lim = px(s.cap);
      el('line', { x1: lim, x2: lim, y1: 20, y2: 96, stroke: col('red'), 'stroke-width': 2.5, 'stroke-dasharray': '6 4' }, svg);
      var parts = (s.items || []).map(function (it) {
        var r = el('rect', { y: 30, height: 52, fill: col(it.color) }, svg);
        var t = el('text', { y: 62, 'font-size': 14, 'font-weight': 600, fill: '#fff', 'text-anchor': 'middle' }, svg);
        r.style.transition = 'x .5s ease, width .5s ease';
        t.style.transition = 'x .5s ease';
        hover(r, it.tip);
        return { it: it, r: r, t: t };
      });
      el('text', { x: lim, y: 116, 'text-anchor': 'middle', 'font-size': 13.5, 'font-weight': 700, fill: col('red') }, svg, s.capLabel || (s.cap + '%'));
      var say = el('text', { x: lim, y: 140, 'text-anchor': 'middle', 'font-size': 13 }, svg, '');
      function draw(k) {
        var x = held.value;
        parts.forEach(function (p) {
          var w = k === 'before' ? p.it.before : p.it.after;
          p.r.setAttribute('x', px(x));
          p.r.setAttribute('width', px(w));
          p.t.setAttribute('x', px(x + w / 2));
          p.t.textContent = p.it.label + ' ' + w + '%';
          x += w;
        });
        say.textContent = (k === 'before' ? s.beforeSay : s.afterSay) || '';
        say.setAttribute('fill', k === 'before' ? col('red') : col('green'));
        [].forEach.call(ctrl.querySelectorAll('button'), function (b) {
          b.classList.toggle('on', b.getAttribute('data-k') === k);
        });
      }
      [].forEach.call(ctrl.querySelectorAll('button'), function (b) {
        b.addEventListener('click', function () { draw(b.getAttribute('data-k')); });
      });
      // Paper has no buttons, so a copy showing the "after" state is placed below.
      // The copy drops `data-chart` and its id so it is not drawn again.
      draw('after');
      var copy = svg.cloneNode(true);
      copy.removeAttribute('id');
      copy.removeAttribute('data-chart');
      copy.removeAttribute('data-spec');
      copy.setAttribute('class', 'paper-only');
      copy.setAttribute('aria-hidden', 'true');
      svg.parentNode.insertBefore(copy, svg.nextSibling);
      draw('before');
    },

    // Bar chart comparing numbers.
    bars: function (svg, s) {
      var L = 90, Rx = 980, T = 30, B = 280;
      function py(v) { return B - (B - T) * v / s.max; }
      svg.setAttribute('viewBox', '0 0 1000 320');
      for (var v = 0; v <= s.max; v += s.step) {
        el('line', { x1: L, x2: Rx, y1: py(v), y2: py(v), stroke: css('--line'), 'stroke-width': 1 }, svg);
        el('text', { x: L - 12, y: py(v) + 4, 'text-anchor': 'end', 'font-size': 12, fill: css('--ink-3') }, svg, v + (s.unit || ''));
      }
      if (s.yLabel) el('text', { x: 0, y: T - 14, 'font-size': 12, fill: css('--ink-3') }, svg, s.yLabel);
      var slot = (Rx - L) / s.bars.length, bw = Math.min(160, slot * 0.5);
      s.bars.forEach(function (b, i) {
        var cx = L + slot * (i + 0.5);
        hover(el('rect', { x: cx - bw / 2, y: py(b.value), width: bw, height: B - py(b.value), rx: 8, fill: col(b.color), opacity: 0.9 }, svg), b.tip);
        el('text', { x: cx, y: py(b.value) - 10, 'text-anchor': 'middle', 'font-size': 17, 'font-weight': 700, fill: col(b.color) }, svg, b.text != null ? b.text : String(b.value));
        el('text', { x: cx, y: B + 26, 'text-anchor': 'middle', 'font-size': 14, fill: css('--ink-2') }, svg, b.label);
      });
    },

    // Period chart. On a year axis: a cut-off line, a faded span up to it, and a highlighted span.
    period: function (svg, s) {
      var L = 40, Rx = 980;
      function px(y) { return L + (Rx - L) * (y - s.from) / (s.to - s.from); }
      svg.setAttribute('viewBox', '0 0 1000 220');
      for (var y = s.from; y <= s.to; y++) {
        el('line', { x1: px(y), x2: px(y), y1: 40, y2: 178, stroke: css('--line'), 'stroke-width': 1 }, svg);
        el('text', { x: px(y), y: 200, 'text-anchor': 'middle', 'font-size': 13, fill: css('--ink-3') }, svg, unit('year', y));
      }
      var id = 'fade-' + (svg.id || Math.random().toString(36).slice(2));
      var grad = el('linearGradient', { id: id, x1: '0', x2: '1' }, el('defs', {}, svg));
      el('stop', { offset: '0', 'stop-color': col('orange'), 'stop-opacity': '0' }, grad);
      el('stop', { offset: '1', 'stop-color': col('orange'), 'stop-opacity': '.24' }, grad);
      var learn = s.learn || {};
      hover(el('rect', { x: L, y: 52, width: px(s.cut.at) - L, height: 40, fill: 'url(#' + id + ')' }, svg), learn.tip);
      if (learn.label) el('text', { x: px(s.cut.at) - 12, y: 78, 'text-anchor': 'end', 'font-size': 14, 'font-weight': 600, fill: col('orange') }, svg, learn.label);
      el('line', { x1: px(s.cut.at), x2: px(s.cut.at), y1: 38, y2: 178, stroke: col('orange'), 'stroke-width': 2 }, svg);
      el('text', { x: px(s.cut.at), y: 28, 'text-anchor': 'middle', 'font-size': 12.5, 'font-weight': 700, fill: col('orange') }, svg, s.cut.label);
      var t = s.test;
      hover(el('rect', { x: px(t.from), y: 112, width: px(t.to) - px(t.from), height: 40, rx: 8, fill: col('blue'), opacity: 0.88 }, svg), t.tip);
      el('text', { x: (px(t.from) + px(t.to)) / 2, y: 138, 'text-anchor': 'middle', 'font-size': 14, 'font-weight': 600, fill: '#fff' }, svg, t.label);
      if (t.sub) el('text', { x: (px(t.from) + px(t.to)) / 2, y: 172, 'text-anchor': 'middle', 'font-size': 12.5, fill: col('blue') }, svg, t.sub);
      if (s.note) el('text', { x: px(t.from) - 14, y: 138, 'text-anchor': 'end', 'font-size': 13, fill: css('--ink-2') }, svg, s.note);
    }
  };

  function specOf(svg, scope) {
    var id = svg.getAttribute('data-spec');
    var node = id ? (scope.querySelector ? scope.querySelector('[id="' + id + '"]') : null) || document.getElementById(id) : null;
    return node ? JSON.parse(node.textContent) : null;
  }

  // View buttons above a time band keep only the chosen lanes at full strength.
  function wireViews(scope) {
    [].forEach.call(scope.querySelectorAll('.chart-views[data-chart]'), function (box) {
      if (box.hasAttribute('data-chart-wired')) return;
      box.setAttribute('data-chart-wired', '');
      var svg = document.getElementById(box.getAttribute('data-chart'));
      var text = document.getElementById(box.getAttribute('data-text'));
      var buttons = [].slice.call(box.querySelectorAll('button'));
      function pick(b) {
        buttons.forEach(function (x) { x.classList.toggle('on', x === b); });
        var keep = b.getAttribute('data-lanes') ? b.getAttribute('data-lanes').split(',') : null;
        if (svg) {
          [].forEach.call(svg.querySelectorAll('g[data-lane]'), function (g) {
            g.style.opacity = !keep || keep.indexOf(g.getAttribute('data-lane')) >= 0 ? '1' : '.15';
          });
        }
        if (text) text.textContent = b.getAttribute('data-say') || '';
      }
      buttons.forEach(function (b) { b.addEventListener('click', function () { pick(b); }); });
      if (buttons[0]) pick(buttons[0]);
    });
  }

  // Charts on a page that is not shown are drawn when the page opens (`doc.js` calls this).
  window.dxCharts = function (scope) {
    scope = scope || document;
    [].forEach.call(scope.querySelectorAll('svg[data-chart]'), function (svg) {
      if (svg.hasAttribute('data-chart-drawn')) return;
      var draw = R[svg.getAttribute('data-chart')];
      var spec = specOf(svg, scope);
      if (!draw || !spec) return;
      svg.setAttribute('data-chart-drawn', '');
      draw(svg, spec);
    });
    wireViews(scope);
  };
  window.dxCharts(document);
})();
