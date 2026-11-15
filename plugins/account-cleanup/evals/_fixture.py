"""Writes the state an eval case starts from into the run's HOME and workspace.

The run's HOME is a temporary folder, so nothing here reads or writes the real vaults, browser profile,
keychain, or accounts. The saved passwords are made up: each row has a site and dates only, with the
username and password left empty, and every site is under the reserved .example domain.

Usage: python3 _fixture.py browser | project | planned
  browser   Chrome's saved passwords and history for the made-up sites, and no data folder
  project   a small Node.js project in the workspace, and no data folder
  planned   browser, then the plugin's own scripts collect, look up, and describe the candidates
            for a user in Japan, as steps 1 to 3 of the skill leave them
"""
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "skills", "account-cleanup", "scripts")
HOME = os.environ["HOME"]
CHROME = os.path.join(HOME, "Library", "Application Support", "Google", "Chrome", "Default")
DATA = os.path.join(HOME, ".local", "share", "account-cleanup")

# (origin URL, created, last used or None, last visited in the history or None), dates as YYYY-MM-DD.
SITES = [
    ("https://www.northpine-bank.example/login", "2018-04-02", "2025-10-20", "2026-11-01"),
    ("https://mail.quickpost.example/", "2017-06-11", "2026-10-30", "2026-11-10"),
    ("https://pixelsnap.example/signin", "2019-02-14", "2020-03-01", "2020-05-01"),
    ("https://recipebox.example/account", "2021-01-09", None, None),
    ("https://trailmap.example/login", "2020-07-21", None, None),
    ("https://forum.old-gadgets.example/", "2016-05-30", "2017-01-04", None),
    ("https://shop.greenleaf.example/", "2022-08-18", "2026-09-12", "2026-09-20"),
    ("http://localhost:5173/", "2025-12-01", None, None),
]

# What steps 3 of the skill writes for each candidate key in the planned state.
DESCRIPTIONS = {
    "northpine-bank.example": ("An online bank", "bank", "ng", "A bank account should be closed with the bank, not here"),
    "quickpost.example": ("An email service", "email", "ng", "Other accounts may use this address to sign in"),
    "pixelsnap.example": ("A photo-sharing social network", "social", "ok", "Not used since 2020"),
    "recipebox.example": ("A recipe collection site", "other", "ok", "Saved once and never used"),
    "trailmap.example": ("Hiking trail maps", "other", "ok", "Not used since it was saved in 2020"),
    "old-gadgets.example": ("A forum about old gadgets", "social", "ok", "Not used since 2017"),
    "greenleaf.example": ("An online plant shop", "shopping", "ng", "Used in September 2026"),
    "localhost": ("A development address on this computer", "dev", "ok", "Not a web service account"),
}


def chrome_time(day):
    """Chrome stores times as microseconds since 1601-01-01."""
    import datetime
    seconds = (datetime.datetime.fromisoformat(day + "T12:00:00+00:00") -
               datetime.datetime(1601, 1, 1, tzinfo=datetime.timezone.utc)).total_seconds()
    return int(seconds) * 1000000


def write_browser():
    os.makedirs(CHROME, exist_ok=True)
    db = sqlite3.connect(os.path.join(CHROME, "Login Data"))
    db.execute("CREATE TABLE logins (origin_url TEXT, username_value TEXT, password_value BLOB, date_created INTEGER,"
               " date_last_used INTEGER, blacklisted_by_user INTEGER)")
    db.executemany("INSERT INTO logins VALUES (?, '', X'', ?, ?, 0)",
                   [(url, chrome_time(made), chrome_time(used) if used else 0) for url, made, used, _ in SITES])
    db.commit()
    db.close()
    db = sqlite3.connect(os.path.join(CHROME, "History"))
    db.execute("CREATE TABLE urls (url TEXT, last_visit_time INTEGER)")
    db.executemany("INSERT INTO urls VALUES (?, ?)",
                   [(url, chrome_time(seen)) for url, _, _, seen in SITES if seen])
    db.commit()
    db.close()


def write_project():
    with open("package.json", "w", encoding="utf-8") as f:
        json.dump({"name": "notes-app", "version": "1.0.0", "main": "index.js",
                   "dependencies": {"left-pad": "^1.3.0", "chalk": "^5.3.0"}}, f, indent=2)
        f.write("\n")
    with open("index.js", "w", encoding="utf-8") as f:
        f.write("const chalk = require('chalk');\n\nconsole.log(chalk.green('notes'));\n")


def run(*args):
    subprocess.run(["bash", os.path.join(SCRIPTS, args[0]), *args[1:]], check=True, stdout=subprocess.DEVNULL)


def write_planned():
    write_browser()
    # The scripts check whether each site still answers. The made-up sites do not exist, so a stand-in
    # curl answers for every site, and it is removed before the agent starts.
    stub = tempfile.mkdtemp()
    try:
        with open(os.path.join(stub, "curl"), "w", encoding="utf-8") as f:
            f.write("#!/bin/sh\nexit 0\n")
        os.chmod(os.path.join(stub, "curl"), 0o755)
        os.environ["PATH"] = stub + os.pathsep + os.environ["PATH"]
        run("add-site.sh", "trailmap.example", "https://trailmap.example/privacy", "impossible",
            "No delete button. The privacy page says to ask support by email")
        run("prepare.sh", "--sources", "chrome", "--region", "japan", "--history")
    finally:
        shutil.rmtree(stub)
    descriptions = {key: {"description": d, "category": c, "suggestion": s, "why": w}
                    for key, (d, c, s, w) in DESCRIPTIONS.items()}
    path = os.path.join(DATA, "descriptions-new.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(descriptions, f, indent=2)
    os.chmod(path, 0o600)
    run("annotate.sh", path)


def main(mode):
    if mode == "browser":
        write_browser()
    elif mode == "project":
        write_project()
    elif mode == "planned":
        write_planned()
    else:
        sys.exit("unknown mode: %s" % mode)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
