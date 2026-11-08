"""Draws the 32x32 pixel-art system icons for RedoX Gaming.

Generic hardware drawings (controllers, handhelds, a disc, a cabinet), no
official logos. Output:
  app/assets/systems/<id>.png   32x32, scaled in Godot with nearest filter
  docs/system_icons.png         preview sheet

Usage:  python tools/make_system_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUTLINE = (10, 14, 28, 255)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x, y, w, h, c):
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=hexc(c))

    def oval(self, x, y, w, h, c):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=hexc(c))

    def px(self, x, y, c):
        self.img.putpixel((x, y), hexc(c))

    def clear(self, x, y, w=1, h=1):
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=(0, 0, 0, 0))

    def btn(self, x, y, c):
        """3x3 button with a 1px shine."""
        self.rect(x, y, 3, 3, c)
        r, g, b, _ = hexc(c)
        self.img.putpixel((x, y), (min(255, r + 70), min(255, g + 70), min(255, b + 70), 255))

    def dpad(self, cx, cy, c):
        self.rect(cx - 3, cy - 1, 6, 2, c)
        self.rect(cx - 1, cy - 3, 2, 6, c)

    def done(self):
        """Adds the dark 1px outline around the shape."""
        src = self.img.copy()
        w, h = src.size
        for y in range(h):
            for x in range(w):
                if src.getpixel((x, y))[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] != 0:
                        self.img.putpixel((x, y), OUTLINE)
                        break
        return self.img


def nes():
    i = Icon()
    i.rect(15, 4, 2, 5, "#3a3a3a")                 # cable
    i.rect(2, 9, 28, 14, "#c8c8cc")                # body
    i.rect(3, 10, 26, 1, "#ececf0")                # highlight
    i.rect(4, 12, 24, 9, "#2e2e33")                # face
    i.rect(5, 13, 9, 7, "#46464d")
    i.dpad(9, 16, "#111114")
    i.rect(15, 17, 2, 1, "#8a8a90")                # select / start
    i.rect(18, 17, 2, 1, "#8a8a90")
    i.btn(21, 15, "#e0301e")
    i.btn(25, 15, "#e0301e")
    return i.done()


def snes():
    i = Icon()
    i.rect(4, 9, 8, 2, "#7c3aed")                  # shoulders
    i.rect(20, 9, 8, 2, "#7c3aed")
    i.oval(2, 10, 14, 13, "#d5d5de")
    i.oval(16, 10, 14, 13, "#d5d5de")
    i.rect(9, 11, 14, 11, "#d5d5de")
    i.rect(7, 11, 18, 1, "#ededf3")
    i.dpad(9, 16, "#333338")
    i.rect(13, 18, 2, 1, "#8b8b95")
    i.rect(16, 18, 2, 1, "#8b8b95")
    i.btn(22, 11, "#3b82f6")
    i.btn(26, 15, "#ef4444")
    i.btn(22, 19, "#eab308")
    i.btn(18, 15, "#22c55e")
    return i.done()


def handheld(body, bezel, screen, buttons, colour_screen=False):
    i = Icon()
    i.rect(7, 2, 18, 28, body)
    i.rect(8, 3, 16, 1, "#ffffff40".replace("40", "") if False else body)
    i.clear(23, 29, 2, 1)
    i.clear(24, 28, 1, 1)
    i.rect(9, 4, 14, 11, bezel)
    i.rect(11, 6, 10, 7, screen)
    if colour_screen:
        i.rect(12, 10, 3, 2, "#ef4444")
        i.rect(16, 8, 2, 4, "#3b82f6")
        i.rect(11, 12, 10, 1, "#22c55e")
    else:
        i.rect(12, 10, 3, 2, "#306230")
        i.rect(16, 8, 2, 4, "#306230")
        i.rect(11, 12, 10, 1, "#0f380f")
    i.px(10, 5, "#ef4444")                         # power led
    i.dpad(12, 20, "#222226")
    i.btn(17, 21, buttons)
    i.btn(21, 17, buttons)
    i.rect(13, 25, 2, 1, "#6b6b70")
    i.rect(16, 25, 2, 1, "#6b6b70")
    for x in (19, 21, 23):
        i.rect(x, 26, 1, 3, "#8a8678" if not colour_screen else "#0f766e")
    return i.done()


def gb():
    return handheld("#c9c6b8", "#4a4a5a", "#8bac0f", "#8b1e4b")


def gbc():
    return handheld("#14b8a6", "#1f2937", "#fde68a", "#1f2937", colour_screen=True)


def gba():
    i = Icon()
    i.rect(3, 8, 6, 1, "#4338ca")
    i.rect(23, 8, 6, 1, "#4338ca")
    i.oval(1, 9, 12, 15, "#6366f1")
    i.oval(19, 9, 12, 15, "#6366f1")
    i.rect(7, 9, 18, 15, "#6366f1")
    i.rect(10, 10, 12, 11, "#1e1b4b")
    i.rect(11, 11, 10, 9, "#a5f3fc")
    i.rect(12, 16, 4, 3, "#22c55e")
    i.rect(17, 13, 2, 2, "#f97316")
    i.dpad(6, 16, "#1e1b4b")
    i.btn(22, 18, "#e0e7ff")
    i.btn(26, 14, "#e0e7ff")
    return i.done()


def md():
    i = Icon()
    i.rect(15, 3, 2, 6, "#2a2a2e")
    i.oval(1, 8, 30, 17, "#1c1c20")
    i.rect(6, 9, 20, 1, "#3a3a40")
    i.oval(4, 12, 9, 9, "#3a3a40")
    i.dpad(8, 16, "#0d0d10")
    i.rect(14, 11, 4, 2, "#2563eb")               # start
    i.btn(16, 18, "#2563eb")
    i.btn(21, 15, "#2563eb")
    i.btn(24, 12, "#2563eb")
    return i.done()


def sms():
    i = Icon()
    i.rect(15, 4, 2, 5, "#2a2a2e")
    i.rect(3, 9, 26, 14, "#1c1c20")
    i.rect(5, 10, 22, 1, "#f97316")
    i.dpad(9, 16, "#6a6a72")
    i.btn(18, 15, "#f97316")
    i.btn(23, 15, "#f97316")
    i.rect(16, 20, 10, 1, "#3a3a40")
    return i.done()


def gg():
    i = Icon()
    i.oval(1, 8, 10, 17, "#1f1f23")
    i.oval(21, 8, 10, 17, "#1f1f23")
    i.rect(5, 8, 22, 17, "#1f1f23")
    i.rect(9, 9, 14, 14, "#0b0b0f")
    i.rect(11, 11, 10, 10, "#0ea5e9")
    i.rect(12, 17, 8, 3, "#22c55e")
    i.rect(14, 13, 3, 3, "#fde047")
    i.dpad(5, 16, "#3f3f46")
    i.btn(22, 18, "#0ea5e9")
    i.btn(26, 14, "#0ea5e9")
    i.rect(25, 10, 2, 2, "#0ea5e9")
    return i.done()


def pce():
    i = Icon()
    i.rect(10, 5, 12, 7, "#f59e0b")                # HuCard
    i.rect(11, 6, 10, 2, "#fde68a")
    i.rect(4, 10, 24, 15, "#e5e7eb")
    i.rect(4, 10, 24, 4, "#374151")
    i.rect(8, 11, 16, 2, "#111827")
    i.rect(6, 17, 8, 1, "#9ca3af")
    i.rect(6, 19, 8, 1, "#9ca3af")
    i.rect(6, 21, 8, 1, "#9ca3af")
    i.rect(20, 19, 5, 3, "#111827")
    return i.done()


def a26():
    i = Icon()
    i.oval(12, 3, 8, 7, "#2a2a2e")
    i.rect(15, 9, 2, 12, "#2a2a2e")
    i.rect(5, 20, 22, 9, "#1a1a1e")
    i.rect(6, 21, 20, 1, "#3a3a40")
    i.rect(5, 25, 22, 2, "#a16207")
    i.rect(7, 17, 5, 3, "#dc2626")
    i.rect(8, 16, 3, 1, "#dc2626")
    return i.done()


def ngp():
    i = Icon()
    i.oval(1, 9, 12, 15, "#d946ef")
    i.oval(19, 9, 12, 15, "#d946ef")
    i.rect(7, 9, 18, 15, "#d946ef")
    i.rect(11, 10, 11, 11, "#1f1f23")
    i.rect(12, 11, 9, 9, "#d9f99d")
    i.rect(13, 15, 3, 3, "#3f6212")
    i.rect(17, 13, 2, 5, "#3f6212")
    i.oval(3, 13, 7, 7, "#1f1f23")
    i.rect(5, 15, 3, 3, "#6b6b70")
    i.btn(22, 18, "#1f1f23")
    i.btn(26, 14, "#1f1f23")
    return i.done()


def ps1():
    i = Icon()
    i.oval(2, 2, 28, 28, "#cbd5e1")
    i.oval(5, 5, 22, 22, "#e2e8f0")
    i.oval(10, 10, 12, 12, "#94a3b8")
    i.oval(13, 13, 6, 6, "#64748b")
    i.clear(15, 15, 2, 2)
    # rainbow shine
    for n, c in enumerate(["#ef4444", "#eab308", "#22c55e", "#3b82f6"]):
        i.rect(7 + n, 21 - n, 2, 1, c)
        i.rect(21 - n, 7 + n, 2, 1, c)
    i.rect(8, 7, 3, 1, "#ffffff")
    i.rect(7, 8, 1, 3, "#ffffff")
    return i.done()


def arcade():
    i = Icon()
    i.rect(8, 2, 16, 28, "#9d174d")
    i.rect(9, 3, 14, 4, "#facc15")
    i.rect(11, 4, 10, 2, "#f97316")
    i.rect(9, 8, 14, 10, "#0f172a")
    i.rect(11, 10, 3, 3, "#22d3ee")
    i.rect(17, 13, 3, 3, "#ef4444")
    i.rect(10, 16, 12, 1, "#1e293b")
    i.rect(6, 19, 20, 3, "#ec4899")
    i.rect(10, 16, 1, 3, "#111114")
    i.rect(9, 15, 3, 2, "#ef4444")
    i.rect(16, 20, 2, 1, "#facc15")
    i.rect(19, 20, 2, 1, "#facc15")
    i.rect(9, 22, 14, 8, "#be185d")
    i.rect(14, 24, 1, 2, "#facc15")
    i.rect(17, 24, 1, 2, "#facc15")
    return i.done()


def all_games():
    i = Icon()
    for x, y, c in ((5, 5, "#e0301e"), (17, 5, "#ff7a1a"), (5, 17, "#ffc23d"), (17, 17, "#f5e6c8")):
        i.rect(x, y, 10, 10, c)
        i.rect(x + 1, y + 1, 8, 1, "#ffffff")
    return i.done()


ICONS = [
    ("all", "TÜMÜ", all_games, "#ffc23d"),
    ("nes", "NES", nes, "#e0301e"),
    ("snes", "SNES", snes, "#8b5cf6"),
    ("gb", "GAME BOY", gb, "#84a90f"),
    ("gbc", "GB COLOR", gbc, "#14b8a6"),
    ("gba", "GB ADVANCE", gba, "#6366f1"),
    ("md", "MEGA DRIVE", md, "#2563eb"),
    ("sms", "MASTER SYS", sms, "#f97316"),
    ("gg", "GAME GEAR", gg, "#0ea5e9"),
    ("pce", "PC ENGINE", pce, "#f59e0b"),
    ("a26", "ATARI 2600", a26, "#a16207"),
    ("ngp", "NEO POCKET", ngp, "#d946ef"),
    ("ps1", "PLAYSTATION", ps1, "#94a3b8"),
    ("arcade", "ARCADE", arcade, "#ec4899"),
]


def main():
    out_dir = ROOT / "app" / "assets" / "systems"
    out_dir.mkdir(parents=True, exist_ok=True)
    rendered = []
    for sid, name, fn, accent in ICONS:
        img = fn()
        img.save(out_dir / f"{sid}.png")
        rendered.append((name, img, accent))

    # preview sheet
    scale, cols, cell_w, cell_h = 6, 7, 240, 290
    rows = (len(rendered) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w + 40, rows * cell_h + 40), hexc("#0a0e1c"))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(ROOT / "app/assets/fonts/PressStart2P-Regular.ttf"), 14)
    for n, (name, img, accent) in enumerate(rendered):
        cx = 20 + (n % cols) * cell_w
        cy = 20 + (n // cols) * cell_h
        d.rectangle([cx + 8, cy + 8, cx + cell_w - 8, cy + cell_h - 8], fill=hexc("#141a2e"), outline=hexc(accent), width=4)
        big = img.resize((32 * scale, 32 * scale), Image.NEAREST)
        sheet.alpha_composite(big, (cx + (cell_w - big.width) // 2, cy + 22))
        tw = d.textlength(name, font=font)
        d.text((cx + (cell_w - tw) / 2, cy + cell_h - 52), name, font=font, fill=hexc("#f5e6c8"))
    docs = ROOT / "docs"
    docs.mkdir(exist_ok=True)
    sheet.save(docs / "system_icons.png")
    print("wrote", len(rendered), "icons and docs/system_icons.png")


if __name__ == "__main__":
    main()
