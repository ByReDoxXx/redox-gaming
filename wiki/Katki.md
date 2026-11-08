[English](Contributing) · **Türkçe**

# Katkı

Yardımınız için teşekkürler! RedoX Gaming GPLv3 lisanslıdır; katkılar da aynı lisansla kabul edilir.

## Hata bildirme

Bir [issue](https://github.com/ByReoxXx/redox-gaming/issues) açıp şunları yazın:

- işletim sisteminiz ve RedoX Gaming sürümü,
- sistem ve oyun (bir homebrew adı; asla ROM dosyası ya da indirme bağlantısı değil),
- ne yaptığınız, ne beklediğiniz, ne olduğu,
- kayıt dosyası: [veri klasöründeki](Kurulum#verileriniz-nerede) `logs/godot.log`.

## Pull request

1. Depoyu fork'layın, bir dal açın, değişiklikleri odaklı tutun.
2. [Tasarım sistemine](https://github.com/ByReoxXx/redox-gaming/blob/main/docs/DESIGN.md) uyun: renkler ve boyutlar `app.gd`'den gelir, her yeni ekran yön tuşu + A/B ile kullanılabilmeli.
3. İki testi de çalıştırın (`smoke_test` ve `services_test`); ikisi de `RESULT: PASS` yazmalı.
4. Neyi değiştirdiğinizi ve nasıl test ettiğinizi anlatın.

## Kurallar

- Hiçbir yerde ticari ROM, BIOS dosyası ya da bunlara bağlantı olmaz: kodda, issue'larda, ekran görüntülerinde.
- Yeni ücretsiz oyun kaynakları yeniden dağıtıma izin vermeli.
- Çekirdekler çalışırken indirilir, depoya eklenmez.

## Sistem ekleme

Bkz. [Teknik doküman → Genişletme](https://github.com/ByReoxXx/redox-gaming/blob/main/docs/TEKNIK.md#9-genişletme): `App.SYSTEMS`'e bir kayıt, klasör ipuçları, kapak klasörü, bir çizim ve isteğe bağlı bir ücretsiz oyun kaynağı.
