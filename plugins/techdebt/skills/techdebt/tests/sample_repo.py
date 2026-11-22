#!/usr/bin/env python3
"""Builds shop, the sample repository whose scan and report the README shows, and checks the README.

Usage:

  sample_repo.py build DIR
  sample_repo.py readme OUT [--browser PATH]
  sample_repo.py compare SCAN README...

`build` creates DIR as the git repository of a small online shop, with Python billing, inventory, and
jobs, a TypeScript API, and React pages. Its commits are dated in days before today, so that a scan
finds the same counts on any day. They use a fixed author with an example.com address, and none of
the git settings of the user.

`readme` builds the repository in OUT/profile/work/shop and scans it with techdebt.py, with HOME set to
OUT/profile so that its path reads ~/work/shop, and with PATH holding only git so that a linter installed
on this machine does not change the counts. It writes the scan to OUT/scan.txt, attaches the notes on
the top files with `explain`, and with --browser saves OUT/screenshot.png, the report opened on the
top file at 1280 by 800 pixels at twice the density.

`compare` names each line of the sample summary in each README that differs from the scan, leaving
out the short hash after HEAD, and the sentence on how far the ranking goes when its number differs.

To make the README again after the report changes:

  out="$(mktemp -d)"
  python3 sample_repo.py readme "$out" --browser "<path of Chrome or Chromium>"

Then put the lines of $out/scan.txt down to the fifth ranked file in the text block of README.md and
README.ja.md, copy $out/screenshot.png to assets/screenshot.png, and remove $out.

Exit codes: 0 done or the READMEs match, 1 a README differs or a step failed, 2 bad arguments.
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TECHDEBT = os.path.join(os.path.dirname(HERE), "scripts", "techdebt.py")
AUTHOR = ("Sample Author", "sample@example.com")
DAY = 86400

# ---------------------------------------------------------------------------
# The code of the sample

# Every stanza of a generated body names its function in one line, so that no eight lines repeat in
# two places except the blocks that the sample copies on purpose.
FIELDS = ["customer", "currency", "tax_code", "discount", "quantity", "unit_price", "due_date", "status",
          "region", "coupon", "shipping", "note", "address", "reference", "channel"]


def camel(word):
    head, *rest = word.split("_")
    return head + "".join(w.title() for w in rest)


def kebab(name):
    return re.sub(r"(?<!^)([A-Z])", r"-\1", name).lower()


def py_function(name, params, length, doc):
    obj = params.split(",")[0].strip()
    head = ["def %s(%s):" % (name, params), '    """%s"""' % doc,
            '    total = Decimal("0")', "    changes = []", "    previous = load_previous(%s)" % obj]
    body = []
    k = 0
    while len(head) + len(body) + 1 < length:
        f = FIELDS[k % len(FIELDS)]
        kind = (k // len(FIELDS)) % 3
        if kind == 0:
            body += ['    %s = getattr(%s, "%s", None)' % (f, obj, f),
                     "    if %s is None:" % f,
                     '        log.warning("%s: no %s on %%s", %s.id)' % (name, f, obj),
                     '        %s = DEFAULTS["%s"]' % (f, f)]
        elif kind == 1:
            body += ["    if %s.%s != previous.%s:" % (obj, f, f),
                     '        changes.append(("%s", "%s", previous.%s, %s.%s))' % (name, f, f, obj, f)]
        else:
            body += ['    total += WEIGHTS.get("%s", 1) * len(str(%s.%s or ""))' % (f, obj, f),
                     '    log.debug("%s: weighed %s")' % (name, f)]
        k += 1
    return head + body + ["    return total, changes"]


def ts_body(name, obj, length, head, tail):
    body = []
    k = 0
    while len(head) + len(body) + len(tail) < length:
        f = camel(FIELDS[k % len(FIELDS)])
        kind = (k // len(FIELDS)) % 3
        if kind == 0:
            body += ["  const %s = %s.%s ?? defaults.%s;" % (f, obj, f, f),
                     "  if (%s === undefined) {" % f,
                     '    throw new Error("%s: no %s");' % (name, f),
                     "  }"]
        elif kind == 1:
            body += ["  if (%s.%s !== previous.%s) {" % (obj, f, f),
                     '    changes.push({ by: "%s", field: "%s", from: previous.%s, to: %s.%s });' % (name, f, f, obj, f),
                     "  }"]
        else:
            body += ['  total += (weights.%s ?? 1) * String(%s.%s ?? "").length;' % (f, obj, f),
                     '  log.debug("%s: weighed %s");' % (name, f)]
        k += 1
    return head + body + tail


def ts_function(name, params, ret, length, exported=True):
    obj = params.split(":")[0].strip()
    head = ["%sfunction %s(%s): %s {" % ("export " if exported else "", name, params, ret),
            "  let total = 0;", "  const changes: Change[] = [];", "  const previous = loadPrevious(%s);" % obj]
    return ts_body(name, obj, length, head, ["  return { total, changes };", "}"])


def tsx_component(name, prop, length):
    head = ["export function %s({ %s }: %sProps) {" % (name, prop, name),
            "  let total = 0;", "  const changes: Change[] = [];", "  const previous = usePrevious(%s);" % prop]
    tail = ["  return (", '    <section className="%s">' % kebab(name),
            "      <Summary total={total} changes={changes} />", "    </section>", "  );", "}"]
    return ts_body(name, prop, length, head, tail)


# The blocks that two files copy, which the scan finds as duplicated.
TAXED_LINES = [
    "    rows = []",
    "    for line in document.lines:",
    "        amount = (line.unit_price * line.quantity).quantize(CENT)",
    '        rate = TAX_RATES.get(line.tax_code, TAX_RATES["standard"])',
    "        tax = (amount * rate).quantize(CENT, rounding=ROUND_HALF_UP)",
    '        rows.append({"sku": line.sku, "amount": amount, "tax": tax})',
    '    subtotal = sum(row["amount"] for row in rows)',
    '    tax_total = sum(row["tax"] for row in rows)',
    "    if document.currency != BASE_CURRENCY:",
    "        subtotal = convert(subtotal, document.currency)",
    "        tax_total = convert(tax_total, document.currency)",
    "    return rows, subtotal, tax_total",
]
ORDER_TOTAL = [
    "  let subtotal = 0;",
    "  for (const item of order.items) {",
    "    const price = item.unitPrice * item.quantity;",
    "    const discount = item.coupon ? Math.min(price, couponValue(item.coupon)) : 0;",
    "    subtotal += Math.round((price - discount) * 100) / 100;",
    "  }",
    "  const shipping = subtotal >= FREE_SHIPPING_FROM ? 0 : SHIPPING_FEE;",
    "  const tax = Math.round(subtotal * TAX_RATE * 100) / 100;",
    "  return { subtotal, shipping, tax, total: subtotal + shipping + tax };",
    "}",
]


def py(name, params, length, doc):
    return ("py", name, params, length, doc)


def ts(name, params, ret, length, exported=True):
    return ("ts", name, params, ret, length, exported)


def tsx(name, prop, length):
    return ("tsx", name, prop, length)


def copied(lines, head):
    return ("copy", head, lines)


# Each file: when it was added (days before today), how many commits change it, what its commits
# are about, its parts, and the markers that commits add later (function, comment, days before today).
FILES = {
    "src/billing/invoice.py": dict(
        created=360, changes=31, topic="invoice totals", doc="Invoices: their lines, totals, and PDF.",
        parts=[py("invoice_total", "invoice, rates", 72, "Adds up the lines of an invoice with their discounts and taxes."),
               py("apply_discounts", "invoice, coupons", 66, "Applies the customer's coupons to the lines of an invoice."),
               copied(TAXED_LINES, "def taxed_lines(document):"),
               py("render_pdf", "invoice, template", 84, "Renders an invoice as a PDF with the shop's letterhead."),
               py("line_amount", "line", 14, "The amount of one line before tax."),
               py("tax_for", "line, region", 18, "The tax of one line in a region."),
               py("due_date_for", "invoice", 12, "The day an invoice falls due."),
               py("number_invoice", "invoice", 16, "Gives an invoice the next number of its year."),
               py("void_invoice", "invoice, reason", 20, "Voids an invoice and keeps the reason."),
               py("send_invoice", "invoice, mailer", 22, "Sends an invoice to the customer."),
               py("invoice_lines", "invoice", 18, "The lines of an invoice in the order of the cart."),
               py("merge_invoices", "invoice, other", 26, "Merges two open invoices of one customer."),
               py("credit_note", "invoice, amount", 24, "Writes a credit note against an invoice."),
               py("summary_row", "invoice", 16, "The row of an invoice in the monthly summary."),
               py("export_csv", "invoice, path", 28, "Writes the lines of an invoice to a CSV file."),
               py("mark_paid", "invoice, payment", 18, "Marks an invoice as paid by a payment."),
               py("remind_overdue", "invoice, today", 30, "Sends a reminder for an overdue invoice."),
               py("late_fee", "invoice, today", 24, "The fee for an invoice paid late.")],
        markers=[(None, "# TODO: move render_pdf into its own module, it loads the PDF library on every import", 360),
                 ("apply_discounts", "    # TODO: stacked coupons apply in the order they were added, not by size", 200),
                 ("invoice_total", "    # FIXME: rounding each line and then the total is a cent off on large invoices", 95)]),
    "src/api/orders.ts": dict(
        created=340, changes=44, topic="order handlers", doc="The HTTP handlers for orders.",
        parts=[ts("updateOrder", "order: Order", "Result", 70),
               copied(ORDER_TOTAL, "export function orderTotal(order: Order): Totals {"),
               ts("createOrder", "order: NewOrder", "Result", 44),
               ts("cancelOrder", "order: Order", "Result", 30),
               ts("listOrders", "query: OrderQuery", "Result", 26),
               ts("orderSummary", "order: Order", "Result", 22),
               ts("shipOrder", "order: Order", "Result", 34),
               ts("refundOrder", "order: Order", "Result", 28),
               ts("validateOrder", "input: OrderInput", "Result", 24)],
        markers=[("updateOrder", "  // TODO: check the change of status against the allowed transitions", 150)]),
    "src/web/checkout.tsx": dict(
        created=300, changes=25, topic="checkout page", doc="The checkout page.",
        parts=[tsx("CheckoutPage", "cart", 75),
               ts("validateCheckout", "form: CheckoutForm", "Result", 64),
               tsx("ShippingOptions", "options", 30),
               tsx("PaymentForm", "payment", 34)],
        markers=[("CheckoutPage", "  // HACK: wait for the address form to settle before reading the shipping fee", 60)]),
    "src/billing/refunds.py": dict(
        created=330, changes=18, topic="refunds", doc="Full and partial refunds.",
        parts=[py("issue_refund", "refund, invoice", 62, "Issues a refund against an invoice."),
               copied(TAXED_LINES, "def refund_taxed_lines(document):"),
               py("refund_status", "refund", 14, "The status of a refund at the payment provider."),
               py("cancel_refund", "refund, reason", 18, "Cancels a refund that has not been paid out."),
               py("refund_to_card", "refund, gateway", 22, "Pays a refund back to the card."),
               py("refunds_for", "invoice", 12, "The refunds of an invoice.")],
        markers=[("issue_refund", "    # TODO: a partial refund of a discounted line refunds the full price", 120)]),
    "src/api/returns.ts": dict(
        created=250, changes=13, topic="return handlers", doc="The HTTP handlers for returns.",
        parts=[copied(ORDER_TOTAL, "function returnTotal(order: Order): Totals {"),
               ts("createReturn", "request: ReturnRequest", "Result", 28),
               ts("approveReturn", "ret: Return", "Result", 22)]),
    "src/billing/tax.py": dict(
        created=350, changes=9, topic="tax rates", doc="Tax rates by region.",
        parts=[py("tax_rate", "code", 12, "The rate of a tax code."),
               py("tax_for_region", "region, amount", 16, "The tax on an amount in a region."),
               py("reverse_charge", "order", 14, "Whether an order is charged in reverse.")]),
    "src/billing/currency.py": dict(
        created=345, changes=6, topic="currency conversion", doc="Conversion between currencies.",
        parts=[py("convert", "amount, currency", 14, "Converts an amount to the base currency."),
               py("rate_on", "currency, day", 12, "The rate of a currency on a day."),
               py("format_amount", "amount, currency", 10, "Formats an amount with its currency.")]),
    "src/api/server.ts": dict(
        created=340, changes=7, topic="server setup", doc="The HTTP server.", imports=['import express from "express";'],
        parts=[ts("createServer", "config: ServerConfig", "Server", 20),
               ts("registerRoutes", "app: App", "void", 24)]),
    "src/api/customers.ts": dict(
        created=320, changes=11, topic="customer handlers", doc="The HTTP handlers for customers.",
        parts=[ts("getCustomer", "id: CustomerId", "Result", 16),
               ts("updateCustomer", "customer: Customer", "Result", 28),
               ts("mergeCustomers", "customer: Customer", "Result", 30)]),
    "src/api/products.ts": dict(
        created=310, changes=9, topic="product handlers", doc="The HTTP handlers for products.",
        parts=[ts("listProducts", "query: ProductQuery", "Result", 22),
               ts("updateProduct", "product: Product", "Result", 26),
               ts("archiveProduct", "product: Product", "Result", 14)]),
    "src/api/auth.ts": dict(
        created=300, changes=5, topic="sign-in", doc="Signing in and out.", imports=['import { z } from "zod";'],
        parts=[ts("login", "request: LoginRequest", "Result", 24),
               ts("refreshToken", "session: Session", "Result", 18),
               ts("logout", "session: Session", "Result", 10)]),
    "src/lib/money.ts": dict(
        created=330, changes=4, topic="money helpers", doc="Adding, splitting, and formatting money.",
        parts=[ts("addMoney", "a: Money", "Money", 10),
               ts("splitMoney", "amount: Money", "Money[]", 18),
               ts("formatMoney", "amount: Money", "string", 12)]),
    "src/lib/dates.ts": dict(
        created=320, changes=3, topic="date helpers", doc="Days and business days.",
        parts=[ts("addDays", "day: Day", "Day", 8),
               ts("businessDaysBetween", "start: Day", "number", 20),
               ts("formatDate", "day: Day", "string", 10)]),
    "src/web/cart.tsx": dict(
        created=290, changes=12, topic="cart page", doc="The cart page.",
        parts=[tsx("CartPage", "cart", 40), tsx("CartRow", "line", 22)]),
    "src/web/product-page.tsx": dict(
        created=280, changes=10, topic="product page", doc="The page of one product.",
        parts=[tsx("ProductPage", "product", 44), tsx("Gallery", "images", 20)]),
    "src/web/header.tsx": dict(
        created=270, changes=4, topic="page header", doc="The header of every page.",
        parts=[tsx("Header", "user", 26)]),
    "src/web/account.tsx": dict(
        created=200, changes=8, topic="account page", doc="The account page.",
        parts=[tsx("AccountPage", "account", 48)]),
    "src/web/search.tsx": dict(
        created=180, changes=6, topic="search page", doc="The search page.",
        parts=[tsx("SearchPage", "query", 36), ts("useSearch", "query: SearchQuery", "SearchState", 22)]),
    "src/web/main.tsx": dict(
        created=290, changes=2, topic="app entry", doc="Mounts the app.",
        imports=['import { createRoot } from "react-dom/client";'],
        parts=[ts("mount", "root: HTMLElement", "void", 10)]),
    "src/jobs/nightly_report.py": dict(
        created=260, changes=7, topic="nightly report", doc="The sales report sent every night.",
        parts=[py("build_report", "day, orders", 40, "Builds the report of a day's orders."),
               py("send_report", "report, recipients", 18, "Sends the report.")]),
    "src/jobs/sync_inventory.py": dict(
        created=240, changes=9, topic="inventory sync", doc="Syncs stock with the suppliers.",
        parts=[py("sync_inventory", "supplier, items", 46, "Syncs the stock of a supplier's items."),
               py("fetch_supplier_stock", "supplier", 20, "Reads the stock a supplier reports.")]),
    "src/inventory/stock.py": dict(
        created=330, changes=8, topic="stock reservations", doc="Reserving and releasing stock.",
        parts=[py("reserve", "item, quantity", 18, "Reserves stock for an order."),
               py("release", "reservation", 14, "Releases reserved stock."),
               py("available", "item", 12, "The stock of an item that is not reserved.")]),
    "src/inventory/warehouse.py": dict(
        created=220, changes=5, topic="warehouse choice", doc="Choosing the warehouse that ships an order.",
        parts=[py("pick_warehouse", "order, warehouses", 26, "Picks the warehouse that ships an order."),
               py("transfer", "item, warehouse", 22, "Moves stock between warehouses.")]),
    "src/notify/mailer.py": dict(
        created=230, changes=6, topic="mail notices", doc="Mail sent to customers.",
        parts=[py("send_receipt", "order, mailer", 24, "Mails the receipt of an order."),
               py("send_shipped", "shipment, mailer", 20, "Mails that an order has shipped.")]),
    "src/notify/sms.py": dict(
        created=150, changes=3, topic="text messages", doc="Text messages sent to customers.",
        parts=[py("send_code", "phone, code", 14, "Sends a sign-in code by text message.")]),
    "src/config.py": dict(
        created=340, changes=5, topic="settings", doc="Settings read from the environment.",
        parts=[py("load_config", "environ", 30, "Reads the settings from the environment.")]),
}

# Test files: the source they test, when they were added, and how many commits change them. Each
# commit adds a test.
TESTS = {
    "tests/test_tax.py": ("src/billing/tax.py", "tax_rate", 340, 3),
    "tests/test_currency.py": ("src/billing/currency.py", "convert", 330, 2),
    "tests/test_stock.py": ("src/inventory/stock.py", "reserve", 300, 2),
    "tests/money.test.ts": ("src/lib/money.ts", "formatMoney", 320, 3),
    "tests/cart.test.tsx": ("src/web/cart.tsx", "CartPage", 280, 3),
}

PACKAGE = {
    "name": "shop",
    "private": True,
    "scripts": {"start": "node dist/api/server.js", "test": "vitest run"},
    "dependencies": {"express": "^4.19.2", "lodash": "^4.17.21", "moment": "^2.30.1", "react": "^18.3.1",
                     "react-dom": "^18.3.1", "zod": "^3.23.8"},
    "devDependencies": {"vitest": "^1.6.0"},
}
STATIC = {
    "README.md": "# shop\n\nThe code of a small online shop: billing and jobs in Python, the API in TypeScript, and the pages in React.\n",
    ".gitignore": "node_modules/\n.venv/\n__pycache__/\ndist/\n",
    "package.json": json.dumps(PACKAGE, indent=2) + "\n",
    "tsconfig.json": json.dumps({"compilerOptions": {"strict": True, "jsx": "react-jsx", "outDir": "dist"},
                                 "include": ["src", "tests"]}, indent=2) + "\n",
    "pyproject.toml": '[project]\nname = "shop"\nversion = "0.1.0"\nrequires-python = ">=3.11"\n',
}

VERBS = ["Fix", "Handle", "Tidy", "Speed up", "Log", "Validate", "Support", "Rework"]


def render_source(path, spec, day, revision):
    """The text of a source file at a commit `day` days before today, its `revision`th change."""
    python = path.endswith(".py")
    markers = {}
    for where, text, added in spec.get("markers", []):
        if added >= day:
            markers.setdefault(where, []).append(text)
    if python:
        lines = ['"""%s"""' % spec["doc"], "import logging", "from decimal import ROUND_HALF_UP, Decimal", "",
                 "from src.config import BASE_CURRENCY, CENT, DEFAULTS, TAX_RATES, WEIGHTS, load_previous", ""]
        lines += markers.get(None, [])
        lines += ["log = logging.getLogger(__name__)", "SCHEMA_VERSION = %d" % revision]
    else:
        lines = ["// %s" % spec["doc"]] + spec.get("imports", [])
        if path.endswith(".tsx"):
            lines.append('import { useState } from "react";')
        lines += ['import { defaults, loadPrevious, log, usePrevious, weights } from "../lib/shared";',
                  'import type { Change } from "../lib/types";', ""]
        lines += markers.get(None, [])
        lines.append("export const SCHEMA_VERSION = %d;" % revision)
    for part in spec["parts"]:
        if part[0] == "py":
            block = py_function(*part[1:])
        elif part[0] == "ts":
            block = ts_function(*part[1:])
        elif part[0] == "tsx":
            block = tsx_component(*part[1:])
        else:
            block = [part[1]] + part[2]
        name = part[1]
        if name in markers:
            block = block[:1] + markers[name] + block[1:]
        lines += [""] * (2 if python else 1) + block
    return "\n".join(lines) + "\n"


def render_test(path, test, revision):
    source, name, _, _ = test
    if path.endswith(".py"):
        module = source[:-3].replace("/", ".")
        lines = ['"""Tests for %s."""' % source, "from %s import %s" % (module, name), "",
                 "from tests.cases import EXPECTED, SAMPLES"]
        for i in range(1, revision + 2):
            lines += ["", "", "def test_%s_case_%d():" % (name, i),
                      "    result = %s(SAMPLES[%d])" % (name, i),
                      "    assert result == EXPECTED[%d]" % i]
    else:
        target = "../" + source.rsplit(".", 1)[0]
        lines = ['import { describe, expect, it } from "vitest";', 'import { %s } from "%s";' % (name, target),
                 'import { expected, samples } from "./cases";', "", 'describe("%s", () => {' % name]
        for i in range(1, revision + 2):
            lines += ['  it("handles case %d", () => {' % i,
                      "    expect(%s(samples[%d])).toEqual(expected[%d]);" % (name, i, i), "  });"]
        lines.append("});")
    return "\n".join(lines) + "\n"


def schedule():
    """The commits of the sample: (days before today, minute of that day, [paths]), oldest first."""
    events = []
    plans = [(p, s["created"], s["changes"]) for p, s in FILES.items()]
    plans += [(p, t[2], t[3]) for p, t in TESTS.items()]
    for path, created, changes in plans:
        days = [created] + [round(created - (created - 3) * i / (changes - 1)) for i in range(1, changes)]
        events += [(d, path) for d in days]
    events.sort(key=lambda e: (-e[0], e[1]))
    commits = []
    for day, path in events:
        if commits and commits[-1][0] == day and path not in commits[-1][2]:
            commits[-1][2].append(path)
        else:
            minute = commits[-1][1] + 1 if commits and commits[-1][0] == day else 0
            commits.append((day, minute, [path]))
    return commits


def git(root, *args, stdin=None):
    """Runs git in root without the git settings of the user."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    r = subprocess.run(["git", "-C", root] + list(args), env=env, input=stdin, capture_output=True)
    if r.returncode != 0:
        sys.exit("sample_repo: git %s failed: %s" % (args[0], r.stderr.decode("utf-8", "replace").strip()))


def data(text):
    raw = text.encode("utf-8")
    return b"data %d\n%s\n" % (len(raw), raw)


def history(now):
    """The commits of the sample as one stream for `git fast-import`."""
    out = []
    revisions = {}
    for n, (day, minute, paths) in enumerate(schedule()):
        changed = dict(STATIC) if n == 0 else {}
        for path in paths:
            revisions[path] = revisions.get(path, 0) + 1
            if path in FILES:
                changed[path] = render_source(path, FILES[path], day, revisions[path])
            else:
                changed[path] = render_test(path, TESTS[path], revisions[path])
        first = paths[0]
        topic = FILES[first]["topic"] if first in FILES else "tests of " + FILES[TESTS[first][0]]["topic"]
        message = ("Add " if revisions[first] == 1 else VERBS[(n + revisions[first]) % len(VERBS)] + " ") + topic
        # An hour before the time of day, so that a scan run now reads the age as `day` days.
        who = "%s <%s> %d +0000" % (AUTHOR[0], AUTHOR[1], now - day * DAY - 3600 + minute * 60)
        out.append(b"commit refs/heads/main\nmark :%d\nauthor %s\ncommitter %s\n" % (n + 1, who.encode(), who.encode()))
        out.append(data(message))
        if n:
            out.append(b"from :%d\n" % n)
        for path, text in changed.items():
            out.append(b"M 100644 inline %s\n" % path.encode())
            out.append(data(text))
        out.append(b"\n")
    return b"".join(out)


def build(root):
    if os.path.exists(root) and os.listdir(root):
        print("sample_repo: %s is not empty" % root, file=sys.stderr)
        return 2
    os.makedirs(root, exist_ok=True)
    git(root, "init", "-q", "-b", "main")
    git(root, "fast-import", "--quiet", stdin=history(int(time.time())))
    git(root, "reset", "-q", "--hard", "main")
    return 0


# ---------------------------------------------------------------------------
# The notes of the agent on the top files, with the numbers read from the scan

NOTES = {
    "src/billing/invoice.py": {
        "what": "Builds invoices, adds up their totals, and renders the PDF",
        "why": "It changed {changes} times in a year, and invoice_total, apply_discounts, and render_pdf are each over 60 lines with no test to catch a wrong total",
        "action": "Add a test for invoice_total, then move render_pdf into its own module as the TODO at the top asks"},
    "src/api/orders.ts": {
        "what": "The HTTP handlers that create and update orders",
        "why": "It is the most changed file in the repository, and its orderTotal is copied in returns.ts, so a fix in one is missed in the other",
        "action": "Move orderTotal into src/lib/money.ts and call it from both handlers"},
    "src/web/checkout.tsx": {
        "what": "The checkout page and the checks on its form",
        "why": "CheckoutPage and validateCheckout are both over 60 lines, and a HACK waits for the address form before it reads the shipping fee",
        "action": "Move validateCheckout into its own module with a test, then read the shipping fee from the state of the form"},
    "src/billing/refunds.py": {
        "what": "Issues full and partial refunds",
        "why": "Its taxed lines are a copy of the ones in invoice.py, and its TODO says that a partial refund of a discounted line refunds the full price",
        "action": "Call taxed_lines from invoice.py and add a test for a partial refund of a discounted line"},
    "src/api/returns.ts": {
        "what": "The HTTP handlers for returns",
        "why": "Its returnTotal is a copy of orderTotal in orders.ts",
        "action": "Use the shared orderTotal once it lives in src/lib/money.ts"},
}


def notes_for(scan):
    ranked = {r["file"]: {x["key"]: x["value"] for x in r["reasons"]} for r in scan["ranked"]}
    return {path: {k: v.format(**ranked[path]) for k, v in note.items()}
            for path, note in NOTES.items() if path in ranked}


def run(cmd, env):
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("sample_repo: %s failed with exit %d: %s" % (" ".join(cmd[1:3]), r.returncode, r.stderr.strip()))
    return r.stdout


def readme(out, browser):
    out = os.path.realpath(out)
    home = os.path.join(out, "profile")
    shop = os.path.join(home, "work", "shop")
    state = os.path.join(out, "state")
    tools = os.path.join(out, "bin")
    found = shutil.which("git")
    if not found:
        sys.exit("sample_repo: git is not on PATH")
    status = build(shop)
    if status:
        return status
    os.makedirs(tools, exist_ok=True)
    os.symlink(os.path.realpath(found), os.path.join(tools, "git"))
    env = dict(os.environ, HOME=home, TECHDEBT_HOME=state, PATH=tools)
    summary = run([sys.executable, TECHDEBT, "scan", shop], env)
    with open(os.path.join(out, "scan.txt"), "w", encoding="utf-8") as fh:
        fh.write(summary)
    folders = glob.glob(os.path.join(state, "shop-*"))
    if len(folders) != 1:
        sys.exit("sample_repo: found %d state folders of the sample" % len(folders))
    with open(os.path.join(folders[0], "scan.json"), encoding="utf-8") as fh:
        scan = json.load(fh)
    notes = os.path.join(out, "notes.json")
    with open(notes, "w", encoding="utf-8") as fh:
        json.dump(notes_for(scan), fh, indent=1)
    run([sys.executable, TECHDEBT, "explain", "--notes", notes, shop], env)
    page = os.path.join(folders[0], "report.html")
    print(summary, end="")
    if browser:
        shot = os.path.join(out, "screenshot.png")
        subprocess.run([browser, "--headless", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
                        "--user-data-dir=" + os.path.join(out, "browser-profile"), "--window-size=1280,800",
                        "--force-device-scale-factor=2", "--virtual-time-budget=3000", "--screenshot=" + shot,
                        "file://%s#item-%s" % (page, scan["ranked"][0]["file"])],
                       capture_output=True, timeout=120)
        if not os.path.isfile(shot):
            sys.exit("sample_repo: the browser saved no screenshot")
        print("Screenshot: %s" % shot)
    return 0


# ---------------------------------------------------------------------------
# Comparing the READMEs with a scan

HEAD_HASH = re.compile(r"HEAD [0-9a-f]{7,40}")
RANKING = [re.compile(r"goes on to (\d+) files"), re.compile(r"\u9806\u4f4d\u306f(\d+)\u4f4d\u307e\u3067")]


def ranked_count(lines):
    if "Start here" not in lines:
        return 0
    n = 0
    for line in lines[lines.index("Start here") + 1:]:
        if not re.match(r"\s*\d+  \S", line):
            break
        n += 1
    return n


def compare(scan_path, readmes):
    with open(scan_path, encoding="utf-8") as fh:
        scan = fh.read().split("\n")
    masked = [HEAD_HASH.sub("HEAD <hash>", l) for l in scan]
    ranked = ranked_count(scan)
    problems = []
    for path in readmes:
        name = os.path.basename(path)
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        start = next((i for i, l in enumerate(lines) if l.startswith("techdebt scan of ")), None)
        if start is None:
            problems.append("%s has no sample summary that starts with 'techdebt scan of'" % name)
        else:
            k = 0
            while start + k < len(lines) and not lines[start + k].startswith("```"):
                line = lines[start + k]
                if k >= len(scan) or HEAD_HASH.sub("HEAD <hash>", line) != masked[k]:
                    problems.append("%s line %d: the README has %r, the scan has %r"
                                    % (name, start + k + 1, line, scan[k] if k < len(scan) else "no line"))
                k += 1
        said = [(n, int(m.group(1))) for n, l in enumerate(lines, 1) for rx in RANKING for m in [rx.search(l)] if m]
        if not said:
            problems.append("%s does not say how far the ranking goes" % name)
        problems += ["%s line %d: the README says the ranking goes on to %d files, the scan ranks %d" % (name, n, v, ranked)
                     for n, v in said if v != ranked]
    for p in problems:
        print(p)
    if not problems:
        print("ok")
    return 1 if problems else 0


def main():
    parser = argparse.ArgumentParser(description="Build the sample repository of the README and check the README.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("build")
    p.add_argument("dir")
    p = sub.add_parser("readme")
    p.add_argument("out")
    p.add_argument("--browser")
    p = sub.add_parser("compare")
    p.add_argument("scan")
    p.add_argument("readmes", nargs="+")
    args = parser.parse_args()
    if args.command == "build":
        return build(os.path.abspath(args.dir))
    if args.command == "readme":
        return readme(os.path.abspath(args.out), args.browser)
    return compare(args.scan, args.readmes)


if __name__ == "__main__":
    sys.exit(main())
