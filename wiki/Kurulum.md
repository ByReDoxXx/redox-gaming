[English](Installation) · **Türkçe**

# Kurulum

## Windows 10 / 11 (x64)

1. **[Releases](https://github.com/ByReDoxXx/redox-gaming/releases)** sayfasından `RedoXGaming-windows-x64.zip` dosyasını indirin.
2. Zip'i istediğiniz yere açın, örneğin `C:\Oyunlar\RedoX Gaming`.
3. `RedoXGaming.exe`'yi çalıştırın. `redox_core.windows.template_release.x86_64.dll` aynı klasörde kalmalı; emülatör köprüsü odur.
4. Uygulama kod imzalı olmadığı için Windows SmartScreen "bilinmeyen yayıncı" uyarısı verebilir. **Ek bilgi → Yine de çalıştır**'ı seçin.

Kurulum programı ve yönetici izni gerekmez. Kaldırmak için klasörü silmeniz yeterli (isterseniz aşağıdaki veri klasörünü de).

## Linux (x64)

1. **[Releases](https://github.com/ByReDoxXx/redox-gaming/releases)** sayfasından `RedoXGaming-<sürüm>-linux-x64.tar.gz` dosyasını indirin.
2. Açın: `tar -xzf RedoXGaming-*-linux-x64.tar.gz -C ~/Oyunlar/RedoX`
3. `./RedoXGaming.x86_64`'ü çalıştırın. `libredox_core.linux.template_release.x86_64.so` yanında kalmalı.

## Android TV / Android telefon (arm64 ya da 32 bit ARM)

1. Releases sayfasından `RedoXGaming-<sürüm>-android.apk` dosyasını indirin.
2. **Telefon:** APK'yı açın ve bu kaynaktan kuruluma izin verin.
   **Android TV:** APK'yı bir USB belleğe kopyalayıp dosya yöneticisiyle açın ya da *Send files to TV* gibi bir uygulamayla gönderin; o uygulama için "bilinmeyen kaynaklar"a izin verin.
3. TV'de RedoX Gaming uygulamalar listesindedir. USB bellekten kendi oyunlarınızı eklemek için sorulduğunda "tüm dosyalara erişim" izni verin.

Android sürümü yeni: cihazınızda çalışmayan bir şey olursa lütfen [bildirin](https://github.com/ByReDoxXx/redox-gaming/issues).

## Sistem gereksinimleri

| | En az |
|---|---|
| Ekran kartı | OpenGL 3.3 (Windows/Linux), OpenGL ES 3.0 (Android) |
| İşlemci | son ~10 yılın herhangi bir 64 bit işlemcisi; PlayStation biraz daha fazlasını ister |
| Disk | uygulama için ~120 MB, ayrıca çekirdekler (her biri 1–10 MB) ve oyunlarınız |
| İnternet | yalnızca ücretsiz mağaza, kapak resimleri ve her sistemin ilk açılışı için |

## İlk açılış

- Ana ekranda **platform carousel**'i görürsünüz. ◀ ▶ ile sistem seçin, **A / Enter** ile açın.
- Bir sistemde ilk kez oyun başlattığınızda RedoX Gaming o sistemin **emülatör çekirdeğini** indirir (birkaç MB, bir kez). Sonrasında o sistem internetsiz çalışır.
- Her şeyi hemen deneyebilmeniz için küçük bir test oyunu, **REDOX TEST** (NES), pakette gelir: A'ya basılı tutunca renk değişir ve bir ses çalar.

## Verileriniz nerede

| İşletim sistemi | Klasör |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\RedoX Gaming\` |
| Linux | `~/.local/share/godot/app_userdata/RedoX Gaming/` |
| Android | uygulamanın özel depolama alanı |

İçinde: `roms/` (indirilen oyunlar), `saves/` (pil kayıtları), `states/` (durum kayıtları), `system/` (BIOS dosyaları), `cores/`, `covers/`. İlerlemenizi korumak için `saves/` ve `states/` klasörlerini yedekleyin.
