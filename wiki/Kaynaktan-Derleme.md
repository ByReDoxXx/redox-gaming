[English](Building-from-Source) · **Türkçe**

# Kaynaktan Derleme

Aşağıda kısa anlatım var; bütün ayrıntılar [docs/TEKNIK.md → Derleme](https://github.com/ByReDoxXx/redox-gaming/blob/main/docs/TEKNIK.md#derleme) bölümünde.

## 1. Araçlar

- **Godot 4.7.x** (standart sürüm) ve ona uygun **export şablonları**
- **Python 3.8+** ve **SCons**: `pip install scons`
- Bir C++ derleyici: **Visual Studio 2022 Build Tools** (Windows), **GCC/Clang** (Linux), **Android NDK** (Android)

## 2. Kodu alın

```bash
git clone --recursive https://github.com/ByReDoxXx/redox-gaming.git
cd redox-gaming
```

`--recursive`, `extension/godot-cpp` alt modülünü de indirir. Unuttuysanız: `git submodule update --init`.

## 3. Emülatör köprüsünü (GDExtension) derleyin

```bash
cd extension
scons platform=windows target=template_debug      # editör için
scons platform=windows target=template_release    # dışa aktarılan sürüm için
```

Linux'ta `platform=linux`, Android için `platform=android arch=arm64` kullanın. Türkçe Windows'ta önce `PYTHONUTF8=1` ayarlayın (yoksa SCons, MSVC'nin Türkçe mesajlarında çöker). Kütüphane `app/bin/<platform>/` içine yazılır.

## 4. Çalıştırın

`app/` klasörünü Godot'da açıp **F5**'e basın. İlk oyunda çekirdek otomatik iner. Geliştirme için çekirdekleri önceden de indirebilirsiniz:

```bash
python tools/fetch_cores.py windows
```

## 5. Dışa aktarın

```bash
godot --headless --path app --export-release "Windows Desktop" ../build/windows/RedoXGaming.exe
```

`RedoXGaming.exe`'yi `redox_core.windows.template_release.x86_64.dll` ile birlikte dağıtın.

## 6. Test edin

```bash
godot --headless --path app -s res://tests/smoke_test.gd
godot --headless --path app res://tests/services_test.tscn
```

Her şey yolundaysa ikisi de `RESULT: PASS` yazar. İkincisi internet ister.
