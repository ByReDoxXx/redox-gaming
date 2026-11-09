**English** · [Türkçe](Oyun-Ekleme)

# Adding Games

RedoX Gaming plays game files you already have: dumps of your own cartridges and discs, or homebrew. It never downloads commercial games.

## Option 1: Add a folder (recommended)

1. Open a system on the home screen.
2. Choose **+ KLASÖR EKLE** (add folder).
3. Pick a folder: your Documents, a USB stick, an external disk or a network share.
4. RedoX Gaming scans it **and all sub-folders** and shows how many games it found. Files stay where they are; nothing is copied.

You can add as many folders as you like. One folder can hold games for every system; each file goes to the right system automatically.

## Option 2: Copy files into the app

Copy files into `roms/<system>/` inside the [data folder](Installation#where-your-data-is), for example `roms/snes/`. System folder names: `nes snes gb gbc gba vb nds md 32x sms gg pce a26 a78 lynx ngp ws ps1 arcade`.

## How systems are recognised

| | Rule |
|---|---|
| Clear extensions | `.nes` → NES, `.sfc/.smc` → SNES, `.gba` → GBA, … (see [Supported Systems](Supported-Systems)) |
| Shared extensions | `.bin` and `.zip` are used by several systems, so they only count inside a folder whose name tells the system: `Mega Drive`, `Genesis`, `MD`, `Atari 2600`, `2600`, `GBA`, `Arcade`, `MAME`, `FBNeo` |
| Ignored | anything else (`.txt`, images, saves) |

## Box art

For your own games, box art is downloaded automatically from [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails). It works best when your file names follow **No-Intro** naming:

| File name | Box art |
|---|---|
| `Super Mario Bros. (World).nes` | ✅ found |
| `Legend of Zelda, The (USA).nes` | ✅ found (the `, The` is understood) |
| `smb1_final_v2.nes` | ❌ shows the system illustration instead |

When several regions exist, the USA cover is preferred, then World, Europe, Japan. Only pictures are downloaded, never games.

## PlayStation BIOS

PlayStation games need a BIOS file from your own console (for example `scph5501.bin`). Put it in the `system/` folder inside the [data folder](Installation#where-your-data-is).
