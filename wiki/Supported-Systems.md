**English** · [Türkçe](Desteklenen-Sistemler)

# Supported Systems

| System | File types | Core | Core license | BIOS |
|---|---|---|---|---|
| NES / Famicom | `.nes .fds .unf` | FCEUmm | GPLv2 | FDS only: `disksys.rom` |
| SNES / Super Famicom | `.sfc .smc` | Snes9x | non-commercial | — |
| Game Boy | `.gb` | Gambatte | GPLv2 | — |
| Game Boy Color | `.gbc` | Gambatte | GPLv2 | — |
| Game Boy Advance | `.gba` (`.bin` in a GBA folder) | mGBA | MPL 2.0 | optional |
| Sega Mega Drive / Genesis | `.md .gen .smd` (`.bin` in a Mega Drive folder) | Genesis Plus GX | non-commercial | — |
| Sega Master System | `.sms` | Genesis Plus GX | non-commercial | — |
| Sega Game Gear | `.gg` | Genesis Plus GX | non-commercial | — |
| PC Engine / TurboGrafx-16 | `.pce` | Beetle PCE Fast | GPLv2 | — |
| Atari 2600 | `.a26` (`.bin` in an Atari folder) | Stella | GPLv2 | — |
| Neo Geo Pocket / Color | `.ngp .ngc` | Beetle NeoPop | GPLv2 | — |
| PlayStation | `.cue .chd .pbp` | PCSX ReARMed | GPLv2 | **required**, e.g. `scph5501.bin` |
| Arcade | `.zip` in an Arcade / FBNeo / MAME folder | FBNeo | non-commercial | some games |
| Nintendo DS | `.nds` | melonDS DS | GPLv3 | optional (built-in free BIOS) |
| Virtual Boy | `.vb .vboy` | Beetle VB | GPLv2 | — |
| Sega 32X | `.32x` | PicoDrive | non-commercial | — |
| Atari 7800 | `.a78` | ProSystem | GPLv2 | — |
| Atari Lynx | `.lnx` | Handy | zlib | optional: `lynxboot.img` |
| WonderSwan / Color | `.ws .wsc` | Beetle WonderSwan | GPLv2 | — |

## About cores

A **core** is the emulator for one system, a separate library made by the [libretro](https://www.libretro.com/) community. RedoX Gaming does not bundle cores: the right one is downloaded from `buildbot.libretro.com` the first time you start a game on that system, and kept in the `cores/` folder. Each core keeps its own license. "Non-commercial" cores may be used freely in a free app like RedoX Gaming.

## BIOS files

BIOS files come from your own console. Put them in `system/` inside the [data folder](Installation#where-your-data-is). RedoX Gaming never downloads BIOS files.

## Not supported (yet)

Systems whose cores need hardware 3D rendering (Nintendo 64, PSP, Dreamcast…) need extra work in the libretro host and are not supported yet.

## Nintendo DS

Both screens are shown one above the other. The lower one is the touch screen: click it with the mouse, or touch it on a phone or tablet. With a TV remote or a gamepad there is no way to touch it yet, so games that need the touch screen cannot be played that way. melonDS DS brings a free BIOS, so no BIOS files are needed; real DS BIOS / firmware files in `system/` are used when present. DS emulation is heavy: on slow Android TV boxes some games may run below full speed.
