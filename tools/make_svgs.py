"""Turns the raster icons and logo into pixel-art SVGs.

Each picture is sampled onto a pixel grid, reduced to a small palette and
written as one <path> per colour (horizontal runs merged), with
shape-rendering="crispEdges" so it stays sharp at any size.

  app/assets/systems_hd/*.png  -> app/assets/svg/systems/<id>.svg   (Gemini art)
      (recent, favorites, settings go to app/assets/svg/ui/<id>.svg)
  app/assets/systems/*.png     -> app/assets/svg/pixel/<id>.svg     (32 px icons, exact)
  app/assets/logo.png          -> app/assets/svg/logo.svg
  app/assets/brand/icon_foreground.png -> app/assets/svg/bull.svg
  app/assets/brand/icon_512.png -> app/assets/svg/app_icon.svg     (config/icon)

Windows .ico, Android launcher icons, the TV banner and the splash stay raster:
those formats are required by the platforms.

Usage:  python tools/make_svgs.py
"""

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "app" / "assets"
OUT = ASSETS / "svg"
UI_ICONS = {"recent", "favorites", "settings"}   # interface icons, not systems


def to_grid(img: Image.Image, grid: int, colors: int, denoise: bool = False) -> Image.Image:
    """Samples img onto grid x grid pixels with at most `colors` colours.
    denoise: smooth JPEG noise first so flat areas stay flat."""
    img = img.convert("RGBA")
    if denoise:
        a = img.getchannel("A")
        img = img.convert("RGB").filter(ImageFilter.MedianFilter(5)).convert("RGBA")
        img.putalpha(a)
    if img.width != grid:
        img = img.resize((grid, round(img.height * grid / img.width)), Image.BOX)
    alpha = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    rgb.paste(img.convert("RGB"), mask=alpha)
    if colors:
        rgb = rgb.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def write_svg(img: Image.Image, dest: Path, size: int) -> int:
    """One path per colour; returns the file size."""
    w, h = img.size
    px = img.load()
    runs = {}
    for y in range(h):
        x = 0
        while x < w:
            r, g, b, a = px[x, y]
            if a == 0:
                x += 1
                continue
            start = x
            while x < w and px[x, y] == (r, g, b, a):
                x += 1
            runs.setdefault("#%02x%02x%02x" % (r, g, b), []).append(f"M{start} {y}h{x - start}v1h-{x - start}z")
    parts = [f'<path fill="{c}" d="{"".join(d)}"/>' for c, d in sorted(runs.items(), key=lambda kv: -len(kv[1]))]
    out_h = round(size * h / w)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{out_h}" '
           f'viewBox="0 0 {w} {h}" shape-rendering="crispEdges">' + "".join(parts) + "</svg>\n")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(svg, encoding="utf-8")
    return len(svg)


def main():
    for p in sorted((ASSETS / "systems_hd").glob("*.png")):
        folder = "ui" if p.stem in UI_ICONS else "systems"
        n = write_svg(to_grid(Image.open(p), 96, 48, denoise=True), OUT / folder / f"{p.stem}.svg", 512)
        print(f"{folder}/{p.stem}.svg  {n // 1024} KB")
    for p in sorted((ASSETS / "systems").glob("*.png")):
        n = write_svg(to_grid(Image.open(p), 32, 0), OUT / "pixel" / f"{p.stem}.svg", 256)
        print(f"pixel/{p.stem}.svg  {n // 1024} KB")
    n = write_svg(to_grid(Image.open(ASSETS / "logo.png"), 192, 64), OUT / "logo.svg", 512)
    print(f"logo.svg  {n // 1024} KB")
    n = write_svg(to_grid(Image.open(ASSETS / "brand" / "icon_foreground.png"), 160, 64), OUT / "bull.svg", 512)
    print(f"bull.svg  {n // 1024} KB")
    n = write_svg(to_grid(Image.open(ASSETS / "brand" / "icon_512.png"), 128, 64), OUT / "app_icon.svg", 512)
    print(f"app_icon.svg  {n // 1024} KB")


if __name__ == "__main__":
    main()
