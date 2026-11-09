**English** · [Türkçe](Kaynaktan-Derleme)

# Building from Source

Short version below; every detail is in [docs/TECHNICAL.md → Building](https://github.com/ByReDoxXx/redox-gaming/blob/main/docs/TECHNICAL.md#building).

## 1. Tools

- **Godot 4.7.x** (standard edition) and the matching **export templates**
- **Python 3.8+** and **SCons**: `pip install scons`
- A C++ compiler: **Visual Studio 2022 Build Tools** (Windows), **GCC/Clang** (Linux), **Android NDK** (Android)

## 2. Get the code

```bash
git clone --recursive https://github.com/ByReDoxXx/redox-gaming.git
cd redox-gaming
```

`--recursive` also fetches the submodules `extension/godot-cpp` and `extension/rcheevos` (RetroAchievements). Forgot it? Run `git submodule update --init`.

## 3. Build the emulator bridge (GDExtension)

```bash
cd extension
scons platform=windows target=template_debug      # for the editor
scons platform=windows target=template_release    # for exported builds
```

Use `platform=linux` on Linux, `platform=android arch=arm64` and `arch=arm32` for Android (many Android TVs run a 32-bit system). On a non-English Windows set `PYTHONUTF8=1` first. The library lands in `app/bin/<platform>/`.

## 4. Run

Open the `app/` folder in Godot and press **F5**. On the first game start the core is downloaded automatically. For development you can also pre-download cores:

```bash
python tools/fetch_cores.py windows
```

## 5. Export

```bash
godot --headless --path app --export-release "Windows Desktop" ../build/windows/RedoXGaming.exe
```

Ship `RedoXGaming.exe` together with `redox_core.windows.template_release.x86_64.dll`.

## 6. Test

```bash
godot --headless --path app -s res://tests/smoke_test.gd
godot --headless --path app res://tests/services_test.tscn
```

Both print `RESULT: PASS` when everything works. The second one needs internet.

## 7. Automatic builds (GitHub Actions)

Every push builds Windows, Linux and Android on GitHub (`.github/workflows/build.yml`); the packages are under the run's **Artifacts**. Pushing a version tag publishes a release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

For a stable Android signature add the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD` (details in [docs/TECHNICAL.md](https://github.com/ByReDoxXx/redox-gaming/blob/main/docs/TECHNICAL.md#continuous-integration)).
