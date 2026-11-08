[English](Installation) · **Türkçe**

# Kurulum

## Windows 10 / 11 (x64)

1. **[Releases](https://github.com/ByReDoxXx/redox-gaming/releases)** sayfasından `RedoXGaming-windows-x64.zip` dosyasını indirin.
2. Zip'i istediğiniz yere açın, örneğin `C:\Oyunlar\RedoX Gaming`.
3. `RedoXGaming.exe`'yi çalıştırın. `redox_core.windows.template_release.x86_64.dll` aynı klasörde kalmalı; emülatör köprüsü odur.
4. Uygulama kod imzalı olmadığı için Windows SmartScreen "bilinmeyen yayıncı" uyarısı verebilir. **Ek bilgi → Yine de çalıştır**'ı seçin.

Kurulum programı ve yönetici izni gerekmez. Kaldırmak için klasörü silmeniz yeterli (isterseniz aşağıdaki veri klasörünü de).

## Linux (x64)

Paketli sürüm yolda. O zamana kadar [kaynaktan derleyebilirsiniz](Kaynaktan-Derleme).

## Android TV / Android telefon

Bir sonraki sürümde (APK) gelecek. Arayüz zaten TV kumandasına göre tasarlandı.

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
