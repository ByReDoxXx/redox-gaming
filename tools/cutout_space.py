"""Cuts the Gemini space sprites (art/gemini/space/<kind>_<n>.jpg, on a plain
white background) out and writes app/assets/space/<kind>_<n>.png.

Unlike tools/cutout_icons.py this does not rely on the dark outline: ship
engine flames have none. Background = near-white pixels connected to the
image border, so light parts inside the sprite (glass, highlights) stay.

Usage:  python tools/cutout_space.py
"""

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "gemini" / "space"
OUT = ROOT / "app" / "assets" / "space"
WORK = 1000          # mask is computed at this size
OUT_SIZE = 256       # longer side of the written sprite


def is_background(c) -> bool:
    """Near white and nearly grey (JPEG noise on the white background)."""
    return min(c) >= 222 and max(c) - min(c) <= 24


def background_mask(img: Image.Image) -> Image.Image:
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if not seen[i] and is_background(px[x, y]):
            seen[i] = 1
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while q:
        x, y = q.popleft()
        if x > 0: push(x - 1, y)
        if x < w - 1: push(x + 1, y)
        if y > 0: push(x, y - 1)
        if y < h - 1: push(x, y + 1)

    mask = Image.new("L", (w, h), 255)
    mp = mask.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if seen[row + x]:
                mp[x, y] = 0
    return mask


def process(path: Path) -> str:
    src = Image.open(path).convert("RGB")
    small = src.resize((WORK, WORK), Image.BILINEAR)
    mask = background_mask(small).filter(ImageFilter.MedianFilter(3))
    mask = mask.resize(src.size, Image.BILINEAR).point(lambda v: 255 if v > 127 else 0)
    rgba = src.convert("RGBA")
    rgba.putalpha(mask)
    rgba = rgba.crop(mask.getbbox())
    scale = OUT_SIZE / max(rgba.size)
    size = (max(1, round(rgba.width * scale)), max(1, round(rgba.height * scale)))
    # premultiply so the white background does not bleed into the edges
    rgba = rgba.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    rgba.save(OUT / f"{path.stem}.png")
    return f"{path.stem}  {size[0]}x{size[1]}"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for p in sorted(SRC.glob("*.jpg")):
        print("cut", process(p))


if __name__ == "__main__":
    main()
