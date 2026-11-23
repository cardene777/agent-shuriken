/**
 * The parts on an app's screen, read from the list each system gives, as one list a flow's targets
 * are looked up in.
 *
 * | System | List read | Coordinates of `frame` |
 * |---|---|---|
 * | `mac` | the Swift tool's accessibility list (`screen-video-mac parts`) | points from the top left of the app's window |
 * | `ios` | `idb ui describe-all --json` | points of the simulator's screen |
 * | `android` | `uiautomator dump` | pixels of the emulator's screen |
 *
 * Each part is `{ role, name, value, id, enabled, secure, frame }`: `role` is a web role (`button`,
 * `textbox`, `text`, `switch`, ...), `name` what the part is called (its label, title, or text),
 * `value` what it holds, `id` its accessibility identifier or resource id, `secure` whether it hides
 * what is typed, and `frame` `[x, y, width, height]`.
 *
 * | Function | What it does |
 * |---|---|
 * | `readParts` | The parts of a system's list |
 * | `findPart` | The part a target names, or undefined |
 * | `partsHolding` | The parts whose name or value holds a text |
 */

const MAC_ROLES = {
  AXButton: "button",
  AXMenuButton: "button",
  AXTextField: "textbox",
  AXTextArea: "textbox",
  AXComboBox: "combobox",
  AXPopUpButton: "combobox",
  AXStaticText: "text",
  AXHeading: "heading",
  AXCheckBox: "checkbox",
  AXRadioButton: "radio",
  AXLink: "link",
  AXImage: "img",
  AXSlider: "slider",
  AXMenuItem: "menuitem",
  AXMenuBarItem: "menuitem",
  AXTabGroup: "tablist",
  AXCell: "cell",
  AXRow: "row",
  AXTable: "table",
  AXOutline: "tree",
  AXList: "list",
  AXGroup: "group",
  AXScrollArea: "group",
  AXToolbar: "toolbar",
  AXWindow: "window",
};
const MAC_SUBROLES = { AXSwitch: "switch", AXSearchField: "searchbox", AXSecureTextField: "textbox", AXTabButton: "tab" };

const IOS_ROLES = {
  Application: "application",
  Window: "window",
  Button: "button",
  Link: "link",
  TextField: "textbox",
  SecureTextField: "textbox",
  TextView: "textbox",
  SearchField: "searchbox",
  StaticText: "text",
  Heading: "heading",
  Header: "heading",
  Switch: "switch",
  Toggle: "switch",
  Image: "img",
  Cell: "cell",
  Slider: "slider",
  Tab: "tab",
  TabBar: "tablist",
  Table: "table",
  CollectionView: "list",
  Picker: "combobox",
  Group: "group",
  Other: "group",
};

const ANDROID_ROLES = [
  [/(^|\.)RadioButton$/, "radio"],
  [/(^|\.)(Switch|SwitchCompat|SwitchMaterial|MaterialSwitch)$/, "switch"],
  [/(^|\.)(CheckBox|MaterialCheckBox)$/, "checkbox"],
  [/(^|\.)(ToggleButton)$/, "switch"],
  [/Button$/, "button"],
  [/(^|\.)(EditText|AutoCompleteTextView|TextInputEditText|MultiAutoCompleteTextView)$/, "textbox"],
  [/(^|\.)(TextView|CheckedTextView)$/, "text"],
  [/(^|\.)ImageView$/, "img"],
  [/(^|\.)(SeekBar|Slider)$/, "slider"],
  [/(^|\.)Spinner$/, "combobox"],
  [/(^|\.)(RecyclerView|ListView|GridView)$/, "list"],
];

/** Roles that hold the whole screen, which a label or a text never names. */
const WHOLE = new Set(["window", "application"]);

const text = (value) => (value === null || value === undefined ? "" : String(value));
const part = ({ role, name, value, id, enabled = true, secure = false, frame }) => ({ role, name: text(name), value: text(value), id: text(id), enabled: enabled !== false, secure, frame: frame.map(Number) });

function macParts(list) {
  return list.map((item) => {
    const role = MAC_SUBROLES[item.subrole] ?? MAC_ROLES[item.role] ?? String(item.role ?? "").replace(/^AX/, "").toLowerCase();
    // A static text has no title: its text is its value
    const name = role === "text" || role === "heading" ? item.title ?? item.value : item.title ?? item.description ?? item.label;
    return part({ role, name, value: item.value, id: item.identifier, enabled: item.enabled, secure: item.subrole === "AXSecureTextField", frame: item.frame });
  });
}

function iosParts(list) {
  return list.map((item) => {
    const f = item.frame ?? {};
    const role = IOS_ROLES[item.type] ?? String(item.type ?? "group").toLowerCase();
    return part({ role, name: item.AXLabel, value: item.AXValue, id: item.AXUniqueId, enabled: item.enabled, secure: item.type === "SecureTextField", frame: [f.x ?? 0, f.y ?? 0, f.width ?? 0, f.height ?? 0] });
  });
}

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" };
const decode = (value) => value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (all, code) => (code[0] === "#" ? String.fromCodePoint(code[1] === "x" || code[1] === "X" ? parseInt(code.slice(2), 16) : Number(code.slice(1))) : ENTITIES[code] ?? all));

function androidParts(xml) {
  const parts = [];
  for (const [, body] of xml.matchAll(/<node\b([^>]*?)\/?>/g)) {
    const a = {};
    for (const [, key, value] of body.matchAll(/([\w-]+)="([^"]*)"/g)) a[key] = decode(value);
    const bounds = /^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$/.exec(a.bounds ?? "");
    if (bounds === null) continue;
    const [x1, y1, x2, y2] = bounds.slice(1).map(Number);
    const cls = a.class ?? "";
    const role = ANDROID_ROLES.find(([pattern]) => pattern.test(cls))?.[1] ?? (a.clickable === "true" ? "button" : "group");
    // A field is named by its description or its hint; its text is what it holds
    const name = a["content-desc"] || (role === "textbox" ? a.hint ?? "" : a.text ?? "");
    parts.push(part({ role, name, value: a.text, id: a["resource-id"], enabled: a.enabled !== "false", secure: a.password === "true", frame: [x1, y1, x2 - x1, y2 - y1] }));
  }
  return parts;
}

/** The parts of what `platform`'s tool printed: JSON for `mac` and `ios`, the XML of `uiautomator dump` for `android`. */
export function readParts(platform, output) {
  if (platform === "android") return androidParts(output);
  const list = JSON.parse(output);
  if (!Array.isArray(list)) throw new Error(`the ${platform} list of parts is not a list`);
  return platform === "mac" ? macParts(list) : iosParts(list);
}

const shown = (p) => p.frame[2] > 0 && p.frame[3] > 0;

/**
 * The part `target` names among the parts shown on the screen, or undefined. `role` matches the
 * role and, with `name`, the name; `label` the name; `text` the name or the value; `testId` the id,
 * or the end of a resource id (`com.example:id/save` for `save`); `nth` picks among the matches.
 * Names are compared whole unless `exact` is false. A `point` is a part of no size at that point.
 */
export function findPart(parts, target) {
  if (target.point !== undefined) return part({ role: "point", name: "", value: "", id: "", frame: [target.point[0], target.point[1], 0, 0] });
  const same = target.exact === false ? (a, b) => a.toLowerCase().includes(b.toLowerCase()) : (a, b) => a === b;
  const on = parts.filter(shown);
  let matches;
  if (target.role !== undefined) matches = on.filter((p) => p.role === target.role && (target.name === undefined || same(p.name, target.name)));
  else if (target.label !== undefined) matches = on.filter((p) => !WHOLE.has(p.role) && same(p.name, target.label));
  else if (target.text !== undefined) matches = on.filter((p) => !WHOLE.has(p.role) && (same(p.name, target.text) || same(p.value, target.text)));
  else if (target.testId !== undefined) matches = on.filter((p) => p.id === target.testId || p.id.endsWith(`:id/${target.testId}`));
  else matches = [];
  return matches[target.nth ?? 0];
}

/** The parts shown whose name or value holds `needle`. */
export function partsHolding(parts, needle) {
  return parts.filter((p) => shown(p) && !WHOLE.has(p.role) && (p.name.includes(needle) || p.value.includes(needle)));
}
