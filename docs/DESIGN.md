# RedoX Gaming — Design System

Made with ui-ux-pro-max (style: **Pixel Art**, fonts: **Press Start 2P + VT323**).
The colours come from the RedoX logo instead of the skill's generic red/blue/green.
Tokens live in `app/scripts/app.gd`. Change them there, not in individual screens.

## Platform first
TV first, then desktop, then phone. Base canvas is **1920×1080** (`canvas_items` stretch, `expand`).
- Everything must work with a **D-pad and A/B only**. No feature may need a mouse or touch.
- TV safe area: **96 px** on the sides, **54 px** top and bottom (5%).
- Pixel art is only drawn at **whole-number scales** (system icons are 32 px: 64 = 2×, 128 = 4×).

## Colour tokens
| Token | Hex | Use |
|---|---|---|
| `bg` | `#0A0E1C` | screen background |
| `surface` | `#141A2E` | cards, panels |
| `surface_hi` | `#1F2742` | raised / hovered surface |
| `line` | `#2A3352` | resting borders |
| `fire_red` | `#E0301E` | brand, "REDOX" word |
| `fire_orange` | `#FF7A1A` | secondary brand, pressed |
| `gold` | `#FFC23D` | **focus ring**, headings |
| `text` | `#F5E6C8` | body text (15.6:1 on `bg`) |
| `muted` | `#A3A9C2` | secondary text (8.6:1 on `bg`) |

Each system also has an **accent** (see `SYSTEMS` in `app.gd`, preview in `docs/system_icons.png`).
An accent is never the only way to tell systems apart. The icon and the name always appear with it.

## Type
| Role | Font | Size (1080p) |
|---|---|---|
| Wordmark / screen title | Press Start 2P | 32 |
| Labels, buttons, card titles | Press Start 2P | 16–24 |
| Body / meta / hints | VT323 | 32–40 |

Press Start 2P sizes stay on its 8 px grid (8, 16, 24, 32…).

## Shapes and effects
- Square corners. Borders are 4 px, or 6 px when focused.
- **Hard shadow** under a focused element: offset 8 px, black at 60%, no blur.
- No gradients, blur or glass effects. The only "glow" is the logo.

## Focus (the most important state on TV)
- A focused element gets a **gold 6 px border**, the hard shadow, and lifts **8 px** in 100 ms.
- A focused element must never be clipped. Scroll areas keep 24 px of padding for the lift.
- A selected tab (not focused) shows its accent as the border and as an 8 px bar under it.

## Motion
Kept to 100–150 ms on focus and lift. Screens change with a cut, not a slide; this matches the retro style and keeps TVs responsive.

## Screens
1. **Home**: RedoX logo centred at the top, then the **platform carousel**:
   - the selected platform is shown large (360 px) on a pixel pedestal, with a stepped glow in its accent colour;
   - 2 neighbours on each side get smaller and fainter (scale 0.58 / 0.40, opacity 0.55 / 0.22);
   - the list wraps around; it slides in 180 ms (cubic ease-out) and **never rotates on its own**;
   - left/right arrows are visible and clickable, plus D-pad, mouse wheel and swipe;
   - platform name in its accent colour, game count, and position dots underneath.
2. **Games**: accent bar on top, header (back button, platform icon, name, count, small logo), 5-column game grid, empty state that names the file types and the ROM folder.
   B / Esc / Android back returns to Home **on the same platform**.
3. **Player**: game picture at whole-number scale on black; pause menu uses the same panel style over a 75% scrim.

Platform illustrations: `art/gemini/*.jpg` (Gemini, generated from the logo) → `python tools/cutout_icons.py` → `app/assets/systems_hd/*.png` (512 px, linear + mipmaps).

## Controls shown on screen
`◀ ▶` choose platform · `A` open / play · `B` back · `SELECT+START` pause menu in a game.

## Brand files
Originals from Gemini live in `art/brand/`; `python tools/make_brand_assets.py` builds everything else.

| File | Used for |
|---|---|
| `app/assets/brand/icon_512.png` | app / window / taskbar icon (`config/icon`) |
| `app/assets/brand/icon.ico` | Windows exe icon (`config/windows_native_icon`), 16–256 px |
| `app/assets/brand/splash.png` | boot screen, 1920×1080 |
| `app/assets/brand/android/fg_432.png` + `bg_432.png` | Android adaptive launcher icon (bull inside the 66% safe zone) |
| `app/assets/brand/android/icon_192.png` | Android legacy launcher icon |
| `app/assets/brand/android/tv_banner_320x180.png` | Android TV launcher banner |
| `docs/github_social_1280x640.png` | GitHub repo social preview |
| `docs/play_feature_1024x500.png` | Play Store feature graphic |

## Vector assets (SVG)
`python tools/make_svgs.py` turns the raster art into pixel-art SVGs (one `<path>` per colour, `crispEdges`):
`app/assets/svg/logo.svg`, `bull.svg`, `app_icon.svg` (`config/icon`), `systems/*.svg` (platform illustrations, 96 px grid), `pixel/*.svg` (the original 32 px icons).
The app loads only these SVGs. Windows `.ico`, Android launcher icons, the TV banner and the splash stay PNG/ICO because the platforms require raster files.

## Online services (autoloads)
| Autoload | Job |
|---|---|
| `Net` | HTTP downloads with progress |
| `Cores` | finds libretro cores; downloads a missing one once from buildbot.libretro.com |
| `Library` | the player's games: `user://roms/<system>/`, loose files, and added folders (USB, NAS) scanned in place |
| `Catalog` | free homebrew list from Retrobrews (gamelist.xml per system, cached 24 h), install = ROM + screenshot + metadata |
| `Covers` | box art for the player's own games from libretro-thumbnails (title match, USA > World > Europe > Japan) |

Platform screen tabs: **OYUNLARIM** (own games) · **ÜCRETSİZ OYUNLAR** (store) · **+ KLASÖR EKLE**.
Store flow: card → detail dialog (screenshot, developer, year, players, description, source) → **İNDİR VE OYNA** → progress → core download on first use → game starts.
