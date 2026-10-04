"""Stamp a build's version into its export preset and write godot/build_info.json.

    python3 stamp.py PRESET VERSION BUILD SOURCE [key=value ...]

VERSION is the full version ("1.2.0-pr.16"); BUILD is the number that must
only ever go up per app. Android presets get version/name = VERSION and
version/code = BUILD. iOS presets get application/short_version = the plain
"1.2.0" (TestFlight refuses anything else; the suffix stays in build_info.json)
and application/version = BUILD. Any key=value pairs are set as written (a
string value needs its quotes), added to the preset's options if missing.
"""

import datetime
import json
import os
import re
import subprocess
import sys

PATH = "godot/export_presets.cfg"


def stamp(text: str, preset: str, values: dict) -> str:
    presets = re.findall(r'\[preset\.(\d+)\]\n\nname="([^"]+)"', text)
    matches = [i for i, n in presets if n == preset]
    if not matches:
        sys.exit(f"no export preset named {preset!r} in {PATH}")
    index = matches[0]
    head, sep, rest = text.partition(f"[preset.{index}.options]")
    body, nxt, tail = rest.partition("\n[preset.")
    for key, value in values.items():
        line = f"{key}={value}"
        pattern = rf"(?m)^{re.escape(key)}=.*$"
        if re.search(pattern, body):
            body = re.sub(pattern, lambda _m: line, body)
        else:
            body = body.rstrip("\n") + "\n" + line + "\n"
    return head + sep + body + nxt + tail


def platform_of(text: str, preset: str) -> str:
    m = re.search(rf'\nname="{re.escape(preset)}"\nplatform="([^"]+)"', text)
    return m.group(1) if m else ""


def main() -> None:
    preset, version, build, source = sys.argv[1:5]
    text = open(PATH).read()
    if platform_of(text, preset) == "iOS":
        values = {
            "application/short_version": f'"{version.split("-")[0]}"',
            "application/version": f'"{build}"',
        }
    else:
        values = {"version/name": f'"{version}"', "version/code": build}
    for pair in sys.argv[5:]:
        key, _, value = pair.partition("=")
        values[key] = value
    open(PATH, "w").write(stamp(text, preset, values))

    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    info = {
        "version": version,
        "commit": os.environ.get("BUILD_COMMIT") or commit,
        "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "source": source,
    }
    json.dump(info, open("godot/build_info.json", "w"))
    print(preset, values, info)


if __name__ == "__main__":
    main()
