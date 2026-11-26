(function () {
  'use strict';

  // Charts drawn inside the document: time bands, capped bars, bar charts, and periods.
  // Each chart is an svg with `data-chart` (the kind) and `data-spec` (the id of a
  // `<script type="application/json">` element holding what to draw), inside a frame of its own
  // (`.fig-scroll`). Example numbers and short notes are drawn in the chart; hovering a dot or
  // bar shows its tip.
  //
  // Size. A chart is drawn at the width of its frame in pixels, so its text keeps the sizes
  // written here (12px or more) at every screen width. Each kind also measures the narrowest
  // width at which its own words fit: hour and year labels apart, a band's name inside its band,
  // a part's name inside its part. When the frame is narrower than that, the chart is drawn at
  // that width and scrolls sideways in its frame, and doc.js shows that it continues.
  // A chart is drawn again when its frame changes width: when its section opens, and when the
  // window is resized.
  //
  // Layers. Grid lines and guides are drawn first. Bars are opaque, so a line never shows through
  // a bar, and text on the background of the frame gets an outline in that color, so a line that
  // passes behind the text stops at it.
  //
  // Everything is drawn by this file alone, so the document loads nothing from outside.

  var NS = 'http://www.w3.org/2000/svg';
  // Interface text (axis units and the default capped bar buttons) comes from the dictionary of
  // the page (assets/ui.json), through doc.js, which is loaded first. Each unit is marked with
  // `data-ui`, so it follows the language switch.
  var ui = window.dxUi;
  // Named colors are tokens in doc.css, with a light and a dark value; other values are used as given.
  var NAMED = ['gray', 'blue', 'orange', 'violet', 'violet2', 'green', 'red'];
  function col(c) { return NAMED.indexOf(c) >= 0 ? 'var(--chart-' + c + ')' : (c || 'var(--chart-gray)'); }
  // A token (`var(--line)`) is set through the style, so the chart follows a switch between
  // light and dark without being drawn again; other values are attributes.
  var PAINT = { fill: true, stroke: true, 'stop-color': true };
  function paint(e, k, v) {
    if (PAINT[k] && /^var\(/.test(String(v))) e.style.setProperty(k, v);
    else e.setAttribute(k, v);
  }
  function el(tag, attrs, parent, text) {
    var e = document.createElementNS(NS, tag);
    Object.keys(attrs).forEach(function (k) { paint(e, k, attrs[k]); });
    if (text != null) e.textContent = text;
    if (parent) parent.appendChild(e);
    return e;
  }
  // An axis unit such as an hour or a year: interface text with the number `n` in it.
  function unitText(key, n, attrs, parent) {
    attrs['data-ui'] = key;
    attrs['data-ui-n'] = n;
    return el('text', attrs, parent, ui.say(key, { n: n }));
  }
  // An outline in the color behind a text, painted under the letters: a line drawn earlier
  // stops at the text instead of running through it.
  function halo(t, color) {
    paint(t, 'stroke', color || 'var(--panel)');
    t.setAttribute('stroke-width', 4);
    t.setAttribute('stroke-linejoin', 'round');
    t.setAttribute('paint-order', 'stroke');
    return t;
  }

  // The width of a text in pixels, in the font of the page.
  var pen = null;
  function measure(text, size, weight) {
    if (!pen) pen = document.createElement('canvas').getContext('2d');
    pen.font = (weight || 400) + ' ' + size + 'px ' + getComputedStyle(document.body).fontFamily;
    return pen.measureText(text == null ? '' : String(text)).width;
  }
  function widest(list, size, weight) {
    return list.reduce(function (w, t) { return Math.max(w, measure(t, size, weight)); }, 0);
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

  // ---- Time bands ----
  // Each lane has bands for open hours, dots for moments in the day, and dashed spans.

  function hours(s) {
    var r = { from: s.from != null ? s.from : 0, to: s.to != null ? s.to : 24, step: s.step || 3, list: [] };
    for (var h = r.from; h <= r.to; h += r.step) r.list.push(h);
    return r;
  }
  function hourWords(r) { return r.list.map(function (h) { return ui.say('hour', { n: h }); }); }
  // The lane names column: `labelWidth`, or wider when a name needs it.
  function laneColumn(s) {
    return Math.max(s.labelWidth || 120, Math.ceil(widest(s.lanes.map(function (l) { return l.name; }), 15, 700)) + 16);
  }
  // Room right of the last hour, so its label stays inside the chart.
  function hourEnd(r) { return Math.max(15, Math.ceil(measure(hourWords(r).slice(-1)[0], 13) / 2) + 2); }
  // How far the marks of a lane reach above and below its line.
  function reach(lane) {
    var m = { above: 13, below: 13 };
    (lane.dots || []).forEach(function (d) {
      if (!d.label) return;
      if (d.pos === 'down') m.below = Math.max(m.below, 32);
      else m.above = Math.max(m.above, 31);
    });
    (lane.spans || []).forEach(function (p) { m.below = Math.max(m.below, (p.dy != null ? p.dy : 20) + 22); });
    return m;
  }
  // The parts of the axis a lane's bands leave open: the guide runs only there.
  function openHours(lane, r) {
    var open = [[r.from, r.to]];
    (lane.bands || []).forEach(function (b) {
      open = [].concat.apply([], open.map(function (o) {
        if (b.to <= o[0] || b.from >= o[1]) return [o];
        var out = [];
        if (b.from > o[0]) out.push([o[0], b.from]);
        if (b.to < o[1]) out.push([b.to, o[1]]);
        return out;
      }));
    });
    return open;
  }

  var K = {};

  K.timeband = {
    min: function (s) {
      var r = hours(s), span = r.to - r.from;
      var plot = (widest(hourWords(r), 13) + 16) * span / r.step;
      s.lanes.forEach(function (lane) {
        (lane.bands || []).forEach(function (b) {
          if (!b.label || b.to <= b.from) return;
          var name = (b.labelPad != null ? b.labelPad : 10) + measure(b.label, 13, 600);
          plot = Math.max(plot, (name + 10) * span / (b.to - b.from));
          // A band's name ends before a dot on the same band, so the dot does not cover it.
          (lane.dots || []).forEach(function (d) {
            if (d.at > b.from && d.at < b.to) plot = Math.max(plot, (name + 18) * span / (d.at - b.from));
          });
        });
      });
      return laneColumn(s) + hourEnd(r) + plot;
    },
    draw: function (svg, s, W) {
      var r = hours(s), L = laneColumn(s), Rx = W - hourEnd(r), gap = s.gap || 64;
      function hx(h) { return L + (Rx - L) * (h - r.from) / (r.to - r.from); }
      // Lanes are spaced by what they carry, so a note under one lane keeps clear of the next
      // lane and of the axis.
      var ys = [], below = 0;
      s.lanes.forEach(function (lane, i) {
        var m = reach(lane);
        ys.push(i === 0 ? Math.max(46, m.above + 18) : ys[i - 1] + Math.max(gap, below + m.above + 14));
        below = m.below;
      });
      var first = ys[0], end = ys[ys.length - 1] + Math.max(30, below + 10), axis = end + 22;
      svg.setAttribute('viewBox', '0 0 ' + W + ' ' + (axis + 20));
      r.list.forEach(function (h) {
        el('line', { x1: hx(h), x2: hx(h), y1: first - 30, y2: end, stroke: 'var(--line)', 'stroke-width': 1 }, svg);
        unitText('hour', h, { x: hx(h), y: axis, 'text-anchor': 'middle', 'font-size': 13, fill: 'var(--ink-3)' }, svg);
      });
      s.lanes.forEach(function (lane, i) {
        var y = ys[i];
        var g = el('g', { 'data-lane': lane.key || ('lane' + i) }, svg);
        el('text', { x: 0, y: y + 5, 'font-size': 15, 'font-weight': 700, fill: 'var(--ink)' }, g, lane.name);
        openHours(lane, r).forEach(function (o) {
          el('line', { x1: hx(o[0]), x2: hx(o[1]), y1: y, y2: y, stroke: 'var(--line-2)', 'stroke-dasharray': '3 4' }, g);
        });
        (lane.bands || []).forEach(function (b) {
          hover(el('rect', { x: hx(b.from), y: y - 13, width: hx(b.to) - hx(b.from), height: 26, rx: 7, fill: col(b.color) }, g), b.tip);
          if (b.label) {
            hover(el('text', { x: hx(b.from) + (b.labelPad != null ? b.labelPad : 10), y: y + 5, 'font-size': 13, 'font-weight': 600, fill: 'var(--chart-on)' }, g, b.label), b.tip);
          }
        });
        (lane.spans || []).forEach(function (p) {
          var a = hx(p.from) + 10, z = hx(p.to) - 10, dy = p.dy != null ? p.dy : 20;
          el('path', { d: 'M' + a + ' ' + (y + dy) + ' L' + z + ' ' + (y + dy), stroke: col(p.color), 'stroke-width': 1.5, 'stroke-dasharray': '5 4', fill: 'none' }, g);
          halo(el('text', { x: (a + z) / 2, y: y + dy + 17, 'text-anchor': 'middle', 'font-size': 12.5, fill: col(p.color) }, g, p.label));
        });
        (lane.dots || []).forEach(function (d) {
          var dg = el('g', {}, g);
          el('circle', { cx: hx(d.at), cy: y, r: 7, fill: col(d.color), stroke: 'var(--panel)', 'stroke-width': 2 }, dg);
          var anchor = d.align === 'end' ? 'end' : d.align === 'start' ? 'start' : 'middle';
          var tx = anchor === 'end' ? hx(d.at) + 9 : anchor === 'start' ? hx(d.at) - 9 : hx(d.at);
          halo(el('text', { x: tx, y: d.pos === 'down' ? y + 27 : y - 18, 'text-anchor': anchor, 'font-size': 13, 'font-weight': 600, fill: col(d.color) }, dg, d.label));
          hover(dg, d.tip);
        });
      });
    }
  };

  // ---- Capped bar ----
  // One bar against a limit. Buttons switch between before and after trimming to the limit.

  K.capbar = {
    setup: function (svg, s, st) {
      // Without `buttons` in the spec, the buttons say before and after in the interface language.
      var ctrl = document.createElement('div');
      ctrl.className = 'chart-ctrl';
      (s.buttons ? s.buttons.slice(0, 2) : ['before', 'after']).forEach(function (name, i) {
        var k = i === 0 ? 'before' : 'after';
        var b = document.createElement('button');
        b.type = 'button';
        if (s.buttons) {
          b.textContent = name;
        } else {
          b.setAttribute('data-ui', k);
          b.textContent = ui.say(k);
        }
        b.setAttribute('data-k', k);
        b.addEventListener('click', function () {
          st.k = k;
          if (st.show) st.show(k);
        });
        ctrl.appendChild(b);
      });
      var frame = svg.parentNode;
      frame.parentNode.insertBefore(ctrl, frame);
      st.ctrl = ctrl;
    },
    // Each part's name fits inside the part, on one line or as the name over the percent.
    min: function (s) {
      var need = 320, cap = s.cap;
      function room(label, value, pad) {
        if (!value) return;
        var w = label ? Math.max(measure(label, 14, 600), measure(value + '%', 14, 600)) : measure(value + '%', 14, 600);
        need = Math.max(need, (w + pad) * 100 / value);
      }
      var held = s.held || { value: 0 };
      if (held.label) room(held.label, held.value, 24);
      (s.items || []).forEach(function (it) { room(it.label, it.before, 20); room(it.label, it.after, 20); });
      // The limit's label and the sentences under it are centered on the limit line.
      [[s.capLabel || (cap + '%'), 13.5, 700], [s.beforeSay || '', 13, 400], [s.afterSay || '', 13, 400]].forEach(function (t) {
        var half = measure(t[0], t[1], t[2]) / 2 + 6;
        need = Math.max(need, half * 100 / Math.max(100 - cap, 1), half * 100 / Math.max(cap, 1));
      });
      return Math.min(need, 1600);
    },
    draw: function (svg, s, W, st) {
      function px(p) { return W * p / 100; }
      svg.setAttribute('viewBox', '0 0 ' + W + ' 150');
      [0, 25, 50, 75, 100].forEach(function (p) {
        el('text', { x: px(p), y: 14, 'text-anchor': p === 0 ? 'start' : p === 100 ? 'end' : 'middle', 'font-size': 12, fill: 'var(--ink-3)' }, svg, p + '%');
      });
      el('rect', { x: 0, y: 30, width: W, height: 52, rx: 10, fill: 'var(--track)' }, svg);
      var held = s.held || { label: '', value: 0 };
      var parts = [{ label: held.label, before: held.value, after: held.value, color: 'gray', tip: held.tip, held: true }]
        .concat(s.items || []).map(function (it) {
          var r = el('rect', { y: 30, height: 52, fill: col(it.color) }, svg);
          if (it.held) r.setAttribute('rx', 10);
          else r.style.transition = 'x .5s ease, width .5s ease';
          hover(r, it.tip);
          return { it: it, r: r };
        });
      // The limit line goes over the parts, on a stripe in the frame's color so it stands out
      // from a part of a similar color, and the parts' names go over the line.
      var lim = px(s.cap);
      el('line', { x1: lim, x2: lim, y1: 20, y2: 96, stroke: 'var(--panel)', 'stroke-width': 6 }, svg);
      el('line', { x1: lim, x2: lim, y1: 20, y2: 96, stroke: col('red'), 'stroke-width': 2.5, 'stroke-dasharray': '6 4' }, svg);
      parts.forEach(function (p) {
        p.t = [0, 1].map(function () {
          return halo(el('text', { 'font-size': 14, 'font-weight': 600, fill: 'var(--chart-on)', 'text-anchor': 'middle' }, svg), col(p.it.color));
        });
      });
      halo(el('text', { x: lim, y: 116, 'text-anchor': 'middle', 'font-size': 13.5, 'font-weight': 700, fill: col('red') }, svg, s.capLabel || (s.cap + '%')));
      var say = halo(el('text', { x: lim, y: 140, 'text-anchor': 'middle', 'font-size': 13 }, svg, ''));
      function put(t, x, y, text) {
        t.setAttribute('x', x);
        t.setAttribute('y', y);
        t.textContent = text;
      }
      function show(k) {
        var x = 0;
        parts.forEach(function (p, i) {
          var v = k === 'before' ? p.it.before : p.it.after, w = px(v), cx = px(x + v / 2);
          p.r.setAttribute('x', px(x));
          // The first part is rounded like the track; it runs on under the next part, so its
          // rounded right end does not leave notches where the two meet.
          var next = parts[i + 1] ? px(k === 'before' ? parts[i + 1].it.before : parts[i + 1].it.after) : 0;
          p.r.setAttribute('width', p.it.held && v ? w + Math.min(10, next) : w);
          var one = p.it.label + ' ' + v + '%';
          if (!v || (p.it.held && !p.it.label)) {
            put(p.t[0], cx, 62, '');
            put(p.t[1], cx, 62, '');
          } else if (measure(one, 14, 600) + 16 <= w) {
            put(p.t[0], cx, 62, one);
            put(p.t[1], cx, 62, '');
          } else {
            put(p.t[0], cx, 52, p.it.label);
            put(p.t[1], cx, 70, v + '%');
          }
          x += v;
        });
        say.textContent = (k === 'before' ? s.beforeSay : s.afterSay) || '';
        paint(say, 'fill', k === 'before' ? col('red') : col('green'));
        [].forEach.call(st.ctrl.querySelectorAll('button'), function (b) {
          var on = b.getAttribute('data-k') === k;
          b.classList.toggle('on', on);
          b.setAttribute('aria-pressed', on ? 'true' : 'false');
        });
      }
      // Paper has no buttons, so a copy showing the "after" state is placed below.
      // The copy drops `data-chart` and its id so it is not drawn again.
      if (st.copy && st.copy.parentNode) st.copy.parentNode.removeChild(st.copy);
      show('after');
      var copy = svg.cloneNode(true);
      ['id', 'data-chart', 'data-spec', 'data-chart-drawn', 'style'].forEach(function (a) { copy.removeAttribute(a); });
      copy.setAttribute('class', 'paper-only');
      copy.setAttribute('aria-hidden', 'true');
      svg.parentNode.parentNode.insertBefore(copy, svg.parentNode.nextSibling);
      st.copy = copy;
      st.show = show;
      show(st.k);
    }
  };

  // ---- Bar chart ----

  function barTicks(s) {
    var t = [];
    for (var v = 0; v <= s.max; v += s.step) t.push(v + (s.unit || ''));
    return t;
  }
  function barLeft(s) { return Math.max(70, Math.ceil(widest(barTicks(s), 12)) + 24); }
  function barText(b) { return b.text != null ? b.text : String(b.value); }

  K.bars = {
    min: function (s) {
      var per = 56;
      s.bars.forEach(function (b) { per = Math.max(per, measure(b.label, 14) + 16, measure(barText(b), 17, 700) + 12); });
      return Math.max(barLeft(s) + 20 + per * s.bars.length, measure(s.yLabel || '', 12) + 8);
    },
    draw: function (svg, s, W) {
      var L = barLeft(s), Rx = W - 20, T = 30, B = 280;
      function py(v) { return B - (B - T) * v / s.max; }
      svg.setAttribute('viewBox', '0 0 ' + W + ' 320');
      for (var v = 0; v <= s.max; v += s.step) {
        el('line', { x1: L, x2: Rx, y1: py(v), y2: py(v), stroke: 'var(--line)', 'stroke-width': 1 }, svg);
        el('text', { x: L - 12, y: py(v) + 4, 'text-anchor': 'end', 'font-size': 12, fill: 'var(--ink-3)' }, svg, v + (s.unit || ''));
      }
      if (s.yLabel) el('text', { x: 0, y: T - 14, 'font-size': 12, fill: 'var(--ink-3)' }, svg, s.yLabel);
      var slot = (Rx - L) / s.bars.length, bw = Math.min(160, slot * 0.5);
      s.bars.forEach(function (b, i) {
        var cx = L + slot * (i + 0.5);
        hover(el('rect', { x: cx - bw / 2, y: py(b.value), width: bw, height: B - py(b.value), rx: 8, fill: col(b.color) }, svg), b.tip);
        halo(el('text', { x: cx, y: py(b.value) - 10, 'text-anchor': 'middle', 'font-size': 17, 'font-weight': 700, fill: col(b.color) }, svg, barText(b)));
        el('text', { x: cx, y: B + 26, 'text-anchor': 'middle', 'font-size': 14, fill: 'var(--ink-2)' }, svg, b.label);
      });
    }
  };

  // ---- Period chart ----
  // On a year axis: a cut-off line, an outlined span up to it, and a highlighted span.

  function yearEdges(s) {
    return {
      L: Math.max(40, Math.ceil(measure(ui.say('year', { n: s.from }), 13) / 2) + 2),
      R: Math.max(20, Math.ceil(measure(ui.say('year', { n: s.to }), 13) / 2) + 2)
    };
  }

  K.period = {
    min: function (s) {
      var e = yearEdges(s), t = s.test, learn = s.learn || {}, per = 0;
      for (var y = s.from; y <= s.to; y++) per = Math.max(per, measure(ui.say('year', { n: y }), 13) + 12);
      if (learn.label) per = Math.max(per, (measure(learn.label, 14, 600) + 24) / Math.max(s.cut.at - s.from, 0.25));
      per = Math.max(per, (measure(t.label, 14, 600) + 24) / Math.max(t.to - t.from, 0.25));
      // The note sits left of the highlighted span, clear of the cut line.
      if (s.note) {
        var room = t.from > s.cut.at ? t.from - s.cut.at : t.from - s.from;
        per = Math.max(per, (measure(s.note, 13) + 26) / Math.max(room, 0.25));
      }
      // The cut line's label is centered on it and stays inside the chart.
      if (s.cut.at > s.from) per = Math.max(per, (measure(s.cut.label, 12.5, 700) / 2 - e.L) / (s.cut.at - s.from));
      return e.L + e.R + per * (s.to - s.from);
    },
    draw: function (svg, s, W) {
      var e = yearEdges(s), L = e.L, Rx = W - e.R;
      function px(y) { return L + (Rx - L) * (y - s.from) / (s.to - s.from); }
      svg.setAttribute('viewBox', '0 0 ' + W + ' 220');
      for (var y = s.from; y <= s.to; y++) {
        el('line', { x1: px(y), x2: px(y), y1: 40, y2: 178, stroke: 'var(--line)', 'stroke-width': 1 }, svg);
        unitText('year', y, { x: px(y), y: 200, 'text-anchor': 'middle', 'font-size': 13, fill: 'var(--ink-3)' }, svg);
      }
      var learn = s.learn || {};
      hover(el('rect', { x: L, y: 52, width: Math.max(px(s.cut.at) - L, 0), height: 40, rx: 8, fill: 'var(--panel)', stroke: col('orange'), 'stroke-width': 1.5 }, svg), learn.tip);
      if (learn.label) el('text', { x: px(s.cut.at) - 12, y: 78, 'text-anchor': 'end', 'font-size': 14, 'font-weight': 600, fill: col('orange') }, svg, learn.label);
      el('line', { x1: px(s.cut.at), x2: px(s.cut.at), y1: 38, y2: 178, stroke: col('orange'), 'stroke-width': 2 }, svg);
      halo(el('text', { x: px(s.cut.at), y: 28, 'text-anchor': 'middle', 'font-size': 12.5, 'font-weight': 700, fill: col('orange') }, svg, s.cut.label));
      var t = s.test, mid = (px(t.from) + px(t.to)) / 2;
      hover(el('rect', { x: px(t.from), y: 112, width: px(t.to) - px(t.from), height: 40, rx: 8, fill: col('blue') }, svg), t.tip);
      el('text', { x: mid, y: 138, 'text-anchor': 'middle', 'font-size': 14, 'font-weight': 600, fill: 'var(--chart-on)' }, svg, t.label);
      if (t.sub) halo(el('text', { x: mid, y: 172, 'text-anchor': 'middle', 'font-size': 12.5, fill: col('blue') }, svg, t.sub));
      if (s.note) halo(el('text', { x: px(t.from) - 14, y: 138, 'text-anchor': 'end', 'font-size': 13, fill: 'var(--ink-2)' }, svg, s.note));
    }
  };

  // ---- Drawing at the frame's width ----

  function specOf(svg, scope) {
    var id = svg.getAttribute('data-spec');
    var node = id ? (scope.querySelector ? scope.querySelector('[id="' + id + '"]') : null) || document.getElementById(id) : null;
    return node ? JSON.parse(node.textContent) : null;
  }

  // The width inside the frame. A frame that is not shown has none.
  var lastRoom = 0;
  function roomOf(frame) {
    if (!frame || !frame.clientWidth) return 0;
    var cs = getComputedStyle(frame);
    return Math.floor(frame.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight));
  }

  // The lanes a time band view keeps at full strength (`data-keep`); the others fade.
  function keepLanes(svg) {
    var keep = svg.getAttribute('data-keep');
    keep = keep ? keep.split(',') : null;
    [].forEach.call(svg.querySelectorAll('g[data-lane]'), function (g) {
      g.style.opacity = !keep || keep.indexOf(g.getAttribute('data-lane')) >= 0 ? '1' : '.15';
    });
  }

  // Draws the chart at the width of its frame, or at its narrowest width when the frame is
  // narrower; then the chart keeps that width as its min-width and the frame scrolls.
  // A chart whose frame is not shown is drawn at the last known width and again when shown.
  function render(svg, force) {
    var st = svg._dx;
    var room = roomOf(svg.parentNode);
    if (room > 0) lastRoom = room;
    else if (st.W && !force) return;
    room = room || lastRoom || 960;
    var min = Math.ceil(K[st.kind].min(st.spec));
    var W = Math.max(room, min);
    if (W === st.W && !force) return;
    st.W = W;
    svg.style.minWidth = W > room ? W + 'px' : '';
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    K[st.kind].draw(svg, st.spec, W, st);
    keepLanes(svg);
    ui.relabel(svg);
    if (typeof window.dxFrames === 'function') window.dxFrames(svg.parentNode.parentNode);
  }

  var watcher = window.ResizeObserver ? new ResizeObserver(function (entries) {
    entries.forEach(function (entry) {
      var svg = entry.target.querySelector('svg[data-chart]');
      if (svg && svg._dx) render(svg);
    });
  }) : null;
  if (!watcher) window.addEventListener('resize', function () { window.dxCharts(document); });

  // View buttons above a time band keep only the chosen lanes at full strength. The chosen
  // button is marked as pressed, so a screen reader names the view shown.
  function wireViews(scope) {
    [].forEach.call(scope.querySelectorAll('.chart-views[data-chart]'), function (box) {
      if (box.hasAttribute('data-chart-wired')) return;
      box.setAttribute('data-chart-wired', '');
      var svg = document.getElementById(box.getAttribute('data-chart'));
      var text = document.getElementById(box.getAttribute('data-text'));
      var buttons = [].slice.call(box.querySelectorAll('button'));
      function pick(b) {
        buttons.forEach(function (x) {
          x.classList.toggle('on', x === b);
          x.setAttribute('aria-pressed', x === b ? 'true' : 'false');
        });
        if (svg) {
          if (b.getAttribute('data-lanes')) svg.setAttribute('data-keep', b.getAttribute('data-lanes'));
          else svg.removeAttribute('data-keep');
          keepLanes(svg);
        }
        if (text) text.textContent = b.getAttribute('data-say') || '';
      }
      buttons.forEach(function (b) { b.addEventListener('click', function () { pick(b); }); });
      if (buttons[0]) pick(buttons[0]);
    });
  }

  // Draws the charts in `scope` that are not drawn yet, and draws again those whose frame changed
  // width. `doc.js` calls this when a page or a section opens, and with `force` when the interface
  // language changes, because the axis units change width.
  window.dxCharts = function (scope, force) {
    scope = scope || document;
    [].forEach.call(scope.querySelectorAll('svg[data-chart]'), function (svg) {
      if (svg._dx) { render(svg, force); return; }
      // A copy of a drawn chart (cloneNode) keeps what it shows.
      if (svg.hasAttribute('data-chart-drawn')) return;
      var kind = svg.getAttribute('data-chart');
      var spec = specOf(svg, scope);
      if (!K[kind] || !spec) return;
      svg.setAttribute('data-chart-drawn', '');
      svg._dx = { kind: kind, spec: spec, W: 0, k: 'before' };
      if (K[kind].setup) K[kind].setup(svg, spec, svg._dx);
      render(svg, true);
      // Marks the interface text with its language when it differs from the document's.
      ui.relabel(svg.parentNode.parentNode);
      if (watcher) watcher.observe(svg.parentNode);
    });
    wireViews(scope);
  };
  window.dxCharts(document);
})();
