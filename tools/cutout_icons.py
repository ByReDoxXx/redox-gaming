"""Cuts the Gemini system icons (art/gemini/<id>.jpg) out of their fake
checkerboard background and glow, and writes app/assets/systems_hd/<id>.png.

Every icon has a dark navy outline. Everything outside that outline that can
be reached from the image border without crossing a dark pixel is background.

Also cuts the interface icons (recent, favorites, settings) the same way.

Usage:  python tools/cutout_icons.py [id ...]   (no ids: every picture)
"""

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "gemini"
OUT = ROOT / "app" / "assets" / "systems_hd"
WORK = 1000          # mask is computed at this size
OUT_SIZE = 512
DARK = 70            # max(r, g, b) at or below this is "outline" (a wall)
HOLES = {"ps1": [(0.5, 0.5)], "settings": [(0.5, 0.5)]}   # extra see-through areas inside the outline
# icons whose fake checkerboard has black squares: dark pixels that are not blue-tinted are background,
# the navy outline (blue-tinted) is still a wall
BLACK_CHECKER = {"arcade"}
# icons on a plain white background: only near-white pixels are background, so
# coloured parts behind a gap in the outline stay
WHITE_BG = {"nds", "32x", "vb", "a78", "lynx", "ws",
            "chip8", "coleco", "dinothawr", "doom", "gw", "intv", "jnb", "lowres", "microw8", "o2", "pcecd", "pokemini", "quake", "rick", "segacd", "sg1000", "sv", "tic80", "uzebox", "vectrex", "a5200", "arduboy", "cave", "sbw"}
HOLES["vb"] = [(0.309, 0.822)]   # inside the tripod leg
HOLES["o2"] = [(0.39, 0.695), (0.443, 0.815), (0.417, 0.785)]   # inside the joystick cable
HOLES["a5200"] = [(0.6, 0.748), (0.495, 0.8), (0.843, 0.705), (0.877, 0.63)]   # cable loops
HOLES["sbw"] = [(0.595, 0.367)]   # under the grey cat
HOLES["tic80"] = [(0.718, 0.695)]   # inside the keyboard cable
HOLES["uzebox"] = [(0.545, 0.83), (0.347, 0.807), (0.422, 0.797), (0.28, 0.772)]   # cable loops


def is_white(c):
    return min(c) >= 222 and max(c) - min(c) <= 24


def background_mask(img, extra_seeds, black_checker=False, white_bg=False):
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        c = px[x, y]
        if white_bg:
            ok = is_white(c)
        else:
            ok = max(c) > DARK or (black_checker and c[2] <= c[0] + 6)
        if not seen[i] and ok:
            seen[i] = 1
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    for fx, fy in extra_seeds:
        push(int(fx * w), int(fy * h))

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


def process(path):
    sid = path.stem
    src = Image.open(path).convert("RGB")
    small = src.resize((WORK, WORK), Image.BILINEAR)
    mask = background_mask(small, HOLES.get(sid, []), sid in BLACK_CHECKER, sid in WHITE_BG)
    # drop single stray pixels, then scale the mask back up
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = mask.resize(src.size, Image.BILINEAR).point(lambda v: 255 if v > 127 else 0)

    rgba = src.convert("RGBA")
    rgba.putalpha(mask)
    bbox = mask.getbbox()
    rgba = rgba.crop(bbox)

    side = int(max(rgba.size) * 1.06)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2))
    # premultiply so the background colour does not bleed into the edges
    canvas = canvas.convert("RGBa").resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS).convert("RGBA")
    canvas.save(OUT / f"{sid}.png")
    return sid


def main():
    import sys
    OUT.mkdir(parents=True, exist_ok=True)
    ids = set(sys.argv[1:])
    for p in sorted(SRC.glob("*.jpg")):
        if not ids or p.stem in ids:
            print("cut", process(p))


if __name__ == "__main__":
    main()
