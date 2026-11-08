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

## About cores

A **core** is the emulator for one system, a separate library made by the [libretro](https://www.libretro.com/) community. RedoX Gaming does not bundle cores: the right one is downloaded from `buildbot.libretro.com` the first time you start a game on that system, and kept in the `cores/` folder. Each core keeps its own license. "Non-commercial" cores may be used freely in a free app like RedoX Gaming.

## BIOS files

BIOS files come from your own console. Put them in `system/` inside the [data folder](Installation#where-your-data-is). RedoX Gaming never downloads BIOS files.

## Not supported (yet)

Systems whose cores need hardware 3D rendering (Nintendo 64, Nintendo DS, PSP, Dreamcast…) need extra work in the libretro host and are not on the first roadmap.
