"""Builds every brand file from the Gemini originals in art/brand/.

  art/brand/icon_foreground.jpg  bull head on a fake checkerboard
  art/brand/icon_background.jpg  navy + pixel glow
  art/brand/android_tv_banner.jpg
  art/brand/promo.jpg

Outputs (app/assets/brand/ unless noted):
  icon_foreground.png        bull cut out, 1024, transparent
  android/fg_432.png         adaptive icon foreground (inside the 66% safe zone)
  android/bg_432.png         adaptive icon background
  android/icon_192.png       legacy launcher icon (bg + fg)
  android/tv_banner_320x180.png  Android TV launcher banner
  icon_512.png               app icon (bg + fg), used for the window/taskbar
  icon.ico                   Windows icon (16–256 px)
  splash.png                 1920x1080 boot screen
  app/assets/logo.png, logo_256.png  logo with clean transparent corners
  docs/github_social_1280x640.png, docs/play_feature_1024x500.png

Usage:  python tools/make_brand_assets.py
"""

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "brand"
OUT = ROOT / "app" / "assets" / "brand"
DOCS = ROOT / "docs"

WORK = 1000
CHECKER = (226, 226, 228)     # average colour of the fake checkerboard
SOFT_HI, SOFT_LO = 200, 90    # min(r,g,b): >= HI is background, <= LO is solid


def cut_foreground() -> Image.Image:
    """Removes the baked-in checkerboard. Pixels reachable from the border
    through light pixels get a soft alpha (keeps the flame glow); neutral light
    pixels anywhere (checker seen through gaps) become fully transparent."""
    src = Image.open(ART / "icon_foreground.jpg").convert("RGB").resize((WORK, WORK), Image.LANCZOS)
    w, h = src.size
    px = src.load()

    reach = bytearray(w * h)
    q = deque()

    def light(c):
        return min(c) >= 120

    def push(x, y):
        i = y * w + x
        if not reach[i] and light(px[x, y]):
            reach[i] = 1
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

    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            mn, mx = min(r, g, b), max(r, g, b)
            if mn >= 195 and mx - mn <= 22:
                op[x, y] = (0, 0, 0, 0)
                continue
            # light, washed-out pixels are checker seen through glow even where
            # the border flood cannot reach (inside the fire ring)
            washed = mn >= 120 and mx - mn <= 90
            if not reach[y * w + x] and not washed:
                op[x, y] = (r, g, b, 255)
                continue
            a = (SOFT_HI - mn) / (SOFT_HI - SOFT_LO)
            a = max(0.0, min(1.0, a))
            if a <= 0.02:
                op[x, y] = (0, 0, 0, 0)
                continue
            # un-blend from the checker colour: C = a*F + (1-a)*B
            f = [int(max(0, min(255, (c - (1 - a) * bc) / a))) for c, bc in zip((r, g, b), CHECKER)]
            op[x, y] = (f[0], f[1], f[2], int(a * 255))

    alpha = out.getchannel("A").filter(ImageFilter.MedianFilter(3))
    out.putalpha(alpha)
    return out.crop(alpha.getbbox())


def cut_logo() -> Image.Image:
    """app/assets/logo.jpg has white corners and a light grey anti-aliased rim
    around its rounded square. Flood from the corners through light, greyish
    pixels, then pull the edge in by 2 px so no rim survives."""
    src = Image.open(ROOT / "app" / "assets" / "logo.jpg").convert("RGB")
    w, h = src.size
    px = src.load()
    seen = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if seen[i]:
            return
        c = px[x, y]
        if min(c) >= 100 and max(c) - min(c) <= 45:
            seen[i] = 1
            q.append((x, y))

    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        push(x, y)
    while q:
        x, y = q.popleft()
        if x > 0: push(x - 1, y)
        if x < w - 1: push(x + 1, y)
        if y > 0: push(x, y - 1)
        if y < h - 1: push(x, y + 1)

    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
    out = src.convert("RGBA")
    out.putalpha(alpha)
    return out


def fit(img: Image.Image, size: int, fill: float) -> Image.Image:
    """Centres img on a transparent square so its longest side is size*fill."""
    scale = size * fill / max(img.size)
    im = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
    return canvas


def cover(img: Image.Image, w: int, h: int) -> Image.Image:
    """Scales and centre-crops img to exactly w x h."""
    scale = max(w / img.width, h / img.height)
    im = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left, top = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((left, top, left + w, top + h))


def main():
    (OUT / "android").mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(exist_ok=True)

    logo = cut_logo()
    logo.save(ROOT / "app" / "assets" / "logo.png")
    logo.resize((256, 256), Image.LANCZOS).save(ROOT / "app" / "assets" / "logo_256.png")
    print("logo cut")

    fg = cut_foreground()
    fit(fg, 1024, 0.92).save(OUT / "icon_foreground.png")
    print("foreground cut")

    bg = Image.open(ART / "icon_background.jpg").convert("RGBA")

    # Android adaptive icon: 108dp layers, only the middle 66% is always visible
    fit(fg, 432, 0.60).save(OUT / "android" / "fg_432.png")
    bg.resize((432, 432), Image.LANCZOS).save(OUT / "android" / "bg_432.png")

    def composite(size, fill):
        c = bg.resize((size, size), Image.LANCZOS)
        c.alpha_composite(fit(fg, size, fill))
        return c

    composite(192, 0.80).save(OUT / "android" / "icon_192.png")
    icon512 = composite(512, 0.82)
    icon512.save(OUT / "icon_512.png")
    icon512.save(OUT / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    tv = Image.open(ART / "android_tv_banner.jpg").convert("RGB")
    cover(tv, 320, 180).save(OUT / "android" / "tv_banner_320x180.png")
    cover(tv, 1280, 720).save(OUT / "android" / "tv_banner_1280x720.png")

    promo = Image.open(ART / "promo.jpg").convert("RGB")
    cover(promo, 1280, 640).save(DOCS / "github_social_1280x640.png")
    cover(promo, 1024, 500).save(DOCS / "play_feature_1024x500.png")

    splash = cover(bg.convert("RGB"), 1920, 1080).convert("RGBA")
    dim = Image.new("RGBA", splash.size, (10, 14, 28, 110))
    splash.alpha_composite(dim)
    logo = Image.open(ROOT / "app" / "assets" / "logo.png").convert("RGBA")
    logo = logo.resize((560, 560), Image.LANCZOS)
    splash.alpha_composite(logo, ((1920 - 560) // 2, (1080 - 560) // 2))
    splash.convert("RGB").save(OUT / "splash.png")
    print("done")


if __name__ == "__main__":
    main()
