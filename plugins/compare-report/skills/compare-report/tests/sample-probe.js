// The probe the tests add to the sample report built by sample_report.py. It acts as a reader would
// at the window's width, measures what the browser drew, and writes it as JSON into a pre element
// with the id probe, at the end of the body.
// The query string names what to do: wide, narrow, load (opened with #item-<key>), full (opened with
// #item-<key>/full), contents (opened with a section's fragment), and facts (the facts alone).
(async function () {
  const mode = new URLSearchParams(location.search).get("probe") || "wide";
  const out = { mode: mode, width: innerWidth };
  const tick = (ms) => new Promise((done) => setTimeout(done, ms || 80));
  const $ = (s, root) => (root || document).querySelector(s);
  const $$ = (s, root) => Array.from((root || document).querySelectorAll(s));
  const css = (el, p) => getComputedStyle(el).getPropertyValue(p);
  const shown = (el) => !!el && el.getClientRects().length > 0 && css(el, "visibility") !== "hidden";
  const box = (el) => el.getBoundingClientRect();
  const txt = (el) => (el ? el.textContent.replace(/\s+/g, " ").trim() : "");
  const own = (el) => { const c = el.cloneNode(true); c.querySelectorAll("svg, [aria-hidden='true']").forEach((x) => x.remove()); return txt(c); };
  const named = (el) => (el ? el.getAttribute("aria-label") || own(el) : "");
  const japanese = (s) => /[぀-ヿ㐀-鿿]/.test(s || "");
  const rgb = (c) => { const m = /rgba?\(([^)]+)\)/.exec(c || ""); if (!m) return null; const p = m[1].split(/[\s,/]+/).filter(Boolean).map(Number); return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 }; };
  const lum = (c) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
  const blend = (top, base) => ({ r: top.r * top.a + base.r * (1 - top.a), g: top.g * top.a + base.g * (1 - top.a), b: top.b * top.a + base.b * (1 - top.a), a: 1 });
  const ground = (el) => {
    const layers = [];
    for (let e = el; e; e = e.parentElement) { const c = rgb(css(e, "background-color")); if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; } }
    let base = { r: 255, g: 255, b: 255, a: 1 };
    for (let i = layers.length - 1; i >= 0; i -= 1) base = blend(layers[i], base);
    return base;
  };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const lineCount = (el) => {
    const tops = [];
    const walk = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    for (let node = walk.nextNode(); node; node = walk.nextNode()) {
      if (!node.textContent.trim()) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const rect of range.getClientRects()) if (rect.width > 0) tops.push(rect.top);
    }
    tops.sort((a, b) => a - b);
    let count = 0, last = -1e9;
    for (const top of tops) if (top - last > 4) { count += 1; last = top; }
    return count;
  };
  const press = async (el, ms) => { if (el) { el.click(); await tick(ms); } return !!el; };
  const theme = async (m) => { document.documentElement.dataset.theme = m; await tick(40); };
  // The color a CSS value resolves to, through an element that takes it as its color.
  const resolve = (value) => { const s = document.createElement("span"); s.style.color = value; document.body.appendChild(s); const c = css(s, "color"); s.remove(); return c; };
  // Every style rule of the page, with the rules inside @media blocks, as [media, rule] pairs.
  const rules = () => {
    const found = [];
    const walk = (list, media) => { for (const r of Array.from(list || [])) {
      if (r.cssRules && r.media) walk(r.cssRules, r.media.mediaText);
      else if (r.cssRules && !r.selectorText) walk(r.cssRules, media);
      else if (r.selectorText) found.push([media, r]); } };
    for (const s of Array.from(document.styleSheets)) { try { walk(s.cssRules, ""); } catch (e) { /* a sheet from another origin */ } }
    return found;
  };
  // Lays the page out as printed: the @media rules for print apply on screen and those for screen do
  // not, by swapping the two words in every media list. The returned function swaps them back.
  const printLike = async () => {
    const lists = [];
    const walk = (list) => { for (const r of Array.from(list || [])) { if (r.media && r.cssRules) { lists.push(r.media); walk(r.cssRules); } else if (r.cssRules) walk(r.cssRules); } };
    for (const s of Array.from(document.styleSheets)) { try { walk(s.cssRules); } catch (e) { /* a sheet from another origin */ } }
    const swap = () => lists.forEach((m) => { m.mediaText = m.mediaText.replace(/\b(print|screen)\b/g, (w) => (w === "print" ? "screen" : "print")); });
    swap();
    await tick(60);
    return async () => { swap(); await tick(60); };
  };

  await tick(300);
  const cards = $$("#candidates .card");
  const names = cards.map((c) => txt($("h3", c)));
  const keyOf = (name) => { const c = cards.find((x) => txt($("h3", x)) === name); return c ? c.getAttribute("data-candidate") : null; };
  const split = $("#candidates .split");
  const list = split ? $(".list", split) : null;
  const detail = split ? $(".detail", split) : null;
  const entries = () => (list ? $$("li", list) : []);
  const entryButtons = () => entries().map((li) => $$("button", li)[0]).filter(Boolean);
  const title = () => $("#detail-title");
  const backButton = () => (detail ? $(".back", detail) : null);
  const fullButton = () => (detail ? $$("button", detail).find((b) => named(b) === "Open full page") : null);
  const axisNames = $$("section.axis > h2").map(txt);
  const reportTables = () => $$("main table").filter((t) => shown(t) && !t.classList.contains("facts"));
  out.cards = { names: names, keys: cards.map((c) => c.getAttribute("data-candidate")) };
  out.hasSplit = !!split && !!list && !!detail;
  out.titleSize = $(".cover h1") ? parseFloat(css($(".cover h1"), "font-size")) : 0;
  out.hscroll = document.documentElement.scrollWidth > document.documentElement.clientWidth + 1;

  const factsInfo = () => {
    const f = $(".cover table.facts");
    if (!f) return null;
    const h1 = $(".cover h1");
    return {
      afterTitle: !!h1 && !!(h1.compareDocumentPosition(f) & Node.DOCUMENT_POSITION_FOLLOWING),
      caption: !!$(":scope > caption", f),
      rows: $$("tr", f).map((tr) => ({ label: txt($("th", tr)), scope: $("th", tr) ? $("th", tr).getAttribute("scope") : null,
        value: txt($("td", tr)), shown: shown(tr), time: $("time", tr) ? $("time", tr).getAttribute("datetime") : null })),
      band: !!$(".cover .stats, .cover dl"),
    };
  };

  if (mode === "facts") {
    out.facts = factsInfo();
  }

  if (mode === "load" || mode === "full") {
    const main = $("main");
    out.load = { title: txt(title()), current: entryButtons().filter((b) => b.getAttribute("aria-current") === "true").map(named), hash: location.hash,
      listShown: shown(list), detailShown: shown(detail), detailWidth: detail ? box(detail).width : 0,
      mainWidth: main.clientWidth - parseFloat(css(main, "padding-left")) - parseFloat(css(main, "padding-right")) };
  }

  if (mode === "contents") {
    // Press the contents link of the second axis and see whether its heading is in view and on top.
    const link = $(".toc a[href='#axis-maintenance']"), h = $("#axis-maintenance > h2");
    await press(link, 400);
    if (h) {
      const r = box(h), hit = document.elementFromPoint(r.left + Math.min(20, r.width / 2), r.top + r.height / 2);
      out.contents = { link: !!link, top: r.top, bottom: r.bottom, height: innerHeight, scrollY: scrollY, onTop: !!hit && (hit === h || h.contains(hit)) };
    }
  }

  if (mode === "wide") {
    out.split = split ? {
      detailTag: detail ? detail.tagName : null, labelledby: detail ? detail.getAttribute("aria-labelledby") : null,
      modal: !!detail && (!!detail.closest("dialog") || detail.getAttribute("role") === "dialog" || detail.hasAttribute("aria-modal")),
      title: title() ? { tag: title().tagName, tabindex: title().getAttribute("tabindex"), text: txt(title()), inDetail: !!detail && detail.contains(title()) } : null,
      listShown: shown(list), detailShown: shown(detail), listWidth: list ? box(list).width : 0, listRight: list ? box(list).right : 0,
      detailLeft: detail ? box(detail).left : 0, detailWidth: detail ? box(detail).width : 0, splitWidth: box(split).width,
      gap: parseFloat(css(split, "column-gap")) || 0,
    } : null;
    out.entries = entries().map((li) => {
      const buttons = $$("button", li), b = buttons[0], last = b ? b.lastElementChild : null;
      return { buttons: buttons.length, name: b ? named(b) : "", current: b ? b.getAttribute("aria-current") : null,
        chevron: !!last && last.tagName.toLowerCase() === "svg" && last.getAttribute("aria-hidden") === "true" };
    });
    out.marks = entryButtons().map((b) => { const li = b.closest("li"), els = [b, li];
      return { bg: els.map((e) => css(e, "background-color")).join(" "), edge: Math.max(...els.map((e) => parseFloat(css(e, "border-left-width")) || 0)),
        shadow: els.map((e) => css(e, "box-shadow")).join(" ") }; });

    // What the details hold for the first candidate, as the place of each part among the shown elements.
    const parts = (name) => {
      const card = cards.find((c) => txt($("h3", c)) === name);
      if (!detail || !card) return null;
      const summary = txt($(".summary", card)), description = txt(card.querySelector(":scope > p:last-of-type"));
      const fields = $$("dt", card).map((dt) => [txt(dt), txt(dt.nextElementSibling)]);
      const risks = $$("#risks tbody tr[data-candidate='" + card.getAttribute("data-candidate") + "']").map((tr) => txt(tr.children[1]));
      const els = $$("*", detail).filter(shown);
      const at = (test) => els.findIndex(test);
      return {
        title: at((e) => e === title()),
        summary: at((e) => e.tagName === "P" && txt(e) === summary),
        fields: at((e) => e.tagName === "TABLE" && fields.length > 0 && fields.every(([l, v]) => $$("tr", e).some((tr) => txt($("th", tr)) === l && txt($("td", tr)) === v))),
        description: at((e) => e.tagName === "P" && txt(e) === description),
        scores: at((e) => e.tagName === "TABLE" && axisNames.every((a) => $$("tbody tr", e).some((tr) => txt(tr.firstElementChild) === a))),
        risks: at((e) => e.tagName === "TABLE" && risks.length > 0 && risks.every((r) => txt(e).includes(r))),
      };
    };
    out.parts = parts(names[0]);
    out.current = entryButtons().filter((b) => b.getAttribute("aria-current") === "true").map(named);
    out.firstTitle = txt(title());

    out.scroll = split ? {
      list: list ? { position: css(list, "position"), y: css(list, "overflow-y"), x: css(list, "overflow-x"), max: css(list, "max-height") } : null,
      detail: detail ? { position: css(detail, "position"), y: css(detail, "overflow-y"), x: css(detail, "overflow-x"), max: css(detail, "max-height") } : null,
      titleSticky: (() => { if (!detail || !title()) return null; for (let e = title(); e && e !== detail; e = e.parentElement) if (css(e, "position") === "sticky") return { top: css(e, "top") }; return null; })(),
    } : null;

    // The scores the details show for each candidate, against the candidate's row in each axis table.
    const want = (name) => $$("section.axis").map((sec) => { const tr = $("tbody tr[data-candidate='" + keyOf(name) + "']", sec);
      return tr ? { axis: txt($("h2", sec)), score: txt(tr.querySelector("td.center")), why: txt(tr.querySelector("td.rationale")) } : null; }).filter(Boolean);
    const got = () => { const t = detail ? $$("table", detail).find((e) => axisNames.some((a) => $$("tbody tr", e).some((tr) => txt(tr.firstElementChild) === a))) : null;
      return t ? $$("tbody tr", t).map((tr) => { const c = Array.from(tr.children); return { axis: txt(c[0]), score: txt(c[1]), why: txt(c[c.length - 1]) }; }) : []; };
    out.scores = [];
    for (const b of entryButtons()) {
      const name = named(b);
      await press(b, 120);
      out.scores.push({ name: name, title: txt(title()), hash: location.hash, want: want(name), got: got(),
        current: entryButtons().filter((x) => x.getAttribute("aria-current") === "true").map(named) });
    }
    await press(entryButtons()[0], 120);

    // Open full page, and back from it.
    const main = $("main");
    const fb = fullButton();
    out.full = null;
    if (fb) {
      await press(fb, 150);
      out.full = { hash: location.hash, listShown: shown(list), detailWidth: box(detail).width, back: shown(backButton()),
        mainWidth: main.clientWidth - parseFloat(css(main, "padding-left")) - parseFloat(css(main, "padding-right")) };
      await press(backButton(), 150);
      out.full.after = { hash: location.hash, listShown: shown(list), detailShown: shown(detail) };
    }

    // The tables.
    out.tables = reportTables().map((t) => {
      const heads = $$(":scope > thead th", t), rows = $$(":scope > tbody > tr", t), lab = t.getAttribute("aria-labelledby");
      return { name: txt($(":scope > caption", t)) || (lab ? txt(document.getElementById(lab)) : ""), cols: heads.length,
        scopes: heads.map((h) => h.getAttribute("scope")),
        rowHeads: rows.map((tr) => tr.firstElementChild.tagName === "TH" && tr.firstElementChild.getAttribute("scope") === "row"),
        headLine: heads.length ? css(heads[0], "border-bottom-width") : "", scrolls: t.parentElement.scrollWidth > t.parentElement.clientWidth + 1 };
    });
    out.lines = {};
    out.facts = factsInfo();
    // The facts labels against their own ground, and whether that ground is the --label or --cover-label token.
    const factsColor = (token) => {
      const f = $(".cover table.facts");
      if (!f) return null;
      const th = $("th", f), td = $("td", f), g = ground(th);
      return { label: ratio(blend(rgb(css(th, "color")), g), g), own: !same(g, ground(td)),
        token: [token("--label"), token("--cover-label")].filter(Boolean).some((t) => same(rgb(t), rgb(css(th, "background-color")))) };
    };
    out.factsColor = {};
    out.colors = {};
    for (const m of ["light", "dark"]) {
      await theme(m);
      out.lines[m] = reportTables().map((t) => {
        const rows = $$(":scope > tbody > tr", t), cell = (tr) => tr.children[1] || tr.firstElementChild;
        const lines = rows.slice(0, -1).map((tr) => { const c = rgb(css(cell(tr), "border-bottom-color")), g = ground(cell(tr)); return c ? ratio(blend(c, g), g) : 0; });
        return { name: txt($(":scope > caption", t)), cols: $$(":scope > thead th", t).length, rows: rows.length,
          scrolls: t.parentElement.scrollWidth > t.parentElement.clientWidth + 1,
          striped: rows.length > 1 && !same(ground(cell(rows[0])), ground(cell(rows[1]))), minLine: lines.length ? Math.min(...lines) : 0 };
      });
      const root = getComputedStyle(document.documentElement);
      const token = (k) => { const v = root.getPropertyValue(k).trim(); return v ? resolve(v) : ""; };
      out.factsColor[m] = factsColor(token);
      const sample = (cls) => { const s = document.createElement("span"); s.className = cls; s.textContent = "X"; $("main").appendChild(s);
        const v = { color: css(s, "color"), bg: css(s, "background-color") }; s.remove(); return v; };
      out.colors[m] = { accent: token("--accent"), accentSoft: token("--accent-soft"),
        status: ["--good", "--good-soft", "--warn", "--warn-soft", "--critical", "--critical-soft"].map(token),
        tags: ["t1", "t2", "t3", "t4", "t5"].map((t) => sample("tag " + t)), s: sample("score s") };
    }
    await theme("light");

    // The facts and the long table as printed.
    const unprint = await printLike();
    { const root = getComputedStyle(document.documentElement);
      out.factsColor.print = factsColor((k) => { const v = root.getPropertyValue(k).trim(); return v ? resolve(v) : ""; }); }
    const printedLong = reportTables().find((t) => $$(":scope > tbody > tr", t).length >= 30);
    out.longPrint = printedLong ? { boxHeight: printedLong.parentElement.clientHeight, scrollHeight: printedLong.parentElement.scrollHeight,
      tableHeight: box(printedLong).height, overflowY: css(printedLong.parentElement, "overflow-y") } : null;
    out.splitPrint = split ? { split: shown(split), cards: shown($("#candidates .cards")) } : { split: false, cards: shown($("#candidates .cards")) };
    await unprint();

    // The grid of the candidate cards as the stylesheet writes it.
    out.gridRules = rules().filter(([, r]) => /\.cards\b/.test(r.selectorText) && r.style.gridTemplateColumns).map(([m, r]) => ({ media: m, columns: r.style.gridTemplateColumns }));

    out.risks = $$("#risks .risk").map((r) => { const first = r.firstElementChild, nodes = Array.from(r.childNodes);
      const isIcon = !!first && first.tagName.toLowerCase() === "svg";
      return { level: Array.from(r.classList).filter((c) => c !== "risk").join(" "), icon: isIcon && first.getAttribute("aria-hidden") === "true"
        && nodes.slice(0, nodes.indexOf(first)).every((n) => !n.textContent.trim()), svg: isIcon ? first.innerHTML : "", text: own(r) }; });
    out.caution = $$("main .caution").filter((c) => !(detail && detail.contains(c))).map((c) => ({ icon: !!$("svg[aria-hidden='true']", c), h3: txt($("h3", c)), role: c.getAttribute("role") }));
    out.dateCount = (document.body.innerText.match(/2026-11-10/g) || []).length;

    const ul = $("#candidates .cards");
    if (ul) {
      const was = ul.style.display;
      ul.style.display = "grid";
      await tick(20);
      out.grid = { tag: ul.tagName, items: Array.from(ul.children).map((li) => li.tagName), columns: css(ul, "grid-template-columns"),
        widths: Array.from(ul.children).map((li) => box(li).width), width: box(ul).width, gap: parseFloat(css(ul, "column-gap")) || 0 };
      ul.style.display = was;
    }
    const picks = $("#summary .picks");
    out.picks = picks ? { tag: picks.tagName, items: Array.from(picks.children).map((x) => x.tagName) } : null;

    const chart = $(".bars");
    out.bars = chart ? {
      values: $$(".value", chart).map((v) => ({ text: txt(v), right: box(v).right, align: css(v, "text-align") })),
      labels: $$(".label", chart).map((l) => ({ text: txt(l), cut: css(l, "text-overflow") === "ellipsis" || l.scrollWidth > l.clientWidth + 1, lines: lineCount(l) })),
    } : null;
    const ct = $("#candidates table");
    out.contentWidth = ct ? { table: box(ct).width, wrap: box(ct.parentElement).width } : null;

    const longTable = reportTables().find((t) => $$(":scope > tbody > tr", t).length >= 30);
    out.long = null;
    if (longTable) {
      const w = longTable.parentElement, th = $("thead th", longTable);
      out.long = { boxHeight: w.clientHeight, tableHeight: box(longTable).height };
      w.scrollTop = 400;
      await tick(40);
      out.long.scrolled = w.scrollTop;
      out.long.headGap = box(th).top - box(w).top - (parseFloat(css(w, "border-top-width")) || 0);
      w.scrollTop = 0;
    }

    // A chart opens larger when pressed, and closing it gives focus back.
    out.zoom = null;
    if (chart) {
      chart.focus();
      await press(chart, 150);
      const dlg = $("dialog[open]"), close = dlg ? $$("button", dlg).find(shown) : null;
      out.zoom = { open: !!dlg, modal: !!dlg && dlg.matches(":modal"), holds: !!dlg && !!$(".bars, svg", dlg),
        close: close ? { icon: !!$("svg", close), label: close.getAttribute("aria-label") || "", text: own(close) } : null };
      await press(close, 150);
      const a = document.activeElement;
      out.zoom.closed = !$("dialog[open]");
      out.zoom.back = !!a && (a === chart || chart.contains(a) || a.contains(chart));
    }

    // The language switch: the frame's words change and the report's text stays.
    const before = { summary: txt($("#summary > p")), heading: txt($("#candidates > h2")), description: txt(cards[0] ? cards[0].querySelector(":scope > p:last-of-type") : null) };
    const backRef = backButton(), fullRef = fullButton();
    const frame = () => ({ facts: $$(".cover table.facts th").map(txt), contents: txt($(".toc h2")), back: backRef ? own(backRef) : "",
      full: fullRef ? named(fullRef) : "", legend: $$(".legend [data-t]").map(txt), chart: chart ? chart.getAttribute("aria-label") || "" : "" });
    out.lang = { en: frame() };
    await press($("[data-lang='ja']"), 120);
    out.lang.ja = frame();
    if (chart) {
      await press(chart, 150);
      const dlg = $("dialog[open]"), close = dlg ? $$("button", dlg).find(shown) : null;
      out.lang.ja.close = close ? close.getAttribute("aria-label") || "" : "";
      await press(close, 150);
    }
    out.lang.after = { summary: txt($("#summary > p")), heading: txt($("#candidates > h2")), description: txt(cards[0] ? cards[0].querySelector(":scope > p:last-of-type") : null) };
    out.lang.before = before;
    out.lang.japanese = Object.fromEntries(Object.entries(out.lang.ja).map(([k, v]) => [k, Array.isArray(v) ? v.length > 0 && v.every(japanese) : japanese(v)]));
    out.lang.keys = typeof TEXT === "undefined" ? null : { en: Object.keys(TEXT.en).sort(), ja: Object.keys(TEXT.ja).sort() };
    await press($("[data-lang='en']"), 80);
  }

  if (mode === "narrow") {
    const both = () => shown(list) && shown(detail);
    let together = !!split && both();
    out.narrow = { start: { list: shown(list), detail: shown(detail) } };
    const first = entryButtons()[0];
    await press(first, 150);
    together = together || both();
    const back = backButton();
    const shownEls = detail ? $$("*", detail).filter(shown) : [];
    out.narrow.open = { list: shown(list), detail: shown(detail), focus: !!title() && document.activeElement === title(), title: txt(title()), hash: location.hash,
      back: back ? { shown: shown(back), first: shownEls[0] === back || (!!shownEls[0] && shownEls[0].contains(back)), text: own(back) } : null,
      prev: detail ? shown($("a[rel='prev']", detail)) : false, next: detail ? shown($("a[rel='next']", detail)) : false };
    await press(detail ? $("a[rel='next']", detail) : null, 150);
    together = together || both();
    out.narrow.next = { title: txt(title()), focus: !!title() && document.activeElement === title(),
      prev: detail ? shown($("a[rel='prev']", detail)) : false, next: detail ? shown($("a[rel='next']", detail)) : false };
    const shownName = txt(title());
    await press(backButton(), 200);
    together = together || both();
    const a = document.activeElement;
    out.narrow.back = { list: shown(list), detail: shown(detail), focus: a && a.tagName === "BUTTON" ? named(a) : (a ? a.tagName : ""), shownName: shownName };
    out.narrow.together = together;
    out.hscroll = document.documentElement.scrollWidth > document.documentElement.clientWidth + 1;

    const sc = reportTables().find((t) => $$(":scope > thead th", t).length >= 7);
    out.region = null;
    if (sc) {
      const w = sc.parentElement, lab = w.getAttribute("aria-labelledby"), th = $(":scope > tbody > tr > th", sc);
      w.scrollLeft = 0;
      await tick(60);
      const start = { shadow: css(w, "box-shadow"), image: css(w, "background-image") };
      w.focus();
      await tick(30);
      const ring = { outline: css(w, "outline-style"), width: parseFloat(css(w, "outline-width")) || 0, shadow: css(w, "box-shadow"), focused: document.activeElement === w };
      w.blur();
      w.scrollLeft = w.scrollWidth;
      await tick(60);
      const end = { shadow: css(w, "box-shadow"), image: css(w, "background-image") };
      out.region = { role: w.getAttribute("role"), tabindex: w.getAttribute("tabindex"), labelledby: lab, label: lab && document.getElementById(lab) ? txt(document.getElementById(lab)) : "",
        caption: txt($(":scope > caption", sc)), scrolls: w.scrollWidth > w.clientWidth + 1, start: start, end: end, ring: ring,
        sticky: th ? { position: css(th, "position"), gap: box(th).left - box(w).left - (parseFloat(css(w, "border-left-width")) || 0) } : null };
      w.scrollLeft = 0;
    }
  }

  const pre = document.createElement("pre");
  pre.id = "probe";
  pre.hidden = true;
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
})();
