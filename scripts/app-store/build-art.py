#!/usr/bin/env python3
"""App Store header and search-result art, one set per language (docs/app-store-assets/feature-art)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
SP = REPO / "build" / "app-store"  # localized captures come from capture-locales.sh
ICON = REPO / "MURMUR/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
OUT = REPO / "docs" / "app-store-assets" / "feature-art"
FONT = "/System/Library/Fonts/SFNS.ttf"

TOP_RIGHT = (46, 27, 110)
BOTTOM_LEFT = (122, 63, 208)
CORAL = (255, 107, 87)

# folder: (headline, subline)
COPY = {
    "es-ES": ("Tu voz, hecha texto", "Notas de voz transcritas en tu iPhone"),
    "en-US": ("Your voice, as text", "Voice notes transcribed on your iPhone"),
    "fr-FR": ("Votre voix, en texte", "Notes vocales transcrites sur votre iPhone"),
    "de-DE": ("Ihre Stimme als Text", "Sprachnotizen, auf Ihrem iPhone transkribiert"),
    "it": ("La tua voce, in testo", "Note vocali trascritte sul tuo iPhone"),
    "pt-BR": ("Sua voz, em texto", "Notas de voz transcritas no seu iPhone"),
}

# name: (width, height)
FORMATS = {
    "header-5244x2950": (5244, 2950),
    "header-3840x1646": (3840, 1646),
    "search-3840x2560": (3840, 2560),
}
SS = 3  # supersampling for the rounded corners


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def gradient(size):
    w, h = size
    small = Image.new("RGB", (256, 256))
    px = small.load()
    for y in range(256):
        for x in range(256):
            t = ((255 - x) / 255 * h + y / 255 * w) / (w + h)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP_RIGHT, BOTTOM_LEFT))
    return small.resize(size, Image.BICUBIC)


def rounded(size, radius):
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * SS, fill=255)
    return big.resize(size, Image.LANCZOS)


def paste_card(canvas, image, pos, radius):
    mask = rounded(image.size, radius)
    blur = max(8, image.width // 22)
    shadow = Image.new("L", canvas.size, 0)
    shadow.paste(mask.point(lambda v: v * 55 // 100), (pos[0], pos[1] + blur // 2))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", canvas.size, (12, 6, 36)), (0, 0), shadow)
    canvas.paste(image, pos, mask)


def slice_card(path, size):
    img = Image.open(path).convert("RGB")
    cw, ch = size
    h = round(img.width * ch / cw)
    return img.crop((0, 0, img.width, h)).resize(size, Image.LANCZOS)


def wrap(draw, text, fnt, max_width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def text_block(canvas, headline, sub, left, top_or_center, block_w, icon_s, center=False, mid=None):
    """Icon + name, headline and subline. Shrinks the icon until MURMUR fits the block."""
    draw = ImageDraw.Draw(canvas)
    while True:
        title_f = font(round(icon_s * 0.62), "Bold")
        row_w = icon_s + round(icon_s * 0.28) + draw.textlength("MURMUR", font=title_f)
        if row_w <= block_w:
            break
        icon_s -= 4
    head_f = font(round(icon_s * 0.50), "Semibold")
    sub_f = font(round(icon_s * 0.30), "Regular")
    head_lines = wrap(draw, headline, head_f, block_w)
    sub_lines = wrap(draw, sub, sub_f, block_w)
    head_lh, sub_lh = round(head_f.size * 1.18), round(sub_f.size * 1.35)
    g1, g2 = round(icon_s * 0.45), round(icon_s * 0.22)
    total = icon_s + g1 + head_lh * len(head_lines) + g2 + sub_lh * len(sub_lines)
    y = (mid - total // 2) if mid is not None else top_or_center
    x0 = left + (block_w - row_w) / 2 if center else left

    icon = Image.open(ICON).convert("RGB").resize((icon_s, icon_s), Image.LANCZOS)
    paste_card(canvas, icon, (round(x0), y), round(icon_s * 0.225))
    draw = ImageDraw.Draw(canvas)
    draw.text((x0 + icon_s + round(icon_s * 0.28), y + icon_s // 2), "MURMUR", font=title_f,
              fill=(255, 255, 255), anchor="lm")
    y += icon_s + g1
    for lines, fnt, lh, fill in ((head_lines, head_f, head_lh, (255, 255, 255)), (sub_lines, sub_f, sub_lh, (222, 210, 246))):
        for line in lines:
            lx = left + (block_w - draw.textlength(line, font=fnt)) / 2 if center else left
            draw.text((lx, y), line, font=fnt, fill=fill)
            y += lh
        y += g2


def build(locale, name, size):
    w, h = size
    canvas = gradient(size)
    headline, sub = COPY[locale]
    lib, ply = SP / "art" / locale / "01-library.png", SP / "art" / locale / "03-player.png"

    if w / h >= 1.7:
        # Wide: text on the left, two phones on the right (the second one lower).
        ch = round(h * 0.80)
        cw = round(ch * 0.66)
        gap = round(w * 0.025)
        margin = round(w * 0.06)
        x2 = w - margin - cw
        x1 = x2 - gap - cw
        y1 = round(h * 0.07)
        y2 = h - y1 - ch
        radius = round(cw * 0.09)
        paste_card(canvas, slice_card(lib, (cw, ch)), (x1, y1), radius)
        paste_card(canvas, slice_card(ply, (cw, ch)), (x2, y2), radius)
        block_w = x1 - 2 * gap - margin
        text_block(canvas, headline, sub, margin, 0, block_w, round(min(h * 0.20, block_w * 0.30)), mid=h // 2)
    else:
        # Tall-ish: centered text on top, two phones bleeding off the bottom edge.
        cw = round(w * 0.30)
        ch = round(h * 0.64)
        gap = round(w * 0.03)
        x1 = (w - 2 * cw - gap) // 2
        x2 = x1 + cw + gap
        radius = round(cw * 0.09)
        paste_card(canvas, slice_card(lib, (cw, ch)), (x1, round(h * 0.46)), radius)
        paste_card(canvas, slice_card(ply, (cw, ch)), (x2, round(h * 0.52)), radius)
        margin = round(w * 0.08)
        text_block(canvas, headline, sub, margin, round(h * 0.07), w - 2 * margin, round(h * 0.13), center=True)

    dest = OUT / locale
    dest.mkdir(parents=True, exist_ok=True)
    canvas.save(dest / f"{name}.png", optimize=True)


if __name__ == "__main__":
    for locale in COPY:
        for name, size in FORMATS.items():
            build(locale, name, size)
            print(locale, name, size)
