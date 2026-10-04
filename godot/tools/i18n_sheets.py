#!/usr/bin/env python3
"""Tile the pictures tools/i18n_shots.gd saved into one contact sheet per
language (<out>/<locale>.png) and one of the main menu in every language
(<out>/all_main_menus.png). Needs Pillow.

    python3 godot/tools/i18n_sheets.py <out_dir>
"""
import glob
import os
import sys

from PIL import Image, ImageDraw


def tile(paths, out, cols=3, scale=0.4, label=os.path.basename):
    images = [Image.open(p) for p in paths]
    if not images:
        return
    w, h = images[0].size
    tw, th = int(w * scale), int(h * scale)
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, (th + 16) * rows), (30, 30, 30))
    draw = ImageDraw.Draw(sheet)
    for i, (path, image) in enumerate(zip(paths, images)):
        x, y = (i % cols) * tw, (i // cols) * (th + 16)
        draw.text((x + 4, y + 2), label(path), fill=(255, 255, 255))
        sheet.paste(image.resize((tw, th)), (x, y + 16))
    sheet.save(out)


def main(out_dir):
    mains = []
    for locale in sorted(os.listdir(out_dir)):
        folder = os.path.join(out_dir, locale)
        if not os.path.isdir(folder):
            continue
        shots = sorted(glob.glob(os.path.join(folder, "*.png")))
        tile(shots, os.path.join(out_dir, locale + ".png"))
        main_menu = os.path.join(folder, "01_main.png")
        if os.path.exists(main_menu):
            mains.append(main_menu)
    tile(mains, os.path.join(out_dir, "all_main_menus.png"), cols=3, scale=0.33,
         label=lambda p: os.path.basename(os.path.dirname(p)))
    print("contact sheets in", out_dir)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("TMPDIR", "/tmp") + "/mapman-i18n")
