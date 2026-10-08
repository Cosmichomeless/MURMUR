#!/usr/bin/env python3
"""Shrinks raw simulator screenshots so each PNG stays under 400 KB.

Usage: optimize.py <input.png> <output.png>

Raw captures are 1206x2622. The purple gradient screens barely compress as 24-bit PNG (>3 MB), so
the image is scaled to 640 px wide and reduced to a 256-colour palette with dithering. The same
input always gives the same output.
"""
import sys

from PIL import Image

WIDTH = 640


def optimize(source: str, destination: str) -> None:
    image = Image.open(source).convert("RGB")
    height = round(image.height * WIDTH / image.width)
    image = image.resize((WIDTH, height), Image.LANCZOS)
    image = image.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    image.save(destination, optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    optimize(sys.argv[1], sys.argv[2])
