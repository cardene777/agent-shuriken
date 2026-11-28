// The engine of an explainer video. It reads a theme (window.MX_THEME: colors, characters, pictures) and a
// script (window.MX_SCRIPT: cast, objects, scenes of beats, figures), lays out each scene so that actors and
// objects never overlap, plays the beats on a clock that can pause, resume and jump to a step, and draws the
// figures under the video from the same objects. Nothing in this file names a subject: every word on screen
// comes from the script, every picture from the theme or the script.
(() => {
'use strict';
const TH = window.MX_THEME, SC = window.MX_SCRIPT, UI = window.MX_UI || {};
const W = 896, H = 504;
const mx = document.querySelector('#me-player .mx');
const REDUCE = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const rich = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
const img = n => (TH.images || {})[n];
const color = k => TH.colors[k] || k;
const off = (e, v) => e.toggleAttribute('data-off', !!v);

/* Theme */
for (const [k, v] of Object.entries(TH.colors)) mx.style.setProperty('--' + k, v);
mx.style.setProperty('--font', TH.font);
mx.style.setProperty('--floor', TH.floorY + 'px');
for (const n of ['ok', 'ng']) if (img(n)) mx.style.setProperty('--img-' + n, `url(${img(n)})`);
if (TH.pixelated) mx.classList.add('pixel');
if (REDUCE) mx.classList.add('still-motion');

/* Frame */
const cv = el('div', 'cv'); mx.append(cv);
const bg = el('div', 'bg'); if (img('background')) bg.style.backgroundImage = `url(${img('background')})`;
const ttl = el('div', 'ttl', `<div class="vt">${TH.mark ? `<img alt="" src="${img(TH.mark)}">` : ''}<span>${esc(SC.title)}</span>${SC.subtitle ? `<small>${esc(SC.subtitle)}</small>` : ''}</div><div class="step"></div>`);
const stepEl = ttl.querySelector('.step');
const objLayer = el('div', 'objs'), actLayer = el('div', 'actors'), flyLayer = el('div', 'flies');
const bubble = el('div', 'bubble', '<p></p>'), bl = bubble.firstChild;
cv.append(bg, ttl, objLayer, actLayer, bubble, flyLayer);
const badge = el('div', 'pausebadge', '<svg class="ui" viewBox="0 0 34 34"><path class="ico" d="M11 6 L28 17 L11 28 Z"/></svg>');
const progress = el('div', 'progress');
mx.append(badge, progress);
const ico = badge.querySelector('.ico');
const playBtn = document.getElementById('me-play');
const lineEl = document.getElementById('me-line');

/* Objects and their parts. R maps "object" and "object.part" to elements. */
const R = {}, OBJ = {}, RESTORE = [];
function reg(key, e, restore) { R[key] = e; if (restore) RESTORE.push([e, e.innerHTML]); }
function images(holder, base, states) {
  holder.dataset.state = 'base';
  for (const [k, n] of Object.entries({ base, ...(states || {}) })) { if (!n) continue; const i = el('img'); i.alt = ''; i.src = img(n); i.dataset.k = k; i.style.opacity = k === 'base' ? 1 : 0; holder.append(i); }
}
function swap(holder, state) { holder.dataset.state = state; for (const i of holder.querySelectorAll(':scope > img, :scope > .npic > img, :scope > .ppic > img, :scope > .vp > .shot > img')) i.style.opacity = i.dataset.k === state ? 1 : 0; }
function buildPart(oid, p) {
  let e;
  switch (p.type) {
    case 'text': e = el('p', 'part t-' + (p.style || 'body'), rich(p.text)); break;
    case 'button': e = el('button', 'part btn', esc(p.text)); e.type = 'button'; e.tabIndex = -1; e.dataset.tone = p.tone || 'accent'; e._tone = e.dataset.tone; break;
    case 'row': e = el('div', 'part row'); if (p.justify) e.style.justifyContent = { start: 'flex-start', end: 'flex-end', center: 'center' }[p.justify]; for (const q of p.parts) e.append(buildPart(oid, q)); break;
    case 'tags': e = el('div', 'part tags'); for (const t of p.items) { const s = el('span', 'tg', esc(t.text)); s.dataset.tone = t.tone || 'primary'; s._tone = s.dataset.tone; s._off = !!t.hidden; off(s, t.hidden); e.append(s); if (t.id) reg(`${oid}.${t.id}`, s, true); } break;
    case 'checks': e = el('ul', 'part checks' + (p.style === 'plain' ? ' plain' : '')); for (const it of p.items) { const li = el('li', '', `<span>${rich(it.text)}</span><b class="tok"></b>`); e.append(li); reg(`${oid}.${it.id}`, li, true); } break;
    case 'slots': {
      e = el('div', 'part slots'); e.style.setProperty('--cols', p.cols || p.count);
      if (p.height) e.style.setProperty('--sh', p.height + 'px');
      e._items = Array.from({ length: p.count }, (_, i) => { const s = el('div', 'slot', p.numbered ? `<i>${i + 1}</i>` : ''); if (img(p.image)) s.style.setProperty('--img', `url(${img(p.image)})`); e.append(s); return s; });
      break;
    }
    case 'counter': e = el('div', 'part counter', `<b>${esc(p.start ?? 0)}</b>/${esc(p.total)}${esc(p.unit || '')}`); break;
    case 'image': e = el('div', 'part pic'); e.style.width = (p.width || 110) + 'px'; e.style.height = (p.height || 80) + 'px'; images(e, p.image, p.states); break;
    case 'field': e = el('div', 'part field', `<label>${esc(p.label)}</label><div class="box"><span class="val"></span><span class="ph">${esc(p.placeholder || '')}</span></div>`); break;
    default: throw new Error('unknown part type: ' + p.type);
  }
  e._off = !!p.hidden; off(e, p.hidden);
  if (p.id) reg(`${oid}.${p.id}`, e, ['text', 'button', 'counter', 'field'].includes(p.type));
  return e;
}
/* Nodes: pictures with short names, in rows, joined to their parent by lines. Used for org charts, shelves,
   folders with files: anything better shown as things than as sentences. */
const SVGNS = 'http://www.w3.org/2000/svg';
function nodeOf(n, size) {
  const d = el('div', 'node' + (n.tag ? ' tag' : '') + (n.chip ? ' chip' : '') + (n.float ? ' float' : ''));
  d.style.setProperty('--ns', (n.size || size || 86) + 'px');
  if (n.tone) d.style.setProperty('--tc', color(n.tone));
  if (n.rot != null) d.style.setProperty('--rot', n.rot + 'deg');
  if (!n.chip && !n.tag) { const pic = el('div', 'npic'); if (n.image) images(pic, n.image, n.states); else { pic.classList.add('blank'); images(pic, null, n.states); } d.append(pic); }
  d.dataset.state = 'base';
  d.append(el('span', 'nlabel', esc(n.label || '') + (n.sub ? `<small>${esc(n.sub)}</small>` : '')));
  if (!n.label) d.lastChild.dataset.off = '';
  d.append(el('b', 'tok'));
  d._label0 = d.querySelector('.nlabel').innerHTML;
  d._off = !!n.hidden; off(d, n.hidden);
  return d;
}
function buildNodes(oid, s) {
  const body = el('div', 'nodes' + (s.edges === 'string' ? ' strings' : '')); body.style.setProperty('--gap', (s.gap ?? 22) + 'px'); body.style.setProperty('--rowgap', (s.rowGap ?? 34) + 'px');
  const svg = document.createElementNS(SVGNS, 'svg'); svg.classList.add('edges');
  const halos = document.createElementNS(SVGNS, 'g'), lines = document.createElementNS(SVGNS, 'g');
  svg.append(halos, lines); body.append(svg); body._svg = svg;
  if (s.title) body.append(el('div', 'ntitle', esc(s.title)));
  body._nodes = [];
  body._style = s.edges === 'string' ? 'string' : 'tree';
  s.levels.forEach((level, li) => {
    const row = el('div', 'nrow');
    for (const n of level) {
      const d = nodeOf(n, s.size);
      d._parent = s.edges === false ? null : (n.parent ?? (li ? s.levels[li - 1][0].id : null));
      if (d._parent) {
        // Every line is one path in two layers: all the white halos first, then all the colored lines, so a
        // trunk shared by several children never shows a halo across another line.
        const mk = (cls, layer) => { const p = document.createElementNS(SVGNS, 'path'); p.setAttribute('class', cls); p.setAttribute('pathLength', '1'); layer.append(p); return p; };
        d._edge = body._style === 'string' ? [mk('line', lines)] : [mk('halo', halos), mk('line', lines)];
        edgeOff(d, n.hidden);
      }
      row.append(d); body._nodes.push(d);
      if (n.id) reg(`${oid}.${n.id}`, d, false);
    }
    body.append(row);
  });
  body._oid = oid;
  return body;
}
function edgeOff(d, v) { if (d._edge) for (const p of d._edge) off(p, v); }
function edgeGrow(d) { if (d._edge) for (const p of d._edge) { p.classList.remove('grow'); void p.getBoundingClientRect(); p.classList.add('grow'); } }
/* Positions inside a chart come from the layout (offsets), never from the screen, so a node that is still
   popping in or a chart that is still sliding into place gives the same lines as one at rest. */
function boxIn(e, body) {
  let x = 0, y = 0;
  for (let n = e; n && n !== body; n = n.offsetParent) { x += n.offsetLeft; y += n.offsetTop; }
  return { x, y, w: e.offsetWidth, h: e.offsetHeight, cx: x + e.offsetWidth / 2, b: y + e.offsetHeight };
}
function picBox(d, body) {
  const pic = d.querySelector('.npic');
  if (!pic) return boxIn(d.querySelector('.nlabel'), body);
  const shown = [...pic.querySelectorAll('img')].find(i => i.style.opacity !== '0' && i.offsetHeight);
  return boxIn(shown || pic, body);
}
/* A row whose nodes all hang from one node of an upper row sits under that node, not in the middle. */
function alignRows(body) {
  const cs = getComputedStyle(body), pl = parseFloat(cs.paddingLeft), inner = body.clientWidth - pl - parseFloat(cs.paddingRight);
  for (const row of body.querySelectorAll(':scope > .nrow')) {
    row.style.justifySelf = ''; row.style.marginLeft = '';
    if (row.classList.contains('empty')) continue;
    const ps = new Set([...row.children].map(d => d._parent));
    if (ps.size !== 1 || ps.has(null) || ps.has(undefined)) continue;
    const p = R[`${body._oid}.${[...ps][0]}`];
    if (!p || p.parentElement === row) continue;
    const w = row.offsetWidth, left = Math.max(pl, Math.min(pl + inner - w, picBox(p, body).cx - w / 2));
    row.style.justifySelf = 'start'; row.style.marginLeft = (left - pl) + 'px';
  }
}
function drawEdges(body) {
  if (!body || !body._svg) return;
  alignRows(body);
  body._svg.setAttribute('viewBox', `0 0 ${body.offsetWidth} ${body.offsetHeight}`);
  const by = new Map();
  for (const d of body._nodes) if (d._edge && !d.parentElement.classList.contains('empty')) { if (!by.has(d._parent)) by.set(d._parent, []); by.get(d._parent).push(d); }
  for (const [pid, kids] of by) {
    const p = R[`${body._oid}.${pid}`]; if (!p) continue;
    const pp = picBox(p, body);
    if (body._style === 'string') {
      // A tag hangs from the thing by a string: from just inside its lower edge to the hole at the top of the tag.
      for (const d of kids) {
        const t = boxIn(d.querySelector('.nlabel'), body), cx = t.cx, cy = t.y + 13;
        const sx = pp.cx + Math.max(-1, Math.min(1, (cx - pp.cx) / pp.w)) * pp.w * 0.24, sy = pp.b - pp.h * 0.1;
        const dd = `M${sx} ${sy} C${sx} ${sy + 46} ${cx} ${cy - 56} ${cx} ${cy}`;
        for (const path of d._edge) path.setAttribute('d', dd);
      }
      continue;
    }
    // One trunk down from the parent, one bus across all its children, one drop to each child.
    const px = pp.cx, py = boxIn(p, body).b + 6;
    const tops = kids.map(d => picBox(d, body));
    const bus = Math.round(py + (Math.min(...tops.map(t => t.y)) - 8 - py) / 2);
    kids.forEach((d, i) => {
      const cx = tops[i].cx, cy = tops[i].y - 8, sx = Math.sign(cx - px);
      const r = Math.max(0, Math.min(16, Math.abs(cx - px) / 2, bus - py - 2, cy - bus - 2));
      const dd = Math.abs(cx - px) < 1.5 ? `M${px} ${py} V${cy}` : `M${px} ${py} V${bus - r} Q${px} ${bus} ${px + sx * r} ${bus} H${cx - sx * r} Q${cx} ${bus} ${cx} ${bus + r} V${cy}`;
      for (const path of d._edge) path.setAttribute('d', dd);
    });
  }
}
/* A holder: a picture with a back and an optional front (a rail, a folder, a tray) and things hung on it or
   standing in it. The line they hang from or stand on comes from the anchors of the back picture. */
function buildHolder(oid, s) {
  const W0 = s.width || 440, H0 = W0 * ((TH.aspect || {})[s.back] || 0.6);
  const body = el('div', 'holder' + (s.labels === 'above' ? ' lab-above' : ''));
  const stage = el('div', 'hstage'); stage.style.width = W0 + 'px'; stage.style.height = H0 + 'px';
  const back = el('img', 'hb'); back.alt = ''; back.src = img(s.back); stage.append(back);
  if (s.front) { const f = el('img', 'hf'); f.alt = ''; f.src = img(s.front); stage.append(f); }
  body.append(stage);
  if (s.label) body.append(el('span', 'hlabel', esc(s.label)));
  const anchor = ((TH.anchors || {})[s.back] || {})[s.anchor || 'hang'];
  const line = (s.line ?? (anchor ? anchor[1] : 0.5)) * H0;
  body._nodes = [];
  // A thing with several pictures (an empty hanger that later holds a suit) is measured by all of them, and
  // every name sits on one line, so the names stay level whatever is hanging.
  const VB = (TH.vbox || {}), AS = (TH.aspect || {});
  const items = s.items.map(it => {
    const iw = it.width || s.itemWidth || 110, ih = iw * (AS[it.image] || 1);
    const vs = [it.image, ...Object.values(it.states || {})].map(n => VB[n] || [0, 0, 1, 1]);
    const vb = [Math.min(...vs.map(v => v[0])), Math.min(...vs.map(v => v[1])), Math.max(...vs.map(v => v[2])), Math.max(...vs.map(v => v[3]))];
    const own = VB[it.image] || [0, 0, 1, 1];
    const top = s.stand ? line - own[3] * ih : line - own[1] * ih;
    return { it, iw, ih, vb, top };
  });
  const labelLine = s.labels === 'above' ? Math.min(...items.map(m => m.top + m.vb[1] * m.ih)) - 8 : Math.max(...items.map(m => m.top + m.vb[3] * m.ih)) + 8;
  for (const { it, iw, ih, vb, top } of items) {
    const slot = el('div', 'hslot');
    slot.style.left = (it.x * W0) + 'px'; slot.style.top = top + 'px';
    const d = nodeOf(it, iw);
    const pic = d.querySelector('.npic'); pic.style.width = iw + 'px'; pic.style.height = ih + 'px';
    const lab = d.querySelector('.nlabel');
    if (s.labels === 'above') lab.style.bottom = (top + ih - labelLine) + 'px'; else lab.style.top = (labelLine - top) + 'px';
    const tok = d.querySelector('.tok'); tok.style.top = (vb[1] * ih + ih * (vb[3] - vb[1]) * 0.22 - 14) + 'px'; tok.style.right = ((1 - vb[2]) * iw - 14) + 'px';
    slot.append(d); stage.append(slot); body._nodes.push(d);
    if (it.id) reg(`${oid}.${it.id}`, d, false);
  }
  return body;
}
function buildScreen(oid, s) {
  const body = el('section', 'screen f-' + (s.frame || 'browser'));
  // The window shows the top of the page; a taller page is moved and zoomed inside it, as if scrolled.
  const SW = s.width || 620, ia = (TH.aspect && TH.aspect[s.image]) || 0.625, view = s.view || Math.min(ia, 0.62);
  body.style.setProperty('--w', SW + 'px');
  if (s.frame !== 'phone') body.append(el('div', 'bar', `<i></i><i></i><i></i><span>${esc(s.address || '')}</span>`));
  const vp = el('div', 'vp'); vp.style.height = (SW * view) + 'px';
  const shot = el('div', 'shot'); shot.style.height = (SW * ia) + 'px'; images(shot, s.image, s.states); vp.append(shot); body.append(vp);
  for (const [mid, m] of Object.entries(s.marks || {})) {
    const [x, y, w, h] = m.rect || m;
    const r = el('div', 'mark' + (m.kind ? ' k-' + m.kind : ''), '<span class="mtext"></span>');
    Object.assign(r.style, { left: x * 100 + '%', top: y * 100 + '%', width: w * 100 + '%', height: h * 100 + '%', fontSize: (h * SW * ia * 0.46) + 'px' });
    r._rect = [x, y, w, h]; r._off = true; off(r, true); shot.append(r); reg(`${oid}.${mid}`, r, false);
  }
  const cur = el('div', 'cursor', '<svg class="ui" viewBox="0 0 24 24"><path d="M5 2 L5 20 L9.6 15.6 L12.8 22.4 L16 21 L12.8 14.4 L19 14.4 Z" fill="#1c1a18" stroke="#fff" stroke-width="1.8" stroke-linejoin="round"/></svg>');
  off(cur, true); shot.append(cur);
  Object.assign(body, { _shot: shot, _cursor: cur, _z: 1, _W: SW, _Hv: SW * view, _Hs: SW * ia });
  return body;
}
/* Moves and zooms the page so that rect [x, y, w, h] (fractions of the page) fills the window; null shows its top. */
function focusOn(body, rect, pad = 0.03) {
  const SW = body._W, Hv = body._Hv, Hs = body._Hs;
  let z = 1, tx = 0, ty = 0;
  if (rect) {
    const [x, y, w, h] = rect, rw = w * SW, rh = h * Hs, p = pad * SW;
    z = Math.max(1, Math.min(SW / (rw + 2 * p), Hv / (rh + 2 * p), 4));
    tx = Math.min(0, Math.max(SW - SW * z, SW / 2 - (x * SW + rw / 2) * z));
    ty = Math.min(0, Math.max(Hv - Hs * z, Hv / 2 - (y * Hs + rh / 2) * z));
  }
  body._z = z; body._shot.style.setProperty('--z', z);
  body._shot.style.transform = `translate(${tx}px, ${ty}px) scale(${z})`;
}
function tapAt(body, mark, f) {
  const cur = body._cursor, [x, y, w, h] = mark._rect;
  off(cur, false);
  cur.style.left = (x + w * 0.62) * 100 + '%'; cur.style.top = (y + h * 0.55) * 100 + '%';
  if (f) later(620, () => { mark.classList.remove('click'); void mark.offsetWidth; mark.classList.add('click'); });
}
for (const [id, s] of Object.entries(SC.objects)) {
  let body;
  if (s.type === 'nodes') body = buildNodes(id, s);
  else if (s.type === 'holder') body = buildHolder(id, s);
  else if (s.type === 'screen') body = buildScreen(id, s);
  else if (s.type === 'prop') {
    // The picture takes its height from the tallest of its states before any picture loads, so the layout
    // never measures a prop smaller than it shows.
    const PW = s.width || 160, AS = TH.aspect || {};
    body = el('div', 'prop'); body.style.width = PW + 'px';
    const pic = el('div', 'ppic'); pic.style.height = PW * Math.max(...[s.image, ...Object.values(s.states || {})].map(n => AS[n] || 1)) + 'px';
    images(pic, s.image, s.states); body.append(pic); body._pic = pic;
    if (s.label) body.append(el('span', 'plabel', esc(s.label)));
  } else {
    body = el('section', 'card' + (s.frame ? ' f-' + s.frame : '')); body.style.setProperty('--w', (s.width || 320) + 'px');
    if (s.frame === 'browser') body.append(el('div', 'bar', `<i></i><i></i><i></i><span>${esc(s.address || '')}</span>`));
    if (s.frame === 'phone') body.append(el('div', 'notch'));
    if (s.title && s.band) { const b = el('div', 'band', esc(s.title) + (s.note ? `<small>${esc(s.note)}</small>` : '')); b.style.background = color(s.band); body.append(b); }
    else if (s.title) body.append(el('div', 'head', `<i style="background:${color(s.dot || 'primary')}"></i>${esc(s.title)}${s.note ? `<small>${esc(s.note)}</small>` : ''}`));
    for (const p of s.parts || []) body.append(buildPart(id, p));
  }
  const wrap = el('div', 'obj'); wrap.dataset.object = id; wrap.append(body); off(wrap, true); objLayer.append(wrap);
  OBJ[id] = { wrap, body, spec: s }; R[id] = body;
}
/* A row whose nodes are all hidden takes no room, so a chart grows as its rows appear. */
function rowsOf(body) { let changed = false; for (const row of body.querySelectorAll(':scope > .nrow')) { const empty = !row.querySelector('.node:not([data-off])'); if (row.classList.contains('empty') !== empty) { row.classList.toggle('empty', empty); changed = true; } } return changed; }
function refreshNodes(e) { const body = e.closest('.nodes'); if (!body) return; if (rowsOf(body)) layout(); drawEdges(body); }
addEventListener('load', () => { for (const id in OBJ) drawEdges(OBJ[id].body); });
for (const id in OBJ) if (OBJ[id].body._nodes) { rowsOf(OBJ[id].body); drawEdges(OBJ[id].body); }
if (document.fonts) document.fonts.ready.then(() => { for (const id in OBJ) if (OBJ[id].body._nodes) drawEdges(OBJ[id].body); });

/* Actors */
const ACT = {};
for (const [id, a] of Object.entries(SC.cast)) {
  const ch = TH.characters[a.character];
  const w = el('div', 'actor', `<div class="inner"><img alt=""></div><span class="emote"></span>${a.label ? `<span class="label">${esc(a.label)}</span>` : ''}`);
  w.dataset.actor = id;
  const width = ch.width * (a.scale || 1);
  w.style.width = width + 'px';
  if (a.tone) w.querySelector('.label').style.background = color(a.tone);
  off(w, true); actLayer.append(w);
  ACT[id] = { w, ch, width, height: width * ch.aspect, img: w.querySelector('img'), emote: w.querySelector('.emote'), face: null, label: a.label || '' };
  R[id] = w;
}
function face(id, f) {
  const A = ACT[id], faces = A.ch.faces, name = faces[f] ? f : (A.ch.default || Object.keys(faces)[0]);
  if (A.face !== name) { A.img.src = img(faces[name]); A.face = name; }
}
const EMOTE_TONE = { '!': 'accent', '♪': 'yellow', '?': 'primary' };
function emote(id, sym) { const e = ACT[id].emote; if (!sym) { e.removeAttribute('data-on'); return; } e.textContent = sym; e.dataset.tone = EMOTE_TONE[sym] || 'accent'; e.setAttribute('data-on', ''); }
function act(id, a, f) {
  const w = ACT[id].w; w.classList.remove('hop', 'shake', 'write');
  if (!a || a === 'still') return;
  if (a === 'write' || f) { void w.offsetWidth; w.classList.add(a); }
}

/* Layout: actors take columns at the left and right edges, objects share the space between them. */
let comp = { cast: [], columns: [] }, speaker = null;
const PAD = 12, ACOL = 176, GAP = 18, TOP = 84, BOTTOM = H - 26;
function placeAt(e, left, top, scale) {
  const was = e.hasAttribute('data-off');
  if (was) e.classList.add('snap');
  e.style.left = left + 'px';
  if (top != null) e.style.top = top + 'px';
  if (scale != null) e.style.transform = `scale(${scale})`;
  off(e, false);
  if (was) { void e.offsetWidth; e.classList.remove('snap'); }
}
function layout() {
  const cast = comp.cast.filter(c => ACT[c.id]);
  cast.forEach((c, i) => { c._side = c.side || (i % 2 ? 'right' : 'left'); });
  const left = cast.filter(c => c._side === 'left'), right = cast.filter(c => c._side === 'right');
  const col = c => Math.max(ACOL, ACT[c.id].width + 8);
  let x = PAD;
  for (const c of left) { placeAt(ACT[c.id].w, x + (col(c) - ACT[c.id].width) / 2); x += col(c); }
  let xr = W - PAD;
  for (const c of right) { xr -= col(c); placeAt(ACT[c.id].w, xr + (col(c) - ACT[c.id].width) / 2); }
  for (const id in ACT) if (!cast.some(c => c.id === id)) off(ACT[id].w, true);

  const x0 = left.length ? x + 4 : 30, x1 = right.length ? xr - 4 : W - 30;
  const cols = comp.columns.map(c => c.filter(id => OBJ[id])).filter(c => c.length);
  const shown = new Set(cols.flat());
  for (const id in OBJ) if (!shown.has(id)) off(OBJ[id].wrap, true);
  if (cols.length) {
    const dims = cols.map(c => {
      const ws = c.map(id => OBJ[id].body.offsetWidth), hs = c.map(id => OBJ[id].body.offsetHeight);
      return { w: Math.max(...ws), h: hs.reduce((a, b) => a + b, 0) + GAP * (c.length - 1), ws, hs };
    });
    const totW = dims.reduce((a, d) => a + d.w, 0) + GAP * (cols.length - 1), maxH = Math.max(...dims.map(d => d.h));
    const s = Math.min(comp.zoom || 1.3, (x1 - x0) / totW, (BOTTOM - TOP) / maxH);
    let cx = x0 + ((x1 - x0) - totW * s) / 2;
    cols.forEach((c, i) => {
      const d = dims[i];
      let cy = TOP + ((BOTTOM - TOP) - d.h * s) / 2;
      c.forEach((id, j) => { placeAt(OBJ[id].wrap, cx + (d.w - d.ws[j]) * s / 2, cy, s); cy += (d.hs[j] + GAP) * s; });
      cx += (d.w + GAP) * s;
    });
  }
  placeBubble();
}
function placeBubble() {
  const A = speaker && ACT[speaker];
  if (!A || A.w.hasAttribute('data-off')) { off(bubble, true); return; }
  const left = parseFloat(A.w.style.left), cx = left + A.width / 2;
  const bx = Math.max(8, Math.min(W - 180, cx - 86));
  bubble.style.left = bx + 'px';
  bubble.style.bottom = (H - TH.floorY + A.height * (A.ch.head ?? 1) + 12) + 'px';
  bubble.style.setProperty('--tail', Math.max(22, Math.min(150, cx - bx)) + 'px');
  off(bubble, false);
}
/* The line under the video, for a screen too narrow to read the bubble. */
function caption(who, text) {
  if (!lineEl) return;
  lineEl.innerHTML = text ? (who && ACT[who].label ? `<b>${esc(ACT[who].label)}</b>` : '') + `<span>${rich(text)}</span>` : '';
}

/* Effects from the bundled Sakuga VFX core, sized to the scaled frame. A reader who asks for reduced motion
   sees none. */
const FX = window.SakugaFX;
let k = 1;
if (FX && TH.fx) Object.assign(FX.P, TH.fx);
function target(t) { return R[t] || (OBJ[t] && OBJ[t].body); }
function effect(spec, at) {
  if (REDUCE || !FX || !spec || !at) return;
  const o = typeof spec === 'string' ? { word: spec } : spec;
  const p = FX.at(at, .5, .5);
  if (o.word) FX.sfx(o.word, p.x + (o.dx ?? 0) * k, p.y + (o.dy ?? -46) * k, { size: (o.size || 88) * k, rot: o.rot ?? -0.12 });
  if (o.burst) { FX.burst(p.x, p.y, { r: (o.burst === true ? 56 : o.burst) * k }); FX.shards(p.x, p.y, { n: 7, speed: 230 * k }); }
  if (o.kira) FX.kira(p.x + (o.kdx ?? 40) * k, p.y - 20 * k, { r: 11 * k });
  if (o.puff) { const q = FX.at(at, .5, 1); FX.puff(q.x - q.w * .4, q.y, { n: 4, vx: -26, size: 13 * k }); FX.puff(q.x + q.w * .4, q.y, { n: 4, vx: 26, size: 13 * k }); }
  if (o.slash) FX.slash(p.x, p.y, { len: 110 * k, ang: -0.6, thick: 12 * k });
  if (o.ring) FX.ring(p.x, p.y, { rx: 70 * k, ry: 22 * k });
}
function centerOf(e) { const c = cv.getBoundingClientRect(), r = e.getBoundingClientRect(); return [(r.left + r.width / 2 - c.left) / k, (r.top + r.height / 2 - c.top) / k]; }
function fly(b) {
  const e = el('div', 'fly');
  if (b.image) e.innerHTML = `<img alt="" src="${img(b.image)}" style="width:${b.width || 72}px">`;
  else { e.classList.add('slip'); e.innerHTML = rich(b.text); }
  flyLayer.append(e);
  const w = e.offsetWidth, h = e.offsetHeight, [x0, y0] = centerOf(target(b.from)), [x1, y1] = centerOf(target(b.to));
  e.style.cssText += `;left:${x0 - w / 2}px;top:${y0 - h / 2}px;transform:rotate(-10deg) scale(.8);transition:none`;
  void e.offsetWidth; e.style.transition = '';
  e.style.left = (x1 - w / 2) + 'px'; e.style.top = (y1 - h / 2) + 'px'; e.style.transform = 'rotate(8deg) scale(1)';
  later(800, () => { e.style.opacity = 0; later(250, () => e.remove()); if (b.land) effect(b.land, target(b.to)); });
}
function stamp(b, f) {
  const host = OBJ[b.target] ? OBJ[b.target].body : R[b.target];
  let s = host.querySelector(':scope > .stamp');
  if (!s) { s = el('div', 'stamp', esc(b.text || '')); host.append(s); }
  if (!f || !img(b.image || 'stamp')) { s.setAttribute('data-on', ''); if (f) effect(b.fx, s); return; }
  const im = el('img', 'stamper'); im.alt = ''; im.src = img(b.image || 'stamp');
  const [cx, cy] = centerOf(s), w = 64, h = w * ((TH.aspect || {})[b.image || 'stamp'] || 1.6);
  im.style.cssText = `left:${cx - w / 2}px;top:${cy + 12 - h}px;width:${w}px`;
  flyLayer.append(im);
  later(290, () => { s.setAttribute('data-on', ''); effect(b.fx, s); });
  later(1050, () => im.remove());
}

/* Actions. f is true when played, false when the clock jumps and only the end state is set. */
const DO = {
  say(b, f) {
    if (b.face) face(b.who, b.face);
    if (b.act !== undefined) act(b.who, b.act, f);
    if (b.emote !== undefined) emote(b.who, b.emote);
    speaker = b.who; bl.innerHTML = rich(b.text); caption(b.who, b.text);
    if (f) { bl.classList.remove('pop'); void bl.offsetWidth; bl.classList.add('pop'); }
    placeBubble();
  },
  face(b) { face(b.who, b.face); },
  act(b, f) { act(b.who, b.act, f); },
  emote(b) { emote(b.who, b.emote); },
  enter(b) { for (const w of [].concat(b.who)) if (!comp.cast.some(c => c.id === w)) comp.cast.push({ id: w, side: b.side }); layout(); },
  exit(b) { const ws = [].concat(b.who); comp.cast = comp.cast.filter(c => !ws.includes(c.id)); if (ws.includes(speaker)) speaker = null; layout(); },
  show(b, f) {
    if (OBJ[b.target]) { if (!comp.columns.flat().includes(b.target)) { if (comp.columns[b.column]) comp.columns[b.column].push(b.target); else comp.columns.push([b.target]); } layout(); }
    else { const e = R[b.target]; off(e, false); edgeOff(e, false); refreshNodes(e); if (f) edgeGrow(e); }
  },
  hide(b) {
    if (OBJ[b.target]) { comp.columns = comp.columns.map(c => c.filter(x => x !== b.target)); layout(); }
    else { off(R[b.target], true); edgeOff(R[b.target], true); refreshNodes(R[b.target]); }
  },
  press(b, f) { const e = R[b.target]; if (b.text) e.textContent = b.text; if (b.tone) e.dataset.tone = b.tone; if (f) { e.classList.add('press'); later(140, () => e.classList.remove('press')); } },
  set(b) {
    const e = R[b.target];
    if (e._items) for (const n of b.items || e._items.map((_, i) => i + 1)) { if (b.state) e._items[n - 1].dataset.s = b.state; else delete e._items[n - 1].dataset.s; }
    else if (b.state) e.dataset.s = b.state; else delete e.dataset.s;
  },
  mark(b) { const e = R[b.target]; if (b.on === false) e.removeAttribute('data-on'); else e.setAttribute('data-on', ''); },
  text(b) { const e = R[b.target], t = e._label0 !== undefined ? e.querySelector('.nlabel') : (e.querySelector(':scope > .mtext') || e); t.innerHTML = rich(b.text) + (b.sub ? `<small>${esc(b.sub)}</small>` : ''); off(t, false); if (b.tone) e.dataset.tone = b.tone; if (t !== e) { layout(); drawEdges(e.closest('.nodes')); } },
  swap(b) { swap(R[b.target], b.state); },
  clear(b) { for (const t of [].concat(b.target)) restore(R[t]); },
  shake(b, f) { if (!f) return; const e = target(b.target); e.classList.remove('shake'); void e.offsetWidth; e.classList.add('shake'); },
  fly(b, f) { if (f) fly(b); },
  stamp(b, f) { stamp(b, f); },
  focus(b) { const body = OBJ[b.target].body, m = b.mark && R[`${b.target}.${b.mark}`]; focusOn(body, m ? m._rect : (b.rect || null), b.pad); },
  tap(b, f) { const m = R[b.target]; tapAt(m.closest('.screen'), m, f); },
  fx() {}
};
function restore(e) {
  const r = RESTORE.find(x => x[0] === e);
  if (r) e.innerHTML = r[1];
  delete e.dataset.s; e.removeAttribute('data-on'); off(e, e._off);
  if (e._label0 !== undefined) { const t = e.querySelector('.nlabel'); t.innerHTML = e._label0; off(t, !e._label0); delete e.dataset.tone; }
  edgeOff(e, e._off);
  if (e._tone) e.dataset.tone = e._tone;
  if (e._items) e._items.forEach(s => { delete s.dataset.s; });
  if (e.dataset.state) swap(e, 'base');
}
function run(b, f) {
  DO[b.do](b, f);
  if (f && b.fx && b.do !== 'stamp') effect(b.fx, target(b.fxAt || b.target) || (b.who && ACT[b.who].w));
}

/* Each kind of beat holds the screen for a natural time unless the script says otherwise. */
function natural(b) {
  if (b.hold) return b.hold;
  if (b.do === 'say') return Math.max(1300, Math.min(3800, b.text.length * 105 + 700));
  return { fly: 950, stamp: 1300, enter: 800, exit: 600, show: 800, press: 650, set: 750, shake: 600, focus: 1100, tap: 1100 }[b.do] || 500;
}
const BEATS = [], SCENE_T = [];
let T0 = 0;
SC.scenes.forEach((s, si) => {
  if (si) T0 += s.gap ?? 300;
  SCENE_T.push(T0);
  BEATS.push([T0, f => scene(si, f)]);
  let prev = 700;
  for (const b of s.beats) {
    T0 += b.wait ?? prev;
    const t = T0;
    if (b.do === 'fill') {
      const from = b.from ?? 0, step = b.step ?? 200;
      for (let n = from + 1; n <= b.to; n++) BEATS.push([t + (n - from - 1) * step, f => {
        R[b.target]._items[n - 1].dataset.s = 'done';
        if (b.counter) R[b.counter].querySelector('b').textContent = n;
        if (f && n === from + 1 && b.fx) effect(b.fx, R[b.target]._items[n - 1]);
      }]);
      prev = (b.to - from) * step + 400;
    } else if (b.do === 'count') {
      const from = b.from ?? 0, step = b.step ?? 60;
      for (let n = from + 1; n <= b.to; n++) BEATS.push([t + (n - from - 1) * step, f => {
        const e = R[b.target]; e.querySelector('b').textContent = n;
        if (n === b.to && b.state) e.dataset.s = b.state;
        if (f && b.fx && (n - from) % (b.fxEvery || 1e9) === 1) effect(b.fx, e);
      }]);
      prev = (b.to - from) * step + 400;
    } else if (b.do === 'type') {
      const step = b.step ?? 90, chars = Array.from(b.text);
      BEATS.push([t, () => { off(R[b.target], false); R[b.target].setAttribute('data-on', ''); }]);
      chars.forEach((_, i) => BEATS.push([t + (i + 1) * step, () => { R[b.target].querySelector('.val, .mtext').textContent = chars.slice(0, i + 1).join(''); }]));
      BEATS.push([t + (chars.length + 2) * step, () => R[b.target].removeAttribute('data-on')]);
      prev = (chars.length + 3) * step + 200;
    } else {
      BEATS.push([t, f => run(b, f)]);
      prev = natural(b);
    }
  }
  T0 += prev;
});
const END = T0 + 600;
BEATS.sort((a, b) => a[0] - b[0]);
const sceneAt = t => { let i = 0; while (i + 1 < SCENE_T.length && SCENE_T[i + 1] <= t) i++; return i; };
const sceneEnd = i => (SCENE_T[i + 1] ?? END) - 1;

/* Steps: scenes in a row with the same chapter name make one step. The step being played is named under the
   title, and the bar at the bottom has one segment per step that fills as it plays and plays the step from
   its start on a click. */
const CH = [], RUN = [];
SC.scenes.forEach((s, i) => {
  const name = s.chapter || '';
  if (!CH.length || CH[CH.length - 1].name !== name) CH.push({ name, t: SCENE_T[i] });
  RUN[i] = CH.length - 1;
});
CH.forEach((c, i) => { c.end = CH[i + 1] ? CH[i + 1].t : END; });
const SEG = CH.map(c => {
  const b = el('button', 'seg', '<i></i>'); b.type = 'button'; b.style.flexGrow = Math.max(1, c.end - c.t);
  if (c.name) { b.title = c.name; b.setAttribute('aria-label', c.name); }
  b.addEventListener('click', e => { e.stopPropagation(); seek(c.t, true); });
  progress.append(b); return { ...c, b, fill: b.firstChild };
});
function setBar(t) { for (const s of SEG) s.fill.style.width = Math.max(0, Math.min(1, (t - s.t) / (s.end - s.t))) * 100 + '%'; }
let stepNow = -1;
function chapter(i, f) {
  if (i === stepNow) return;
  stepNow = i;
  SEG.forEach((s, j) => { s.b.dataset.s = j < i ? 'done' : (j === i ? 'now' : ''); });
  const old = stepEl.querySelector('.cur:not(.out)');
  if (!CH[i].name) { if (old) old.remove(); return; }
  const named = CH.filter(c => c.name).length, n = CH.slice(0, i + 1).filter(c => c.name).length;
  const cur = el('span', 'cur', `<b>${n}</b>${esc(CH[i].name)}${named > 1 ? `<small>/ ${named}</small>` : ''}`);
  stepEl.append(cur);
  if (old) { if (f) { old.classList.add('out'); later(450, () => old.remove()); } else old.remove(); }
  if (f) { cur.classList.add('in'); void cur.offsetWidth; cur.classList.remove('in'); }
}

function scene(i, f) {
  const s = SC.scenes[i];
  comp = { cast: (s.cast || []).map(c => typeof c === 'string' ? { id: c } : { ...c }), columns: (s.layout || (s.objects || []).map(o => [o])).map(c => [].concat(c)), zoom: s.zoom };
  if (!comp.cast.some(c => c.id === speaker)) speaker = null;
  // A mark over a head is a reaction to one moment, so it does not carry into the next scene.
  for (const id in ACT) emote(id, null);
  chapter(RUN[i], f);
  layout();
}
function reset() {
  flyLayer.innerHTML = '';
  for (const key in R) if (!ACT[key] && !OBJ[key]) restore(R[key]);
  for (const id in OBJ) if (OBJ[id].body._nodes) { rowsOf(OBJ[id].body); drawEdges(OBJ[id].body); }
  for (const id in OBJ) if (OBJ[id].body._shot) { const b = OBJ[id].body; swap(b, 'base'); focusOn(b, null); off(b._cursor, true); b._shot.querySelectorAll('.mark').forEach(m => { m.querySelector('.mtext').textContent = ''; m.classList.remove('click'); }); }
  for (const id in OBJ) { const b = OBJ[id].body; b.classList.remove('shake'); b.querySelectorAll('.stamp').forEach(s => s.remove()); if (b.dataset.state) swap(b, 'base'); }
  for (const id in ACT) { face(id, ACT[id].ch.default); emote(id, null); act(id, null); }
  speaker = null; bl.textContent = ''; caption(null, '');
  comp = { cast: [], columns: [] };
  stepEl.innerHTML = ''; stepNow = -1;
  SEG.forEach(s => { s.b.dataset.s = ''; });
}
/* Sets the end state of every beat before t, without motion or effects. */
function settle(t, play) {
  cv.classList.add('jump'); reset();
  for (const [bt, f] of BEATS) if (bt < t || (bt === 0 && t === 0 && !play)) f(false);
  void cv.offsetWidth; cv.classList.remove('jump');
}

/* The clock: plays like a video; a click on the video or the play button pauses or plays, and a segment of
   the bar plays its step. With reduced motion, each scene shows at its end state for as long as it lasts. */
let T = 0, playing = false, last = 0, raf = 0, timers = [], held = -1;
function later(ms, f) { timers.push(setTimeout(f, ms)); }
function tick(now) {
  const prev = T;
  T = Math.min(END, T + (now - last)); last = now;
  if (REDUCE) { const i = sceneAt(T); if (i !== held) { held = i; settle(sceneEnd(i) + 1, false); } }
  else for (const [t, f] of BEATS) if (t > prev && t <= T) f(true);
  setBar(T);
  if (T >= END) { SEG.forEach(s => { s.b.dataset.s = 'done'; }); setPlaying(false); return; }
  raf = requestAnimationFrame(tick);
}
function setPlaying(v) {
  playing = v;
  mx.toggleAttribute('data-paused', !v);
  const done = T >= END;
  ico.setAttribute('d', done ? 'M24 9 A10 10 0 1 0 27 19 M24 3 V10 H17' : 'M11 6 L28 17 L11 28 Z');
  ico.setAttribute('fill', done ? 'none' : color('primary')); ico.setAttribute('stroke', done ? color('primary') : 'none'); ico.setAttribute('stroke-width', 3.5); ico.setAttribute('stroke-linecap', 'round');
  if (playBtn) { playBtn.textContent = v ? (UI.pause || 'Pause') : done ? (UI.replay || 'Replay') : (UI.play || 'Play'); playBtn.setAttribute('aria-pressed', String(v)); }
  if (v) { last = performance.now(); raf = requestAnimationFrame(tick); } else cancelAnimationFrame(raf);
}
function seek(t, play) {
  cancelAnimationFrame(raf); timers.forEach(clearTimeout); timers = [];
  if (REDUCE) { held = sceneAt(t); settle(sceneEnd(held) + 1, false); } else settle(t, play);
  T = play ? t - 1 : t;
  setBar(t);
  setPlaying(!!play);
}
function toggle() { if (playing) setPlaying(false); else if (T >= END) seek(0, true); else setPlaying(true); }
mx.addEventListener('click', toggle);
if (playBtn) playBtn.addEventListener('click', toggle);

/* Figures under the video, drawn from the objects of the script: a scene at its end with numbered marks, the
   order of states, two things side by side, and a table. */
function specOf(t) {
  const [oid, pid] = t.split('.'), o = SC.objects[oid];
  if (!pid) return o;
  const find = list => { for (const x of list || []) { if (x.id === pid) return x; const y = find(x.parts); if (y) return y; } return null; };
  return find(o.levels ? o.levels.flat() : o.items || o.parts);
}
function pictureOf(t, state) {
  const s = specOf(t), i = el('img');
  i.alt = ''; i.src = img(state ? s.states[state] : s.image); i.dataset.target = t;
  if (state) i.dataset.state = state;
  if (SC.objects[t.split('.')[0]].type === 'screen') i.classList.add('top');
  return i;
}
const STILLS = [];
function boxOf(key) {
  const e = ACT[key] ? ACT[key].w : OBJ[key] ? OBJ[key].wrap : R[key];
  const c = cv.getBoundingClientRect(), r = e.getBoundingClientRect(), kk = c.width / W;
  return [(r.left - c.left) / kk, (r.top - c.top) / kk, r.width / kk, r.height / kk];
}
function stillOf(f) {
  settle(sceneEnd(f.scene) + 1, false);
  const frame = el('div', 'mx mx-still');
  frame.style.cssText = mx.style.cssText;
  if (TH.pixelated) frame.classList.add('pixel');
  const copy = cv.cloneNode(true);
  copy.querySelector('.flies').innerHTML = '';
  frame.append(copy);
  const legend = el('ol', 'me-legend');
  Object.entries(f.labels).forEach(([key, label], n) => {
    const [x, y, w] = boxOf(key);
    const m = el('span', 'fig-mark', String(n + 1)); m.dataset.mark = key;
    m.style.left = Math.min(W - 30, Math.max(4, x + w - 16)) + 'px'; m.style.top = Math.max(4, y - 10) + 'px';
    copy.append(m);
    legend.append(el('li', '', `<span class="me-badge">${n + 1}</span><span>${esc(label)}</span>`));
  });
  STILLS.push(frame);
  const box = el('div', 'me-still');
  const mini = el('div', 'me-mini'); mini.append(frame);
  box.append(mini, legend);
  return box;
}
function figures() {
  const host = document.getElementById('me-figures');
  if (!host) return;
  for (const f of SC.figures || []) {
    const fig = el('figure', 'me-fig', `<p class="me-q">${esc(f.question)}</p><p class="me-a">${esc(f.answer)}</p>`);
    fig.dataset.kind = f.kind;
    if (f.kind === 'still') fig.append(stillOf(f));
    else if (f.kind === 'flow') {
      const ol = el('ol', 'me-flow'); ol.style.setProperty('--n', f.steps.length);
      f.steps.forEach((s, n) => { const li = el('li', 'me-step'), chip = el('div', 'me-chip'); chip.append(pictureOf(s.target, s.state)); li.append(chip, el('p', '', `<span class="me-sn">${n + 1}</span><span>${esc(s.text)}</span>`)); ol.append(li); });
      fig.append(ol);
    } else if (f.kind === 'compare') {
      const box = el('div', 'me-compare');
      for (const s of f.sides) { const side = el('div', 'me-side', `<h4>${esc(s.title)}</h4>`), chip = el('div', 'me-chip'); chip.append(pictureOf(s.target, s.state)); side.append(chip, el('ul', '', s.points.map(p => `<li>${esc(p)}</li>`).join(''))); box.append(side); }
      fig.append(box);
    } else {
      fig.append(el('div', 'me-table', `<table><thead><tr>${f.columns.map(c => `<th>${esc(c)}</th>`).join('')}</tr></thead><tbody>${f.rows.map(r => `<tr>${r.map(c => `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</tbody></table>`));
    }
    host.append(fig);
  }
}

function fit() {
  k = mx.clientWidth / W; cv.style.transform = `scale(${k})`;
  for (const s of STILLS) s.firstChild.style.transform = `scale(${s.clientWidth / W})`;
}
addEventListener('resize', fit);
fit();
figures();
fit();
window.MX = { END, SCENE_T, steps: CH.map(({ name, t, end }) => ({ name, t, end })), seek, now: () => T, playing: () => playing, play: () => { if (!playing) toggle(); }, pause: () => setPlaying(false) };
if (typeof window.SHOT_T === 'number') seek(window.SHOT_T + 1, false);
else { seek(0, false); later(600, () => seek(0, true)); }
})();
