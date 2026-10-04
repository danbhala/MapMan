#!/usr/bin/env python3
"""Build the game's .po translation files from godot/i18n.

    python3 godot/tools/i18n.py          # write godot/i18n/<locale>.po for every locale
    python3 godot/tools/i18n.py --check  # exit 1 if a .po is stale, or a locale is missing or
                                         # has extra strings, so CI can catch it

Sources: catalog.json holds every English msgid (what the code passes to tr()),
with a note and a width budget for translators, and <locale>.json holds that
locale's translations: {"MSGID": "translation"} or, for a plural entry,
{"MSGID": ["form 0", "form 1", ...]} with as many forms as the locale's
nplurals in the catalog. Godot imports the .po files listed in project.godot.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
I18N = os.path.join(HERE, "..", "i18n")


def po_string(text):
    """A msgid/msgstr in .po syntax: escaped, one line per embedded newline."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    if "\n" not in escaped:
        return '"%s"' % escaped
    lines = escaped.split("\n")
    out = ['""']
    for i, line in enumerate(lines):
        out.append('"%s%s"' % (line, "\\n" if i < len(lines) - 1 else ""))
    return "\n".join(out)


def build(locale, info, strings, translations):
    nplurals = info["nplurals"]
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: MapMan\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        '"Language: %s\\n"' % locale,
        '"Plural-Forms: nplurals=%d; plural=%s;\\n"' % (nplurals, info["plural"]),
        "",
    ]
    problems = []
    for entry in strings:
        msgid = entry["id"]
        value = translations.get(msgid)
        if value is None:
            problems.append("missing: %r" % msgid)
            continue
        if entry.get("note"):
            lines.append("#. %s" % entry["note"].replace("\n", " "))
        lines.append("msgid %s" % po_string(msgid))
        if "plural" in entry:
            if not isinstance(value, list) or len(value) != nplurals:
                problems.append("%r needs %d plural forms" % (msgid, nplurals))
                continue
            lines.append("msgid_plural %s" % po_string(entry["plural"]))
            for i, form in enumerate(value):
                lines.append("msgstr[%d] %s" % (i, po_string(form)))
        else:
            if not isinstance(value, str) or value == "":
                problems.append("%r is empty" % msgid)
                continue
            lines.append("msgstr %s" % po_string(value))
        lines.append("")
    known = {s["id"] for s in strings}
    for extra in sorted(set(translations) - known):
        problems.append("not in the catalog: %r" % extra)
    return "\n".join(lines), problems


def main(check):
    catalog = json.load(open(os.path.join(I18N, "catalog.json"), encoding="utf-8"))
    strings = catalog["strings"]
    failed = False
    for locale, info in catalog["locales"].items():
        path = os.path.join(I18N, locale + ".json")
        if not os.path.exists(path):
            print("%s: no translations file" % locale)
            failed = True
            continue
        translations = json.load(open(path, encoding="utf-8"))
        text, problems = build(locale, info, strings, translations)
        for p in problems:
            print("%s: %s" % (locale, p))
        failed = failed or bool(problems)
        po_path = os.path.join(I18N, locale + ".po")
        if check:
            current = open(po_path, encoding="utf-8").read() if os.path.exists(po_path) else ""
            if current != text:
                print("%s: %s is stale; run tools/i18n.py" % (locale, os.path.basename(po_path)))
                failed = True
        else:
            with open(po_path, "w", encoding="utf-8") as f:
                f.write(text)
            print("%s: %d strings -> %s" % (locale, len(translations), os.path.basename(po_path)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
