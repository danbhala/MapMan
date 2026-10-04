#!/usr/bin/env python3
"""Cut the fallback fonts down to the characters the translations use.

    python3 godot/tools/subset_fonts.py <noto fonts dir>

JetBrains Mono covers Latin, Greek and Cyrillic. Arabic, Japanese, Korean and
Chinese text falls back to Noto Sans fonts, which are 10-18 MB each in full.
This keeps only the glyphs that appear in godot/i18n/*.json (plus digits and
basic punctuation) and writes small variable fonts (the weight axis survives,
so bold headers and stamps still work) into godot/assets/fonts/i18n/.
Rerun it whenever a translation changes; test_i18n.gd fails if a character
has no glyph in any bundled font. Needs fonttools (pip install fonttools brotli).

Each subset also takes JetBrains Mono's vertical metrics: Godot sizes a line
by the tallest font in the fallback chain, so Noto Sans Arabic's deep
descender (0.74 em) would otherwise push every line apart, in every language.
"""
import glob
import json
import os
import subprocess
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
I18N = os.path.join(HERE, "..", "i18n")
OUT = os.path.join(HERE, "..", "assets", "fonts", "i18n")
MAIN_FONT = os.path.join(HERE, "..", "assets", "fonts", "JetBrainsMono-Variable.ttf")

# Output name -> (source file, locales whose text it serves)
FONTS = {
    "NotoSansArabic-Subset.ttf": ("NotoSansArabic[wdth,wght].ttf", ["ar"]),
    "NotoSansJP-Subset.ttf": ("NotoSansJP[wght].ttf", ["ja"]),
    "NotoSansKR-Subset.ttf": ("NotoSansKR[wght].ttf", ["ko"]),
    "NotoSansSC-Subset.ttf": ("NotoSansSC[wght].ttf", ["zh_CN"]),
    "NotoSansTC-Subset.otf": ("NotoSansTC-VF.otf", ["zh_TW"]),
}
ALWAYS = "0123456789 .,:;!?%()[]+-−/×·—–'\"★♥"


def text_of(locale):
    path = os.path.join(I18N, locale + ".json")
    if not os.path.exists(path):
        return ""
    data = json.load(open(path, encoding="utf-8"))
    chars = []
    for value in data.values():
        for form in (value if isinstance(value, list) else [value]):
            chars.append(form)
    # The language's own name is shown on the language sheet in every locale.
    catalog = json.load(open(os.path.join(I18N, "catalog.json"), encoding="utf-8"))
    chars.append(catalog["locales"][locale]["name"])
    return "".join(chars)


def match_line_metrics(path, main_path):
    """Give the font at `path` the main font's ascent and descent, in its em."""
    main = TTFont(main_path)
    font = TTFont(path)
    scale = font["head"].unitsPerEm / main["head"].unitsPerEm
    ascent = round(main["hhea"].ascent * scale)
    descent = round(main["hhea"].descent * scale)  # negative
    hhea, os2 = font["hhea"], font["OS/2"]
    hhea.ascent, hhea.descent, hhea.lineGap = ascent, descent, 0
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ascent, descent, 0
    os2.usWinAscent, os2.usWinDescent = ascent, -descent
    if os2.version >= 4:
        os2.fsSelection |= 1 << 7  # USE_TYPO_METRICS, as JetBrains Mono sets it
    font.save(path)


def main(src_dir):
    os.makedirs(OUT, exist_ok=True)
    for name, (source, locales) in FONTS.items():
        text = ALWAYS + "".join(text_of(l) for l in locales)
        unicodes = sorted({ord(c) for c in text if not c.isspace() or c == " "})
        if len(unicodes) <= len(ALWAYS):
            print("%s: no translations yet, skipped" % name)
            continue
        unicodes_arg = ",".join("U+%04X" % u for u in unicodes)
        out = os.path.join(OUT, name)
        subprocess.check_call([
            "pyftsubset", os.path.join(src_dir, source),
            "--unicodes=" + unicodes_arg, "--output-file=" + out,
            "--name-IDs=*", "--no-hinting", "--layout-features=*",
        ])
        match_line_metrics(out, MAIN_FONT)
        print("%s: %d characters, %d KB" % (name, len(unicodes), os.path.getsize(out) // 1024))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
