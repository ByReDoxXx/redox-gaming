[English](Supported-Systems) · **Türkçe**

# Desteklenen Sistemler

| Sistem | Dosya türleri | Çekirdek | Çekirdek lisansı | BIOS |
|---|---|---|---|---|
| NES / Famicom | `.nes .fds .unf` | FCEUmm | GPLv2 | yalnızca FDS: `disksys.rom` |
| SNES / Super Famicom | `.sfc .smc` | Snes9x | ticari olmayan kullanım | — |
| Game Boy | `.gb` | Gambatte | GPLv2 | — |
| Game Boy Color | `.gbc` | Gambatte | GPLv2 | — |
| Game Boy Advance | `.gba` (GBA klasöründe `.bin`) | mGBA | MPL 2.0 | isteğe bağlı |
| Sega Mega Drive / Genesis | `.md .gen .smd` (Mega Drive klasöründe `.bin`) | Genesis Plus GX | ticari olmayan kullanım | — |
| Sega Master System | `.sms` | Genesis Plus GX | ticari olmayan kullanım | — |
| Sega Game Gear | `.gg` | Genesis Plus GX | ticari olmayan kullanım | — |
| PC Engine / TurboGrafx-16 | `.pce` | Beetle PCE Fast | GPLv2 | — |
| Atari 2600 | `.a26` (Atari klasöründe `.bin`) | Stella | GPLv2 | — |
| Neo Geo Pocket / Color | `.ngp .ngc` | Beetle NeoPop | GPLv2 | — |
| PlayStation | `.cue .chd .pbp` | PCSX ReARMed | GPLv2 | **gerekli**, örn. `scph5501.bin` |
| Arcade | Arcade / FBNeo / MAME klasöründe `.zip` | FBNeo | ticari olmayan kullanım | bazı oyunlar |
| Nintendo DS | `.nds` | melonDS DS | GPLv3 | isteğe bağlı (yerleşik ücretsiz BIOS) |
| Virtual Boy | `.vb .vboy` | Beetle VB | GPLv2 | — |
| Sega 32X | `.32x` | PicoDrive | ticari olmayan kullanım | — |
| Atari 7800 | `.a78` | ProSystem | GPLv2 | — |
| Atari Lynx | `.lnx` | Handy | zlib | isteğe bağlı: `lynxboot.img` |
| WonderSwan / Color | `.ws .wsc` | Beetle WonderSwan | GPLv2 | — |

## Çekirdekler hakkında

**Çekirdek**, tek bir sistemin emülatörüdür; [libretro](https://www.libretro.com/) topluluğunun yaptığı ayrı bir kütüphanedir. RedoX Gaming çekirdekleri pakete koymaz: bir sistemde ilk kez oyun başlattığınızda doğru çekirdek `buildbot.libretro.com`'dan indirilir ve `cores/` klasöründe saklanır. Her çekirdek kendi lisansını korur. "Ticari olmayan kullanım" lisanslı çekirdekler, RedoX Gaming gibi ücretsiz bir uygulamada serbestçe kullanılabilir.

## BIOS dosyaları

BIOS dosyaları kendi konsolunuzdan gelir. Onları [veri klasöründeki](Kurulum#verileriniz-nerede) `system/` klasörüne koyun. RedoX Gaming asla BIOS indirmez.

## (Henüz) desteklenmeyenler

Çekirdekleri donanımsal 3B çizim isteyen sistemler (Nintendo 64, PSP, Dreamcast…) libretro host'ta ek çalışma gerektirir ve henüz desteklenmiyor.

## Nintendo DS

İki ekran üst üste gösterilir. Alttaki dokunmatik ekrandır: fareyle tıklayın ya da telefon / tablette parmağınızla dokunun. TV kumandası ya da gamepad ile henüz dokunulamıyor; dokunmatik ekran isteyen oyunlar bu şekilde oynanamaz. melonDS DS ücretsiz bir BIOS ile gelir, BIOS dosyası gerekmez; `system/` içinde gerçek DS BIOS / firmware dosyaları varsa onlar kullanılır. DS emülasyonu ağırdır: yavaş Android TV kutularında bazı oyunlar tam hızın altında çalışabilir.
