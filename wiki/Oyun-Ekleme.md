[English](Adding-Games) · **Türkçe**

# Oyun Ekleme

RedoX Gaming zaten sahip olduğunuz oyun dosyalarını oynatır: kendi kartuş ve disklerinizden aldığınız kopyalar ya da homebrew oyunlar. Ticari oyun asla indirmez.

## Yol 1: Klasör ekleme (önerilen)

1. Ana ekranda bir sistemi açın.
2. **+ KLASÖR EKLE**'yi seçin.
3. Bir klasör seçin: Belgeler, USB bellek, harici disk ya da ağ paylaşımı.
4. RedoX Gaming klasörü **alt klasörleriyle birlikte** tarar ve kaç oyun bulduğunu gösterir. Dosyalar yerinde kalır, hiçbir şey kopyalanmaz.

İstediğiniz kadar klasör ekleyebilirsiniz. Bir klasörde her sistemin oyunu olabilir; her dosya kendiliğinden doğru sisteme gider.

## Yol 2: Dosyaları uygulamaya kopyalama

Dosyaları [veri klasöründeki](Kurulum#verileriniz-nerede) `roms/<sistem>/` içine kopyalayın, örneğin `roms/snes/`. Sistem klasör adları: `nes snes gb gbc gba vb nds md 32x sms gg pce a26 a78 lynx ngp ws ps1 arcade`.

## Sistemler nasıl tanınır

| | Kural |
|---|---|
| Belirgin uzantılar | `.nes` → NES, `.sfc/.smc` → SNES, `.gba` → GBA, … (bkz. [Desteklenen Sistemler](Desteklenen-Sistemler)) |
| Ortak uzantılar | `.bin` ve `.zip` birden çok sistemde kullanıldığı için yalnızca adı sistemi belli eden bir klasördeyse sayılır: `Mega Drive`, `Genesis`, `MD`, `Atari 2600`, `2600`, `GBA`, `Arcade`, `MAME`, `FBNeo` |
| Yok sayılanlar | diğer her şey (`.txt`, resimler, kayıtlar) |

## Kapak resimleri

Kendi oyunlarınızın kapakları [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails)'ten otomatik iner. Dosya adları **No-Intro** adlandırmasına uyduğunda en iyi sonucu verir:

| Dosya adı | Kapak |
|---|---|
| `Super Mario Bros. (World).nes` | ✅ bulunur |
| `Legend of Zelda, The (USA).nes` | ✅ bulunur (`, The` anlaşılır) |
| `smb1_final_v2.nes` | ❌ yerine sistemin çizimi görünür |

Birden çok bölgenin kapağı varsa sırasıyla ABD, Dünya, Avrupa, Japonya tercih edilir. Yalnızca resim indirilir, asla oyun indirilmez.

## PlayStation BIOS'u

PlayStation oyunları kendi konsolunuzdan alınmış bir BIOS dosyası ister (örneğin `scph5501.bin`). Onu [veri klasöründeki](Kurulum#verileriniz-nerede) `system/` klasörüne koyun.
