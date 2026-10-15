#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Tiles every PNG the notch render harness wrote into one labelled contact sheet.

    python3 scripts/notch-contact-sheet.py <render dir> [output.png]

Tiles keep their points-to-pixels ratio (renders are 2 px per pt; tiles are
drawn at 1 px per pt, so the sheet shows each state at its size in points),
except the lock screen, which is scaled to the column width. Needs Pillow.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

COLUMN = 720          # points per column
GAP = 24
LABEL = 30
GROUND = (44, 44, 46)
INK = (235, 235, 240)


def font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    folder = Path(sys.argv[1])
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else folder / "contact-sheet.png"
    tiles = []
    for path in sorted(folder.glob("*.png")):
        if path.name == output.name:
            continue
        image = Image.open(path).convert("RGB")
        width, height = image.width // 2, image.height // 2
        if width > COLUMN:
            height = round(height * COLUMN / width)
            width = COLUMN
        tiles.append((path.stem, image.resize((width, height), Image.LANCZOS)))
    if not tiles:
        sys.exit(f"no PNGs in {folder}")
    columns = 3
    rows = [tiles[i:i + columns] for i in range(0, len(tiles), columns)]
    row_heights = [max(tile.height for _, tile in row) + LABEL + GAP for row in rows]
    sheet = Image.new("RGB", (columns * (COLUMN + GAP) + GAP, sum(row_heights) + GAP), GROUND)
    draw = ImageDraw.Draw(sheet)
    label_font = font(18)
    y = GAP
    for row, row_height in zip(rows, row_heights):
        x = GAP
        for name, tile in row:
            draw.text((x, y), name, fill=INK, font=label_font)
            sheet.paste(tile, (x, y + LABEL))
            # A hairline frame, so a black island reads against the dark ground.
            draw.rectangle((x - 1, y + LABEL - 1, x + tile.width, y + LABEL + tile.height), outline=(90, 90, 96))
            x += COLUMN + GAP
        y += row_height
    sheet.save(output)
    print(output)


if __name__ == "__main__":
    main()
