"""Writes the state an eval case starts from into the current folder.

Every case documents tiny-slug, a small Node.js library written here. Cases that need laid-out docs
build them with this plugin's own docs_publish.py, so the fixtures follow the script when it changes.
The Japanese translations come from _japanese.json, the one fixture file that holds Japanese text.

Usage: python3 _fixture.py project | laid-out | translate-ready | check-and-fix
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "skills", "docs-publish", "scripts", "docs_publish.py")
JAPANESE = "日本語"
TODO = "<!-- docs-publish:todo"

PROJECT = {
    "package.json": json.dumps({
        "name": "tiny-slug", "version": "1.2.0", "description": "Turn text into URL slugs and back",
        "main": "index.js", "license": "MIT", "engines": {"node": ">=18"}, "scripts": {"test": "node test.js"},
    }, indent=2) + "\n",
    "index.js": """'use strict';

/**
 * Turns text into a URL slug.
 * @param {string} text The text to turn into a slug.
 * @param {{separator?: string, lower?: boolean}} [options]
 * @returns {string} The slug, or '' when the text has no ASCII letters or digits.
 * @throws {TypeError} When text is not a string.
 */
function slugify(text, options = {}) {
  if (typeof text !== 'string') {
    throw new TypeError('slugify expects a string');
  }
  const { separator = '-', lower = true } = options;
  const words = text.normalize('NFKD').replace(/[\\u0300-\\u036f]/g, '').match(/[A-Za-z0-9]+/g) || [];
  const slug = words.join(separator);
  return lower ? slug.toLowerCase() : slug;
}

/**
 * Turns a slug back into words separated by spaces.
 * @param {string} slug The slug.
 * @param {{separator?: string}} [options]
 * @returns {string}
 * @throws {TypeError} When slug is not a string.
 */
function unslug(slug, options = {}) {
  if (typeof slug !== 'string') {
    throw new TypeError('unslug expects a string');
  }
  const { separator = '-' } = options;
  return slug.split(separator).filter(Boolean).join(' ');
}

module.exports = { slugify, unslug };
""",
    "test.js": """'use strict';
const assert = require('node:assert');
const { slugify, unslug } = require('./index.js');

assert.strictEqual(slugify('Hello World'), 'hello-world');
assert.strictEqual(slugify('Hello World', { separator: '_', lower: false }), 'Hello_World');
assert.strictEqual(unslug('hello-world'), 'hello world');
assert.throws(() => slugify(42), TypeError);
console.log('ok');
""",
    "README.md": """# tiny-slug

Turn text into URL slugs and back.
Both functions recieve a string and return a string.

```js
const { slugify } = require('tiny-slug');

slugify('Hello World'); // 'hello-world'
```
""",
}

PLAN = {
    "project": "tiny-slug",
    "languages": [{"code": "en", "name": "English"}, {"code": "ja", "name": JAPANESE}],
    "concepts": [{"slug": "slugs", "title": "Slugs"}],
    "api": [{"slug": "slugify", "title": "slugify"}, {"slug": "unslug", "title": "unslug"}],
    "cookbook": [{"slug": "make-url-slugs", "title": "Make URL slugs"}],
}

# What replaces each to-do note of an English page, in the order the notes appear.
PAGES = {
    "README.md": ["tiny-slug turns text into URL slugs and back, for Node.js apps that build links from titles."],
    "quickstart.md": [
        "At the end, tiny-slug turns a title into a URL slug, in about five minutes.",
        "- Node.js 18 or later",
        "```bash\nnpm install tiny-slug\n```",
        "Save this as `slug.js`.\n\n```js\nconst { slugify } = require('tiny-slug');\n\n"
        "console.log(slugify('Hello World'));\n```\n\nRun it.\n\n```bash\nnode slug.js\n```\n\n"
        "It prints the slug.\n\n```text\nhello-world\n```",
    ],
    "concepts/README.md": ["Read the Slugs page first."],
    "concepts/slugs.md": [
        "A slug is the part of a URL that names a page in words, such as `hello-world`.",
        "Titles hold spaces, capitals, and accents that do not belong in a URL.",
        "```mermaid\nflowchart LR\n  A[Title] --> B[Strip accents] --> C[Keep ASCII letters and digits] --> D[Join] --> E[Slug]\n"
        "```\n\n`slugify` keeps the runs of ASCII letters and digits and joins them with the separator.",
        "```js\nconst { slugify } = require('tiny-slug');\n\nslugify('Hello World Again'); // 'hello-world-again'\n```",
        "- [slugify](../api/slugify.md)\n- [unslug](../api/unslug.md)",
    ],
    "api/README.md": ["Each page covers one function."],
    "api/slugify.md": [
        "Turns text into a URL slug. Use `unslug` to turn a slug back into words.",
        "```js\nslugify(text, options)\n```",
        "| Name | Type | Required | Default | Description |\n|---|---|---|---|---|\n"
        "| `text` | string | Yes | | The text to turn into a slug |\n"
        "| `options.separator` | string | No | `'-'` | Joins the words |\n"
        "| `options.lower` | boolean | No | `true` | Turns the slug into lowercase |",
        "The slug, as a string. An empty string when the text has no ASCII letters or digits.",
        "Throws `TypeError: slugify expects a string` when `text` is not a string.",
        "```js\nconst { slugify } = require('tiny-slug');\n\n"
        "console.log(slugify('Hello World', { separator: '_' })); // hello_world\n```",
        "- [unslug](unslug.md)\n- [Make URL slugs](../cookbook/make-url-slugs.md)",
    ],
    "api/unslug.md": [
        "Turns a slug back into words separated by spaces.",
        "```js\nunslug(slug, options)\n```",
        "| Name | Type | Required | Default | Description |\n|---|---|---|---|---|\n"
        "| `slug` | string | Yes | | The slug |\n"
        "| `options.separator` | string | No | `'-'` | Splits the words |",
        "The words, as a string.",
        "Throws `TypeError: unslug expects a string` when `slug` is not a string.",
        "```js\nconst { unslug } = require('tiny-slug');\n\nconsole.log(unslug('hello-world')); // hello world\n```",
        "- [slugify](slugify.md)",
    ],
    "cookbook/README.md": ["Each recipe is one task."],
    "cookbook/make-url-slugs.md": [
        "Give each blog post a URL slug made from its title.",
        "Install tiny-slug as the [Quickstart](../quickstart.md) shows.",
        "1. Save this as `posts.js`.\n\n```js\nconst { slugify } = require('tiny-slug');\n\n"
        "for (const title of ['First Post', 'Second Post']) {\n  console.log(slugify(title));\n}\n```",
        "```bash\nnode posts.js\n```\n\nIt prints one slug per line.\n\n```text\nfirst-post\nsecond-post\n```",
        "- [slugify](../api/slugify.md)",
    ],
    "faq.md": [
        "## Why is my slug empty?\n\n`slugify` keeps only ASCII letters and digits, so text without any, such as "
        "Japanese text, gives an empty string. See [slugify](api/slugify.md).\n\n## Where do I start?\n\nFollow the [Quickstart](quickstart.md).",
    ],
}


def write(path, text):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def run(*args, stdin=None):
    subprocess.run([sys.executable, SCRIPT, *args], input=stdin, text=True, check=True,
                   stdout=subprocess.DEVNULL)


def fill(page):
    """Replaces the to-do notes of docs/en/<page> with the text PAGES holds for it."""
    path = os.path.join("docs", "en", page)
    texts = iter(PAGES[page])
    lines = [next(texts) if line.startswith(TODO) else line for line in read(path).splitlines()]
    write(path, "\n".join(lines) + "\n")


def translate(page):
    """Writes docs/ja/<page> in Japanese from the English starter page, before fill() replaces its to-do
    notes: the title, headings, and link labels from _japanese.json, each to-do note replaced by the
    Japanese text of the same part, and the code blocks and tables kept in the same order."""
    with open(os.path.join(HERE, "_japanese.json"), encoding="utf-8") as f:
        ja_text = json.load(f)
    en = read(os.path.join("docs", "en", page)).splitlines()
    ja_path = os.path.join("docs", "ja", page)
    lines = ["# " + ja_text["titles"][page]] + read(ja_path).splitlines()[1:3]
    texts = iter(ja_text["pages"][page])
    for line in en[3:]:
        if line.startswith(TODO):
            line = next(texts)
        elif line.startswith("#"):
            marks, heading = line.split(" ", 1)
            line = marks + " " + ja_text["headings"][heading]
        for label, japanese in ja_text["labels"].items():
            line = line.replace(label + "(", japanese + "(")
        lines.append(line)
    write(ja_path, "\n".join(lines) + "\n")


def main(mode):
    for name, text in PROJECT.items():
        write(name, text)
    if mode == "project":
        return
    run("scaffold", "-", stdin=json.dumps(PLAN))
    if mode == "laid-out":
        return
    if mode == "translate-ready":
        fill("quickstart.md")
        return
    if mode != "check-and-fix":
        sys.exit("unknown mode: %s" % mode)
    for page in PAGES:
        translate(page)
        fill(page)
    run("translated", *PAGES)
    # The two problems the case leaves for the agent: a broken link in a translation, and a source page
    # that changed after its translation was recorded. The added sentence is true of the code, so the
    # fix is to carry it into the translation, not to correct the English page.
    faq = os.path.join("docs", "ja", "faq.md")
    write(faq, read(faq).replace("(quickstart.md)", "(quick-start.md)"))
    slugs = os.path.join("docs", "en", "concepts", "slugs.md")
    write(slugs, read(slugs).replace("do not belong in a URL.",
                                     "do not belong in a URL. By default, the slug is all lowercase."))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
