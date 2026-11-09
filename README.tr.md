<p align="center">
  <img src="docs/github_social_1280x640.png" alt="RedoX Gaming" width="100%">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Türkçe</b>
</p>

# RedoX Gaming

**Windows, Linux, Android TV ve Android telefon için ücretsiz ve açık kaynak retro oyun oynatıcı.**
TV kumandası ve gamepad için tasarlanmış pixel art arayüz; arkasında yıllardır test edilen
[libretro](https://www.libretro.com/) emülatör çekirdekleri ve [Godot 4](https://godotengine.org/) motoru var.

- Tek uygulamada 43 sistem: NES, SNES, Game Boy / Color / Advance, Nintendo DS, Mega Drive, Sega CD, 32X, PlayStation, PC Engine, Atari 2600 / 5200 / 7800 / Lynx, Arcade ve daha fazlası; ayrıca ücretsiz oyun motorları (DOOM, Quake, Cave Story) ve fantezi konsollar (TIC-80, LowRes NX)
- **Ücretsiz oyun mağazası:** yasal bir homebrew oyun seçin, kendiliğinden iner ve başlar
- **Kendi oyunlarınız:** bir klasör ya da USB bellek ekleyin, kapak resimleri otomatik bulunur
- **İhtiyaç anında çekirdek:** bir sistemi ilk açtığınızda doğru emülatör çekirdeği bir kez indirilir
- **Kaldığın yerden devam**, resimli 4 kayıt slotu, pil kayıtları
- **Geri sarma** ve **hızlı ileri**, CRT / LCD / yumuşak görüntü filtreleri
- **Hileler:** kendi kodlarınız ya da libretro hile veritabanından tek tıkla
- **RetroAchievements:** eski oyunlarda başarım kazanın (normal ve zor mod)
- **Son oynananlar, favoriler, oynama süresi,** arama ve sıralama
- **Ayarlar:** Türkçe / İngilizce, ses, gamepad ve klavye tuş atama, görüntü boyutu
- Telefon ve tablet için ekran gamepad'i, menü sesleri, yeni sürüm bildirimi
- Ana ekranda hareketli uzay arka planı: kayan yıldızlar, yıldız kaymaları ve küçük uzay savaşları: gemiler UFO'ları kovalayıp vurur, asteroitler parçalanır ya da birbirine çarpar
- Her şey bir yön tuşu ve iki düğmeyle kullanılabilir

> RedoX Gaming ticari oyun **içermez ve indirmez**. Ücretsiz homebrew oyunları ya da yasal yoldan edindiğiniz kendi oyun dosyalarınızı oynarsınız.

---

## Ekran görüntüleri

| Ana ekran: platform carousel | Ücretsiz oyunlar |
|---|---|
| ![Ana ekran](docs/preview_home.png) | ![Mağaza](docs/preview_store.png) |
| **Oyun detayı → İndir ve oyna** | **Kapak resimleriyle Oyunlarım** |
| ![Detay](docs/preview_detail.png) | ![Oyunlarım](docs/preview_mine.png) |
| **Duraklatma menüsü** | **İndirilen bir SNES homebrew oyunu çalışırken** |
| ![Duraklatma](docs/preview_pause.png) | ![SNES](docs/preview_snes_astrohawk.png) |

---

## İndirme

En son sürüm **[Releases](../../releases)** sayfasında.

| Platform | Durum |
|---|---|
| Windows 10/11 (x64) | ✅ `RedoXGaming-<sürüm>-windows-x64.zip`: zip'i açın, `RedoXGaming.exe`'yi çalıştırın |
| Linux (x64) | ✅ `RedoXGaming-<sürüm>-linux-x64.tar.gz`: açın, `RedoXGaming.x86_64`'ü çalıştırın |
| Android TV / Android telefon (arm64 + 32 bit armeabi-v7a) | 🧪 `RedoXGaming-<sürüm>-android.apk`: APK'yı kurun ("bilinmeyen kaynaklar"a izin verin); henüz az cihazda denendi |

Gereksinimler: OpenGL 3.3 destekleyen ekran kartı (son ~12 yılın her kartı). İnternet yalnızca ücretsiz mağaza, kapak resimleri ve ilk çekirdek indirmesi için gerekir.

## Desteklenen sistemler

| Sistem | Dosyalar | Çekirdek (otomatik iner) | Ücretsiz oyun |
|---|---|---|---|
| NES / Famicom | `.nes .fds .unf` | FCEUmm | ✅ 82 |
| SNES / Super Famicom | `.sfc .smc` | Snes9x | ✅ 14 |
| Game Boy | `.gb` | Gambatte | ✅ |
| Game Boy Color | `.gbc` | Gambatte | ✅ 8 |
| Game Boy Advance | `.gba` | mGBA | ✅ 88 |
| Sega Mega Drive / Genesis | `.md .gen .smd` (Mega Drive klasöründe `.bin`) | Genesis Plus GX | ✅ 62 |
| Sega Master System | `.sms` | Genesis Plus GX | ✅ 65 |
| Sega Game Gear | `.gg` | Genesis Plus GX | — |
| PC Engine / TurboGrafx-16 | `.pce` | Beetle PCE Fast | — |
| Atari 2600 | `.a26` (Atari klasöründe `.bin`) | Stella | ✅ 24 |
| Neo Geo Pocket (Color) | `.ngp .ngc` | Beetle NeoPop | — |
| PlayStation | `.cue .chd .pbp` (BIOS gerekir) | PCSX ReARMed | — |
| Arcade | Arcade/FBNeo klasöründe `.zip` | FBNeo | — |
| Nintendo DS | `.nds` (dokunmatik ekran: fare ya da parmak) | melonDS DS | — |
| Virtual Boy | `.vb .vboy` | Beetle VB | — |
| Sega 32X | `.32x` | PicoDrive | — |
| Atari 7800 | `.a78` | ProSystem | — |
| Atari Lynx | `.lnx` | Handy | — |
| WonderSwan / Color | `.ws .wsc` | Beetle WonderSwan | — |
| SG-1000 | `.sg` | Genesis Plus GX | — |
| Vectrex | `.vec` | VecX | ✅ 40 |
| Pokémon Mini | `.min` | PokeMini | ✅ 1 |
| Game & Watch | `.mgw` | Game & Watch (gw) | — |
| Watara Supervision | `.sv` | Potator | — |
| TIC-80 (fantezi konsol) | `.tic` | TIC-80 | ✅ 12 |
| DOOM (motor) | `.wad` (Freedoom, shareware ya da kendi DOOM.WAD'ınız) | PrBoom | ✅ 2 |
| Cave Story | `Doukutsu.exe`'nin bulunduğu klasör | NXEngine | ✅ 1 |
| Quake | `id1/pak0.pak` | TyrQuake | ✅ 1 (shareware) |
| Rick Dangerous | Rick klasöründe `.zip` | xrick | ✅ 1 |
| Dinothawr | Dinothawr klasöründe `.game` | Dinothawr | ✅ 2 |
| Jump 'n Bump | Jump 'n Bump klasöründe `.dat` | Jump 'n Bump | ✅ bölüm paketi |
| Super Bros War | Super Bros War klasöründe `.game` | Super Bros War | ✅ 1 (Super Cat Wars LITE) |
| Arduboy | Arduboy klasöründe `.hex` | Arduous | ✅ 1 |
| CHIP-8 / SCHIP / XO-CHIP | `.ch8 .sc8 .xo8` | JAXE | ✅ 95 |
| Uzebox | `.uze` | Uzem | ✅ 2 |
| LowRes NX | `.nx` | LowRes NX | ✅ 100 |
| MicroW8 | `.uw8` | MicroW8 | ✅ 2 |
| Sega CD / Mega CD | Sega CD klasöründe `.cue .chd .iso` (BIOS gerekli) | Genesis Plus GX | — |
| PC Engine CD | PC Engine CD klasöründe `.cue .chd .ccd` (BIOS gerekli) | Beetle PCE Fast | — |
| ColecoVision | `.col .cv` (Coleco klasöründe `.rom .bin`; BIOS gerekli) | Gearcoleco | ✅ 101 |
| Intellivision | `.int` (Intellivision klasöründe `.bin .rom`; BIOS gerekli) | FreeIntv | ✅ 1 |
| Atari 5200 | `.a52` (5200 klasöründe `.bin`) | a5200 | — |
| Odyssey² / Videopac | Odyssey2 klasöründe `.bin` (BIOS gerekli) | O2EM | — |

**BIOS dosyaları:** "BIOS gerekli" yazan sistemlerde oyunu açınca hangi dosyanın eksik olduğu gösterilir. BIOS'u oyunlarınızın yanına koyup o klasörü ekleyin (ya da `system` klasörüne kopyalayın): RedoX Gaming oyun klasörlerinizdeki bilinen BIOS dosyalarını bulur ve çekirdeklerin baktığı yere kopyalar. BIOS dosyalarını asla indirmez.

## Kontroller

| İşlem | Klavye | Gamepad |
|---|---|---|
| Gezinme / seçme | Yön tuşları | Yön tuşu veya sol çubuk |
| Menüde onay | `Enter` | alt düğme (Xbox A / PlayStation ✕) |
| Menüde geri | `Esc` / Android geri | sağ düğme (Xbox B / ○) |
| Oyunda **A** | `X` | sağ düğme |
| Oyunda **B** | `Z` | alt düğme |
| Oyunda **X / Y** | `S` / `A` | üst / sol düğme |
| Oyunda L / R | `Q` / `W` | LB / RB |
| Oyunda Start / Select | `Enter` / `Shift` | Start / Back (View) |
| Sekme değiştir | `Q` / `E` | LB / RB |
| Favori / ara / sırala | `F` / `/` / `O` | X / Y / Select |
| Son oyuna devam · ayarlar (ana ekran) | `C` · `S` | Y · Start |
| Geri sar (basılı tut) | `R` | LT / L2 |
| Hızlı ileri (basılı tut) | `Boşluk` | RT / R2 |
| Oyun içi menü | `Esc` | Select + Start ya da Guide |
| Hızlı kaydet / yükle (slot 1) | `F2` / `F4` | oyun içi menü |

Oyun içindeki düğmeler SNES düzenine **konuma göre** eşlenir; oyunun A'sı her zaman sağdaki düğmedir. Bütün tuşlar **Ayarlar → Kontroller**'den değiştirilebilir. Ayrıntılar wiki'de: [Kullanım](../../wiki/Kullanim), [RetroAchievements](../../wiki/RetroAchievements-TR).

## Kendi oyunlarınızı ekleme

1. Bir sistemi açın → **+ KLASÖR EKLE** → bir klasör, USB bellek ya da ağ paylaşımı seçin.
2. Alt klasörler de taranır; dosyalar yerinde kalır, hiçbir şey kopyalanmaz.
3. Dosya adı No-Intro adıyla eşleşirse (örn. `Super Mario Bros. (World).nes`) kapak resmi [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails)'ten iner.

Dosyaları uygulamanın ROM klasörüne de kopyalayabilirsiniz: Windows'ta `%APPDATA%\Godot\app_userdata\RedoX Gaming\roms\<sistem>\`.

## Ücretsiz oyunlar

**ÜCRETSİZ OYUNLAR** sekmesi [Retrobrews](https://retrobrews.github.io)'teki homebrew oyunları listeler: eski konsollar için yapılmış ve geliştiricilerinin paylaştığı yeni oyunlar. Retrobrews listedeki her oyunun paylaşımına sahibinin izin verdiğini belirtir; RedoX Gaming her oyunda geliştiriciyi ve kaynağı gösterir.

TIC-80, Vectrex, Pokémon Mini, DOOM, Cave Story, Quake, Rick Dangerous, Dinothawr, Jump 'n Bump, Super Bros War, Arduboy, CHIP-8, Uzebox, LowRes NX, MicroW8 ve Intellivision için sekme, libretro'nun kendi içerik indiricisindeki ücretsiz dağıtılabilen oyunları (TIC-80 kartuşları, hak sahibinin ücretsiz yaptığı Vectrex oyunları, DOOM'un shareware bölümü, Cave Story) ve [Freedoom](https://freedoom.github.io)'u gösterir. ColecoVision oyunları Retrobrews'tan gelir.

## Kaynaktan derleme

```bash
git clone --recursive https://github.com/ByReDoxXx/redox-gaming.git
cd redox-gaming/extension
scons platform=windows target=template_release     # ya da: platform=linux
```

Ardından `app/` klasörünü Godot 4.7 ile açıp **F5**'e basın ya da hazır çıktı ayarıyla dışa aktarın.
Ayrıntılı anlatım, Linux ve Android: **[docs/TEKNIK.md](docs/TEKNIK.md#derleme)** ve **[Wiki](../../wiki/Ana-Sayfa)**.

## Dokümanlar

| | Türkçe | English |
|---|---|---|
| Teknik doküman | [docs/TEKNIK.md](docs/TEKNIK.md) | [docs/TECHNICAL.md](docs/TECHNICAL.md) |
| Tasarım sistemi | | [docs/DESIGN.md](docs/DESIGN.md) |
| Wiki (kurulum, kullanım, SSS, derleme) | [Wiki → Ana Sayfa](../../wiki/Ana-Sayfa) | [Wiki → Home](../../wiki) |

## Yol haritası

- [x] libretro host (görüntü, ses, giriş, durum kaydı, pil kayıtları)
- [x] Pixel art TV arayüzü, platform carousel, duraklatma menüsü
- [x] Ücretsiz homebrew mağazası, klasör/USB ekleme, kapak resimleri, ihtiyaç anında çekirdek
- [x] Windows sürümü
- [x] Ayarlar ekranı: dil, tuş atama, görüntü boyutu, CRT / LCD filtreleri
- [x] Favoriler, son oynananlar, oynama süresi, arama ve sıralama
- [x] Geri sarma, hızlı ileri, 4 kayıt slotu, kaldığın yerden devam
- [x] Hileler (kendi kodlarınız + libretro hile veritabanı), RetroAchievements
- [x] Linux sürümü, Android APK, ekran üstü dokunmatik kontroller, GitHub Actions ile otomatik derleme
- [ ] Android TV'de daha çok cihazda test, TV başlatıcı afişi
- [ ] Linux AppImage / Flatpak
- [ ] Netplay, ses gecikmesi ayarı, donanım çizimli çekirdekler (N64, PSP, Dreamcast)
- [ ] Nintendo DS dokunmatik ekranı için TV kumandası / gamepad ile ekran imleci

## Yasal bilgiler

**RedoX Gaming nedir?** RedoX Gaming, [libretro](https://www.libretro.com/) emülatör çekirdekleri için ücretsiz ve ticari olmayan bir oynatıcıdır. İçinde hiçbir oyun, BIOS ya da konsol üreticisine ait kod yoktur. Emülatörler yasal yazılımlardır; önemli olan oyunların nereden geldiğidir.

**Oyunlar ve BIOS dosyaları.**
- RedoX Gaming hiçbir zaman ticari oyun ya da BIOS dosyası sunmaz, bağlantı vermez ve indirmez.
- Yalnızca kullanma hakkınız olan oyun ve BIOS dosyalarını kullanın; örneğin yasalarınızın izin verdiği ölçüde, sahip olduğunuz kartuş, disk ya da konsoldan kendinizin aldığı kopyalar. Eklediğiniz dosyaların sorumluluğu size aittir.
- BIOS gereken sistemler (PlayStation, Sega CD, PC Engine CD, ColecoVision, Intellivision, Odyssey²) hangi dosyanın eksik olduğunu gösterir; RedoX Gaming yalnızca zaten sizde olan BIOS dosyalarını kopyalar.

**Mağazadaki ücretsiz oyunlar.** RedoX Gaming hiçbir oyunu kendi sunucusunda barındırmaz. ÜCRETSİZ OYUNLAR sekmesi her oyunu doğrudan asıl kaynağından indirir ve kaynağı oyun sayfasında gösterir:
- [Retrobrews](https://retrobrews.github.io): geliştiricisinin paylaşımına izin verdiği homebrew oyunlar.
- [libretro içerik indiricisi](https://buildbot.libretro.com/assets/cores/): RetroArch'ın kendisinin sunduğu ücretsiz dağıtılabilen oyunlar; DOOM ve Quake'in shareware bölümleri, Cave Story (freeware), hak sahibinin ücretsiz yaptığı Vectrex kütüphanesi, TIC-80, Arduboy, CHIP-8, Uzebox, LowRes NX ve MicroW8 homebrew oyunları gibi.
- [Freedoom](https://freedoom.github.io): BSD lisanslı, ücretsiz bir DOOM oyunu.

Mağazadaki bir oyunun hak sahibiyseniz ve kaldırılmasını istiyorsanız lütfen [bir issue açın](../../issues); oyun listeden çıkarılır.

**Emülatör çekirdekleri.** Çekirdekler bir sistemi ilk açtığınızda [libretro buildbot](https://buildbot.libretro.com/)'tan indirilir; uygulamayla birlikte dağıtılmaz. Her çekirdeğin kendi lisansı vardır (aşağıya bakın). Bazı çekirdekler (Snes9x, Genesis Plus GX, PicoDrive, FBNeo) yalnızca ticari olmayan kullanıma izin verir; bu yüzden RedoX Gaming ücretsizdir ve ücretsiz kalacaktır.

**Çevrim içi servisler.** RedoX Gaming'de hesap, reklam ya da kullanım takibi yoktur. Yalnızca şunlara bağlanır: libretro buildbot (çekirdekler ve ücretsiz oyunlar), libretro-thumbnails (kapak görselleri), Retrobrews ve GitHub (ücretsiz oyun listesi, hileler, Freedoom, yeni sürüm kontrolü) ve giriş yaparsanız kendi kullanım koşulları geçerli olan [RetroAchievements](https://retroachievements.org). RetroAchievements anahtarınız yalnızca cihazınızda saklanır.

**Ticari markalar.** Konsol ve oyun adları yalnızca uyumluluğu belirtmek için kullanılır. Tüm ticari markalar sahiplerine aittir. RedoX Gaming; Nintendo, Sega, Sony, NEC, Atari, SNK, Bandai, Mattel, Coleco, Philips/Magnavox, id Software ya da başka bir şirketle bağlantılı değildir ve onlar tarafından desteklenmez. Sistem simgeleri resmi logolar değil, özgün çizimlerdir.

**Garanti yoktur.** RedoX Gaming, GPL v3'te yazdığı gibi "olduğu gibi" ve hiçbir garanti olmadan sunulur.

## Lisans

RedoX Gaming **GNU General Public License v3.0** ile lisanslanmıştır; bkz. [LICENSE](LICENSE).

Üçüncü taraf parçalar kendi lisanslarını korur:

| Bileşen | Lisans |
|---|---|
| [godot-cpp](https://github.com/godotengine/godot-cpp) | MIT |
| [libretro.h](https://github.com/libretro/libretro-common) | MIT |
| libretro çekirdekleri (çalışırken iner, pakete dahil değil) | kendi lisansları: çoğu GPL, Snes9x / Genesis Plus GX / PicoDrive / FBNeo için ticari olmayan kullanım |
| [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P), [VT323](https://fonts.google.com/specimen/VT323) | SIL Open Font License |
| Ücretsiz oyun listesi ve ekran görüntüleri | [Retrobrews](https://retrobrews.github.io) ve her oyunun geliştiricisi |
| Diğer ücretsiz oyunlar (TIC-80, Vectrex, DOOM, Quake, Cave Story ve diğerleri) | [libretro içerik indiricisi](https://buildbot.libretro.com/assets/cores/) ve her oyunun geliştiricisi, [Freedoom](https://freedoom.github.io) (BSD) |
| Kapak resimleri | [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails) |

Ticari markalar, oyun kaynakları ve çevrim içi servisler için [Yasal bilgiler](#yasal-bilgiler) bölümüne bakın.
