**English** · [Türkçe](Kurulum)

# Installation

## Windows 10 / 11 (x64)

1. Open **[Releases](https://github.com/ByReDoxXx/redox-gaming/releases)** and download `RedoXGaming-windows-x64.zip`.
2. Unzip it anywhere, for example `C:\Games\RedoX Gaming`.
3. Run `RedoXGaming.exe`. Keep `redox_core.windows.template_release.x86_64.dll` in the same folder; it is the emulator bridge.
4. Windows SmartScreen may warn about an unknown publisher because the app is not code-signed. Choose **More info → Run anyway**.

No installer, no admin rights. To remove it, delete the folder (and, if you like, the data folder below).

## Linux (x64)

1. Download `RedoXGaming-<version>-linux-x64.tar.gz` from **[Releases](https://github.com/ByReDoxXx/redox-gaming/releases)**.
2. Unpack it: `tar -xzf RedoXGaming-*-linux-x64.tar.gz -C ~/Games/RedoX`
3. Run `./RedoXGaming.x86_64`. Keep `libredox_core.linux.template_release.x86_64.so` next to it.

## Android TV / Android phone (arm64 or 32-bit ARM)

1. Download `RedoXGaming-<version>-android.apk` from Releases.
2. **Phone:** open the APK and allow installing from this source.
   **Android TV:** copy the APK to a USB stick and open it with a file manager, or send it with an app such as *Send files to TV*; allow "unknown sources" for that app.
3. On TV, RedoX Gaming is in the app list (Apps). To add your own games from a USB stick, allow "access to all files" when asked.

The Android build is new: please [report](https://github.com/ByReDoxXx/redox-gaming/issues) anything that does not work on your device.

## System requirements

| | Minimum |
|---|---|
| Graphics | OpenGL 3.3 (Windows/Linux), OpenGL ES 3.0 (Android) |
| CPU | any 64-bit CPU from the last ~10 years; PlayStation needs a bit more |
| Disk | ~120 MB for the app, plus cores (1–10 MB each) and your games |
| Internet | only for the free store, box art and the first start of each system |

## First start

- The home screen shows the **platform carousel**. Use ◀ ▶ to pick a system, **A / Enter** to open it.
- The first time you start a game on a system, RedoX Gaming downloads that system's **emulator core** (a few MB, once). After that the system works offline.
- A tiny test game, **REDOX TEST** (NES), is included so you can try everything right away: hold A and the colour changes, and a tone plays.

## Where your data is

| OS | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\RedoX Gaming\` |
| Linux | `~/.local/share/godot/app_userdata/RedoX Gaming/` |
| Android | the app's private storage |

Inside: `roms/` (downloaded games), `saves/` (battery saves), `states/` (save states), `system/` (BIOS files), `cores/`, `covers/`. Back up `saves/` and `states/` to keep your progress.
