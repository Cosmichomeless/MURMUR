#!/usr/bin/env python3
"""Rebuilds 00-showcase.png, the README cover, from files that are already in the repository.

    python3 docs/screenshots/build-showcase.py        # needs Pillow: pip install pillow

It places the real app icon on the left and two crops of the real screenshots on the right, over a
gradient that uses the icon's own colours. It does NOT capture the app and does NOT regenerate the
four full screenshots: for those see docs/DEMO.md (docs/screenshots/capture.sh).
The output is deterministic, so running it twice gives the same bytes.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ICON = HERE.parent.parent / "MURMUR" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"
OUTPUT = HERE / "00-showcase.png"

SIZE = (1200, 560)
TOP_RIGHT = (46, 27, 110)      # the icon's dark corner
BOTTOM_LEFT = (122, 63, 208)   # the icon's light corner

ICON_SIZE, ICON_RADIUS = 330, 74
CARD_SIZE, CARD_RADIUS, CARD_GAP = (340, 450), 34, 30
SCALE = 4  # supersampling for smooth rounded corners


def gradient() -> Image.Image:
    width, height = SIZE
    mask = Image.new("L", SIZE)
    # 0 at the top-right corner, 255 at the bottom-left one.
    mask.putdata([
        round(255 * ((width - 1 - x) / (width - 1) * height + y / (height - 1) * width)
              / (width + height))
        for y in range(height) for x in range(width)
    ])
    return Image.composite(Image.new("RGB", SIZE, BOTTOM_LEFT), Image.new("RGB", SIZE, TOP_RIGHT), mask)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    big = Image.new("L", (size[0] * SCALE, size[1] * SCALE), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * SCALE, fill=255)
    return big.resize(size, Image.LANCZOS)


def paste_rounded(canvas: Image.Image, image: Image.Image, position: tuple[int, int], radius: int) -> None:
    mask = rounded_mask(image.size, radius)
    shadow = Image.new("L", canvas.size, 0)
    shadow.paste(mask.point(lambda value: value * 55 // 100), (position[0], position[1] + 10))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas.paste(Image.new("RGB", canvas.size, (12, 6, 36)), (0, 0), shadow)
    canvas.paste(image, position, mask)


def crop(name: str, top: int) -> Image.Image:
    """A full-width slice of a screenshot, scaled to the card."""
    image = Image.open(HERE / name).convert("RGB")
    width, height = CARD_SIZE
    slice_height = round(image.width * height / width)
    return image.crop((0, top, image.width, top + slice_height)).resize(CARD_SIZE, Image.LANCZOS)


def build() -> None:
    canvas = gradient()

    icon = Image.open(ICON).convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    paste_rounded(canvas, icon, (70, (SIZE[1] - ICON_SIZE) // 2), ICON_RADIUS)

    cards = [crop("01-library.png", 150), crop("02-recorder.png", 400)]
    x = SIZE[0] - 50 - CARD_SIZE[0] * 2 - CARD_GAP
    y = (SIZE[1] - CARD_SIZE[1]) // 2
    for card in cards:
        paste_rounded(canvas, card, (x, y), CARD_RADIUS)
        x += CARD_SIZE[0] + CARD_GAP

    canvas.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(
        OUTPUT, optimize=True
    )


if __name__ == "__main__":
    build()
    print(f"{OUTPUT.relative_to(HERE.parent.parent)}  {OUTPUT.stat().st_size // 1024} KB")
