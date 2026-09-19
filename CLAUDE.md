# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Altyapı (2026-09-19 devrinden sonra — ÖNCE BUNU OKU)

Oyun Zuhal Müzik'e devredildi. Kod, yayın ve veritabanı artık şirketin hesaplarında;
geliştirme dış geliştiricide (Anıl Emre Gümüş) devam ediyor.

| Katman | Nerede |
|---|---|
| Depo | `toftamars/Zuhal-Game` (eski `anilemregumuss-cyber/Zuhal-Game` DEĞİL) |
| Yayın | **Vercel** — `main`'e her push otomatik yayınlanır (~25 sn). GitHub Pages ARTIK ASIL YOL DEĞİL |
| Canlı adres | https://zuhal-game.vercel.app |
| Veritabanı | Supabase projesi `zuhal-oyun` → `https://cglwmzrsbzuirlwgfxqc.supabase.co` |

⚠️ **Eski yayın adresi `anilemregumuss-cyber.github.io/Zuhal-Game/` ÖLÜ (404).**
Depo devrinde GitHub depo adresini yönlendirir ama **yayın adresini yönlendirmez**.
Sahada QR'lı kupon dolaşırken devir/adres değişikliği yapılacaksa önce eski adrese
yönlendirme sayfası konmalı.

🔴 **Supabase panel yetkisi YOK, gerek de yok.** Şema/RPC/migration işleri `anil`
veritabanı kullanıcısıyla **doğrudan bağlantıdan** yapılır:

```bash
source .env && psql "$ZUHAL_OYUN_DB_URL" -f supabase/<dosya>.sql
```

🔴 **POOLER adresi kullanilir, dogrudan adres DEGIL** (olculdu 19 Eyl):
`db.cglwmzrsbzuirlwgfxqc.supabase.co` yalnizca **IPv6 (AAAA)** kaydina sahip, IPv4 kaydi
**yok**. IPv6'si olmayan aglarda (Windows'ta yaygin) `could not translate host name`
hatasi verir ve bu bir yapilandirma hatasi degil, adresin kendisidir. Dogrusu:

```
postgresql://anil.cglwmzrsbzuirlwgfxqc:<sifre>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
```

- Kullanici adi **proje referansini de icerir**: `anil.cglwmzrsbzuirlwgfxqc` (duz `anil` DEGIL).
- **Port 5432 = session modu** — migration/DDL icin dogru olan budur. 6543 transaction
  modudur, uygulama sorgulari icindir.
- ⚠️ `aws-1-eu-central-1...` bu projeye ait DEGIL (`tenant/user not found` doner). Bolge
  ayni olsa da pooler dugumu projeye gore degisir; tahmin etme, hata mesajindan ayirt et:
  *"password authentication failed"* = dogru dugum, *"tenant/user not found"* = yanlis dugum.

Şifre depoya GİRMEZ (depo herkese açık) — yerelde gizli dosyada tutulur.
Yerel geliştirme: `supabase start` buluta hiç dokunmadan tam kopya verir.
**Disiplin:** her şema değişikliği önce `supabase/` altında bir `.sql` dosyası
olarak depoya girer, sonra uygulanır — veritabanında ne yapıldığı depodan okunsun.

## Git Kuralları

- **Her zaman `main` branch üzerinde çalış ve push et.** Feature branch kullanma.
- Her değişiklikten sonra: `git add <dosya>`, `git commit -m "..."`, `git push origin main`
- Commit mesajları Türkçe olabilir.
- Push = yayın. `main`'e giden her şey birkaç saniye içinde canlıya çıkar.

## Proje Özeti

32" dokunmatik mağaza ekranı için HTML oyunu: **`index.html`**
(müşterinin telefonunda açılan kupon sayfası ayrı: **`k.html`**)

Zuhal Müzik 50. Yıl — Rhythm Challenge. Müşteriler Whitney Houston parçası çalarken snare vuruşunu tam zamanında yaparak indirim/ödül kazanıyor.

## Dosya Yapısı

```
index.html                  ← Kiosk uygulaması (tüm CSS + JS burada, ses artık harici)
k.html                      ← Müşterinin telefonunda açılan kupon sayfası (QR bunu gösterir)
Genel-Halftime-v3.mp4       ← Ana sayfa banner videosu (autoplay, muted, loop) — dikey 1080x1920, 9.6 sn, 12.9 MB
zuhal-muzik.wav             ← Banner arka plan müziği (dokunuşla aç/kapat)
whitney-halftime.mp3        ← Oyun içi Whitney Houston parçası (fetch + Web Audio API decode)
zuhal-fifty-year-black.jpg  ← Oyun ekranı logosu (filter:invert(1) ile beyaza çevrilmiş)
```

**Kasıtlı olarak tutulan eski banner videoları** (hiçbir yerden referans verilmiyor,
ama SILME — kampanyaya geri dönülürse tekrar kullanılacak, sahibi öyle karar verdi):

```
Genel-Halftime.mp4          ← v1, yatay 832x464, 1.1 MB
Genel-Halftime-v2.mp4       ← v2, dikey 480x848 (WhatsApp sıkıştırmalı), 1.55 MB
```

**Kiosk / PWA dosyaları:**

```
manifest.json               ← display:fullscreen — ana ekrana eklenince adres çubuğusuz açılır
icon-192.png / icon-512.png ← PWA ikonları (kodın ürettiği sarı davul markı, maskable uyumlu)
```

Kiosk tarayıcı uygulaması KULLANMA — Chrome motorundan çıkıldığında veya WebView'da
MIDI izin diyaloğu karşılanmadığında SPD::One görünmez olur. Tam ekran için
`manifest.json` (ana ekrana ekle) + `initKioskFullscreen()` (ilk dokunuşta
Fullscreen API, `navigationUI:"hide"`) kullanılır.

`zuhal-fifty-year-black.jpg` **iki yerde** kullanılıyor: kioskta `filter:invert(1)`
ile beyaza çevriliyor, `k.html`'de ise beyaz zemine olduğu gibi basılıyor (siyah logo
yazdırmaya da uygun). Logoyu değiştirirken iki tarafı da kontrol et.

Repoda bu 5 medya dosyası dışında hiçbir medya kullanılmıyor — yeni bir görsel/video eklerken önce `index.html` içinde gerçekten referans verildiğinden emin ol, aksi halde Vercel deploy boyutu şişer.

## index.html Mimarisi

Tüm uygulama tek HTML dosyasında, 3 katman:

### Sayfa 1 — Banner (`.banner`)
- `<video class="banner-vid">` → `Genel-Halftime-v3.mp4` tam ekran
- Sol/sağ dikey kayan şeritler (`.vs-l`, `.vs-r`) ve üst/alt yatay bantlar (`.hs-t`, `.hs-b`) — Akademi kampanya cümleleri, CSS animasyonlu
  - **Metin tam olarak İKİ eş yarıdan oluşmalı.** Animasyon `-50%` kaydırıyor; yarılar birebir aynı değilse döngü başa dönerken görünür bir sıçrama olur. Şu an 5 cümlelik grup 4 kez tekrarlanıyor (çift sayı şart) ve her cümle `• ` ile bitiyor — son tekrardaki boşluğu da SİLME.
  - **Toplam uzunluk ekranı aşmalı**: bir yarı, yatayda ekran genişliğinden / dikeyde ekran yüksekliğinden uzun olmazsa şeritte boşluk açılır. 1080x1920'de ölçülen kapsama: yatay 3.90×, dikey 2.20×. Cümleleri kısaltırsan tekrar sayısını artır.
  - **Akış hızı 107 px/sn olmalı** — sahada okunabilir bulunan hız bu. Süre sabit olduğu için metin uzadıkça veya yazı büyüdükçe akış HIZLANIR. Yazı 13px'ten ~26px'e çıkarıldığında piksel uzunluğu iki katına çıktı ve süre 20 sn → 40 sn yapıldı. Boyutu/metni değiştirirsen `vsL`/`vsR`/`hsT`/`hsB` sürelerini yeniden hesapla (yarı mesafesi ÷ 107).
  - **Zemin altın (`#FFD700`), yazı siyah.** Eskiden kahve zemin (`#1a0f05`) üstüne beyaz yazıydı: kahve, videonun sepya kenarlarına UYSUN diye seçilmişti ve şerit neredeyse görünmez oluyordu. Artık amaç uyum değil dikkat çekmek — kampanya cümleleri okunsun. Ton kioskun geri kalanıyla aynı; `k.html` kuponundaki `#FFC800` bilerek AYRI (kupon beyaz kâğıda basılıyor, ekran sarısı orada fazla parlıyor).
  - **Yazı boyutu vw tabanlı olmalı** (`clamp(13px,2.4vw,30px)`): şerit kalınlığı da `6.9vw`, ikisi birlikte ölçeklenince yazı her ekranda bandın ~%35'i kalıyor. Sabit px verilirse küçük ekranda bandı taşırıyor.
- `#btnGame` → Oyun ekranını açar, banner sesini durdurur
  - **Alt bandın ÜSTÜNDE durmalı.** `bottom` eskiden sabit `52px`'ti ve 1080x1920'de butonun alt 23px'i bandın içinde kalıyordu; bant kahveyken sarı buton yine seçiliyordu, bant altına dönünce alt kenarı bandın içinde eriyordu. Artık `calc(6.9vw + 28px)`, yani bant kalınlığına bağlı — bandı büyütürsen buton da birlikte kayar.
  - `border:3px solid #000` bant ile buton aynı altın olduğu için var; kaldırırsan buton sarı zeminde şeklini kaybeder.
- `#btnKasaAccess` (sağ üstte, sabit/fixed, düşük opaklık) → Kasa PIN ekranını açar, sayfa durumundan bağımsız her zaman görünür
- **Ekrana dokununca müzik aç/kapa YALNIZCA bu sayfada çalışır.** Dinleyici `.banner`
  üzerinde (eskiden `document.body`'deydi) ve `bannerTouch()` iki koşulda hiç
  çalışmaz: `ustKatmanAcikMi()` (`gameOverlay` / `statsModal` / `pinModal`'dan biri
  açıksa) ve dokunulan yer bir `<button>` içindeyse. İkisi de sahada görülen
  hatalardan geliyor: personel kasa panelinde gezerken müzik durup duruyordu, OYNA
  butonuna basış da banner'a kabarıp müziği bir kez daha toggle ediyordu. Yeni bir
  tam ekran katman eklersen id'sini `ustKatmanAcikMi()` listesine EKLE.

### Sayfa 2+3 — Oyun Ekranı (`#gameOverlay`, `z-index:9999`)
- `#gameStart` → İsim girişi, ödül listesi, BAŞLA butonu
- `#gamePlay` → Oyun alanı (aktif vuruş)
- `#gameWin` → Sonuç ve ödül gösterimi
- `#overlayLogoBar` → Zuhal 50. Yıl logosu (tüm oyun sayfalarında sabit, üstte)
- **Logo çubuğu yüksekliği ile sayfa üst boşluğu tek kaynaktan gelir** (`:root`
  içindeki `--logobar-img` / `--logobar-pad` / `--logobar-h` / `--page-top`).
  Eskiden ikisi ayrı ayrı `clamp`'lenmişti; 1080x1920 kioskta logo 160px yer
  kaplarken boşluk 120px'te kalıyor ve logo başlığın üstüne biniyordu. Logo
  boyutunu değiştireceksen SADECE bu değişkenleri değiştir.
- `#gameStart` ve `#gameWin` `justify-content:safe center` kullanır. Düz `center`,
  içerik ekrandan uzun olduğunda üst kısmı kaydırılamaz hale getiriyor ve ilk
  satır logonun altında kayboluyordu (küçük pencerede / QR eklendikten sonra).

### Kasa Paneli (`#statsModal`, `#pinModal`)
- Açılış: `#btnKasaAccess` butonuna veya `#overlayLogo`'ya 5 kez hızlı basınca PIN ekranı açılır (`openPinModal()`), doğru PIN (`STATS_PIN`, varsayılan `"5050"`) girilince panel açılır
- İki sekme: **KAZANANLAR** (`renderWinners()` — isimle arama, sadece kodu üretilmiş/finalize olmuş oyunlar) ve **İSTATİSTİK** (`renderStatsView()` — günlük özet + oyuncu listesi)
- Panel açıkken her 4 saniyede bir `refreshStatsAll()` ile otomatik yenilenir (`statsRefreshTimer`)
- Oyuncu adı gibi kullanıcı girdisi ekrana basılırken **mutlaka `escapeHtml()`'den geçirilmeli** (XSS önlemi — bkz. Dikkat Edilmesi Gerekenler)

### Ses Mimarisi (kritik — karışık olmaması için ayrı tutulmuş)
| Ses | Kaynak | Nasıl |
|-----|--------|-------|
| Banner müziği | `zuhal-muzik.wav` | `new Audio()` HTML element, dokunuşla toggle |
| Oyun müziği | `whitney-halftime.mp3` (harici dosya, `fetch()` ile indirilir) | Web Audio API `wBuffer`, `AudioBufferSourceNode` — `fetchWhitneyArrayBuffer()` sonucu cache'lenir |

Not: Eskiden ayrı bir Web Audio metronom motoru vardı (`start()`, `PAT_NORMAL`/`PAT_HALF`, step grid UI).
Hiçbir yerden çağrılmadığı (tamamen ulaşılamaz olduğu) ve boşuna bir `AudioContext` tuttuğu için
kaldırıldı — iOS eşzamanlı AudioContext sayısını sınırlar. Gerekirse git geçmişinden geri alınabilir.

**Önemli:** Banner sesi ve oyun sesi birbirinden tamamen bağımsız. `openGameOverlay()` → `stopBannerAudio()`, `closeGame()` → `startBannerAudio()`.

### Oyun Mantığı

**Timing:**
- `TOM_HIT_TIME = 12.18` — Whitney Houston parçasında snare'in tam zamanı (saniye)
- `WIN_PERFECT = 0.05` (50ms), `WIN_GREAT = 0.13`, `WIN_GOOD = 0.28`, `WIN_IDAREDER = 0.50`
- **Ses çıkış gecikmesi telafisi** (kritik): `wAudioCtx.currentTime` sesin İŞLENDİĞİ
  anı verir, hoparlörden ÇIKTIĞI anı değil. Aradaki fark `outputLatency`
  (sahada Android kioskta 48 ms ölçüldü). `handleHit()` bu değeri `elapsed`ten
  çıkarır; yoksa tomu duyduğu anda vuran müşteri "48 ms geç" sayılır ve MÜKEMMEL'i
  asla alamaz. Gecikme kasa panelinde görünür (`renderLatencyInfo`), ölçüm oyun
  sırasında alınıp `localStorage`'da saklanır (`captureAudioLatency`) — oyun bitince
  AudioContext kapandığı için sonradan okunamaz.
- **Puanlama tamamen simetrik**: `resultForOffset()` yalnızca |sapma|'ya bakar.
  "Geç vurana kulaklık yok" diye ayrı bir kural YOK — gerek de yok: kulaklık
  penceresi ±30 ms ve insanın sese tepki süresi ~150 ms, yani tomu DUYUP vurarak
  o pencereye girmek imkansız. Tepkiyle vuran en iyi bez çanta alır (test edildi).
  Geçmiş: 20 ms, 150 ms ve "1 ms geç = kulaklık yok" kuralları denendi; üçü de
  ya ters sonuç üretti ya da tam zamanında vuran müşteriyi cezalandırdı.
- **Olay yaşı telafisi** (`eventAgeSec`): tarayıcı olayı hemen işlemeyebilir; ses
  çözümleme veya çizim sıradaysa dinleyici 5-30 ms geç çalışır ve vuruş olduğundan
  geç ölçülür. `event.timeStamp` olayın gerçek anını verdiği için aradaki fark
  çıkarılır. `handleHit(kaynak, evt)` ve `calibHit(kaynak, evt)` aynı düzeltmeyi
  uygular — kalibrasyon oyunla aynı ölçümü yapmalı. Epoch tabanlı veya saçma
  timeStamp değerleri (>0.5 sn, negatif) yok sayılır.
- **Zamanlama kalibrasyonu** (kasa paneli > ⏱ ZAMANLAMA):
  Ses ÇIKIŞ gecikmesi `outputLatency` ile otomatik telafi edilir. GİRİŞ gecikmesi
  (dokunmatik panel 50-120 ms, USB MIDI ~5-10 ms) ölçülemez, kalibre edilir.
    - **Metronom tabanlıdır** (8 tık, 600 ms aralık). Parçadaki tom tek bir kez
      çaldığı için ona tahmin ederek vurulamaz; kişi TEPKİ verir (~150 ms) ve o
      süre telafiye gömülürse oyunun anti-tepki mantığı tamamen çöker.
      Düzenli tempoda ise ritme kilitlenip önceden vurulabilir.
    - İlk 2 vuruş ısınma sayılıp atılır, kalanın MEDYANI alınır.
    - **150 ms üzeri sonuç reddedilir** — o değer cihaz gecikmesi değil tepki süresidir.
    - **Cihaza göre AYRI saklanır**: `inputLatencyTouchMs` / `inputLatencyMidiMs`.
      Ekranla kalibre edip pad'le oynanırsa ~90 ms fazla telafi uygulanır ve geç vuran
      "tam zamanında" görünür. Karışık ölçüm reddedilir.
    - `localStorage`'da tutulur, yani **her cihazda ayrı yapılmalı** (PC'de yapılanı kiosk görmez).
  `totalLatencySec(kaynak)` her vuruşta doğru değeri çıkarır; `handleHit(kaynak)`
  çağrılırken kaynak "midi" veya "touch" olarak geçilir.

**Ödüller:** `whitneyPrizes` objesi, `makeCode()` → `HT50-{KOD}-{DDMM}-{4rakam}` formatında kod üretir

**Ödül merdiveni (AKADEMİ KAMPANYASI):** MÜKEMMEL → Akademi 1 Ay 4 Ders (`AKD1AY`),
HARİKA → Ücretsiz Deneme Dersi (`AKDRS`), İYİ → Akademide İlk Ay %50 (`AKD50`),
İDARE EDER → Zuhal Bez Çanta (`CANTA`), ÇALIŞMAYA DEVAM → **HEDİYE YOK**
(`type:"none"`, kupon üretilmez).

Kampanyanın amacı indirim dağıtmak değil **Akademi'ye öğrenci çekmek**: MÜKEMMEL hariç
her basamak müşteriyi derse yönlendiriyor. Bu yüzden `%50` burada mağaza indirimi değil,
Akademi kayıt indirimidir.

Geçmiş: önceki merdiven kulaklık (`KS200`) + `%15` (`IND15`) + `%10` (`IND10`) üzerineydi.
İki günde 943 oyun oynandı ve ~110 indirim kuponu dağıtıldı; **indirimler ilgi görmedi,
fiziki/ders ödülleri tuttu.** Kulaklık ve tüm yüzde indirimleri merdivenden tamamen kalktı.
Daha eskisinde bez çanta ÇALIŞMAYA DEVAM'daydı; gelişigüzel vuran herkes aldığı için stok
eridi, yukarı çekildi ve kaçıran hediyesiz bırakıldı.

**Kupon son kullanma tarihi:** her kupon kazanıldığı günden **+1 ay** geçerli.
`addOneMonth()` ay sonlarını kırpar (31 Ocak + 1 ay = 28/29 Şubat — JS'in kendi `Date`
aritmetiği 3 Mart'a taşardı). Tarih `formatDate()` ile `DD.MM.YYYY` üretilir, ekranda
`#prizeExpiry`'de, kayıtta `pl.expiry` alanında ve XLS'in 7. sütununda görünür.
**Tarih kayda YAZILIR, kasa panelinde yeniden hesaplanmaz** — yoksa kupon kuralı
değiştiğinde eski kuponlar yanlış tarih gösterir. `isExpired()` boş `expiry`'yi
**geçerli** sayar: kampanyadan önceki kuponlarda bu alan yok, onları yakmamak gerekir.
Kasa panelinde süresi dolmuş kupon yeşil "GEÇERLİ" yerine kırmızı
`⛔ SÜRESİ DOLMUŞ KUPON` verir.

**QR kod (sonuç ekranı):** müşteri kuponu telefonuna alsın diye `#prizeQR` canvas'ına
çizilir. QR üreticisi **elle yazıldı, harici kütüphane/CDN YOK** — kiosk tek HTML
dosyası, internet kesilse bile kupon üretilebilmeli. Kapsam bilerek dar tutuldu:
yalnızca byte modu, ECC seviyesi **M**, sürüm 1-10 (en fazla 216 bayt). Link ~100-120
bayt (sürüm 6-7, 41-45 modül); daha fazlası gerekirse sürüm tablosunu genişletmek
gerekir, `qrEncode()` sığmayan metinde `null` döner ve `qrRender()` QR'ı gizler
(kupon akışı kesilmez).

- **QR bir LİNK taşır** (`qrPayload()` → `KUPON_URL + "#" + kod + "*" + sonKullanma +
  "*" + ad`). Eskiden düz yazı taşıyordu; telefon onu Notlar'a yapıştırıyor, müşteriye
  kupon değil çıplak metin gibi görünüyordu. Bkz. `k.html` bölümü.
  - **Ödül adı BİLEREK taşınmıyor** — kupon kodunun içinde zaten var
    (`HT50-<ODUL>-GGAA-XXXX`) ve `k.html` oradan çözüyor. Her karakter QR'da bir
    bayt; kısa metin = seyrek modül = uzaktan okunabilen kod.
  - **`KUPON_URL` sabit yazılmalı**, `location`'dan türetilmemeli: kiosk `file://`
    üzerinden veya başka bir makineden servis edilse bile müşterinin telefonu bu
    genel adrese gidebilmeli. Güncel değer: `https://zuhal-game.vercel.app/k.html`.
    ⚠️ **Bu adres değişirse elde dolaşan kuponlar ölür** (kupon 1 ay geçerli, QR
    adresi taşıyor). Özel alan adı eklense bile vercel.app adresi çalışmaya devam
    edeceği için bu sabiti bir daha değiştirmeye gerek YOK.
  - Ad soyad `[^A-Za-z0-9]+` → `_` ile sadeleşir; okuyucular linki boşlukta kesiyor.
- **İçerik ASCII'ye indirgenir** (`qrAscii()`). Bazı okuyucular ECI'siz byte modunu
  ISO-8859-1 varsayıp UTF-8 Türkçe karakterleri bozuk gösteriyor. Ekranda Türkçe
  doğru görünür, yalnızca QR'ın içi sadeleşir.
- **Sessiz bölge (4 modül) ve beyaz zemin ZORUNLU.** Kioskun siyah teması üzerine
  doğrudan çizilirse okuyucular kodu çoğu zaman hiç bulamıyor; `#qrBox` beyaz
  çerçeveyi bu yüzden taşıyor.
- **Modül boyutu tam sayı piksel olmalı** (`Math.floor`), kesirli değerde kenarlar
  bulanıklaşıp okuma düşüyor. Hedef ~250 px.
- `#qrBox`, `#codeBox`'ın İÇİNDE. Hediyesiz (`type:"none"`) sonuçta `codeBox`
  gizlendiği için QR da kendiliğinden gizlenir — ayrıca gizlemeye gerek yok.
- **Doğrulama:** üretilen matris Python `segno` kütüphanesinin çıktısıyla 6 farklı
  kupon metninde, 8 maskenin tamamında birebir karşılaştırıldı. ⚠ Karşılaştırırken
  segno'nun `write_padding_bits` davranışı yamalanmalı: akış zaten bayt sınırındayken
  bile 8 sıfır bit ekliyor (`8 - (length % 8)`), byte modunda akış her zaman hizalı
  olduğu için daima fazladan bir `0x00` kod sözcüğü doğuyor. ISO/IEC 18004 §7.4.10
  hizalıyken bit eklenmemesini söylüyor — bizim davranışımız standarda uygun.
  Maske seçimi segno'dan farklı çıkabilir (ceza fonksiyonu yorum farkı); 8 maskenin
  hepsi geçerli olduğu için bu bir hata değil.

## k.html — Müşteri Kupon Sayfası

QR okutulunca müşterinin telefonunda açılan sayfa. Kiosk kodundan **tamamen bağımsız**;
`index.html`'e hiç dokunmadan tasarımı değiştirilebilir. Amacı iki şey: kuponu markalı
ve resmi göstermek, bir de **PDF çıktısı** vermek.

- **Veri `#` (fragment) ile taşınır**, query string ile değil: fragment sunucuya HİÇ
  gitmez, müşteri adı sunucu (Vercel) loglarına düşmez.
- **Ödül adı kupon kodundan çözülür** (`ODULLER` tablosu, anahtar = kodun 2. parçası).
  Ödül merdivenini değiştirirken `index.html`'deki `whitneyPrizes` ile bu tabloyu
  BİRLİKTE güncelle — yoksa yeni kupon "ZUHAL MÜZİK HEDİYESİ" genel metnine düşer
  (bilerek konmuş güvenli varsayılan, çökme değil).
- **PDF, `window.print()` ile alınır.** jsPDF gibi bir kütüphane yok; PDF'e gömülü
  Helvetica ş/ğ/ı gibi Türkçe harfleri taşımıyor, yazdırma yolu hem doğru harfleri
  hem logoyu basıyor. `@media print` butonları gizler ve `print-color-adjust:exact`
  ile altın bandı/kod kutusunu zorla bastırır — yoksa kupon bomboş beyaz çıkıyor.
- **Sayfa AÇIK temalı**, kioskun siyahı kullanılmaz: hem mürekkep yakıyor hem
  "arka plan grafikleri" kapalıyken kupon boş görünüyor.
- **Ad soyad `textContent` ile basılır, `innerHTML` ile ASLA** — veri URL'den geliyor,
  yani saldırgan istediğini yazabilir (test edildi: `<img onerror>` düz metin çıkıyor).
- Kod biçimi `^HT50-[A-Z0-9]{2,10}-\d{4}-\d{4}$` ile doğrulanır; tutmuyorsa "KUPON
  OKUNAMADI" ekranı gelir.
- `suresiDolduMu()` **son günü DAHİL geçerli** sayar ve tarih okunamazsa kuponu
  yakmaz — `index.html`'deki `isExpired()` ile aynı davranış.
- ⚠ Müşterinin telefonunda **internet gerekir** (kiosk offline çalışmaya devam eder,
  QR üretimi yerel). Kupon kodu ayrıca kiosk ekranında yazıyor, kasa oradan doğruluyor.

**`type:"none"` sözleşmesi:** kupon kodu üretilmez, `codeBox`/`cantaBox` gösterilmez,
kayıtta `code` boş kalır. Bu kişi KAZANANLAR listesinde çıkmaz (liste yalnızca `pl.code`
olanları listeler) ama İSTATİSTİK'te sayılır. Yeni hediyesiz bir basamak eklenirse
`showWhitneyResult()` içindeki üç kollu `if (p.type === "code") / else if ("none") / else`
dalını bozma.

**Stok sınırları — iki AYRI sayaç tipi var, karıştırma:**

Ortak temel `countCouponsIn(data, prizeCode)` bir gün nesnesindeki `-KOD-` içeren
**kuponları** sayar — denemeleri değil. Bu ayrım kritik: müşteri 2 deneme yapar ama kod
yalnızca oyun kesinleşince tek bir denemeye yazılır, yani sayı = verilen hediye adedi.

1. **Kampanya boyu TOPLAM** — `couponsIssuedAllTime(prizeCode)` bütün `zuhal_plays_*`
   anahtarlarını tarar. `MAX_AKD1AY_TOTAL = 10`: 1 Ay 4 Ders hediyesi kampanya boyunca
   toplam 10 kişiye verilir, **günlük değil**. Dolunca `prizeForResult("perfect")` →
   `perfectSoldOutPrize` (Ücretsiz Deneme Dersi, etiket yine MÜKEMMEL!).
   **Ayrıca günlük tavan var** — `MAX_AKD1AY_DAILY = 1` (`akd1ayIssuedToday()`):
   aynı günde en fazla 1 kişi alabilir. Hangi sınır önce dolarsa ödül alt basamağa
   düşer. Merdivende iki sınırı birden taşıyan TEK ödül budur. Gerekçe: kampanya
   1 ay sürüyor; tek başına toplam sınır ilk yoğun günde tükenip kalan ~26 günü
   hediyesiz bırakıyordu, tek başına günlük tavan ise ayda 30 adet dağıtırdı.
   Kasa panelinde iki satır ayrı gösterilir (kampanya toplamı + bugün).
   ⚠ Bu sayaç `cleanOldData()`'ya bağımlı: silinen günün kuponları sayılmaz ve sınır
   kendiliğinden gevşer. Saklama süresi bu yüzden 90 güne çıkarıldı; kampanya daha
   uzun sürerse süreyi de uzat.

2. **GÜNLÜK** — `couponsIssuedToday(prizeCode)` yalnızca bugünü sayar, her gün sıfırlanır.
   Bez çanta böyle çalışır. Dolunca `prizeForResult("idareder")` → `idarederSoldOutPrize`
   (Akademide İlk Ay %50, etiket yine İDARE EDER!). **1 Ay 4 Ders'e ASLA yükseltilmez** —
   o ayrı ve çok daha dar bir stok.

Kayıttaki `result` her iki durumda da değişmez ("perfect"/"idareder" kalır) — istatistik bozulmaz.

**Bez çanta stoğu sabit değil, her gün kasa panelinden girilir.** `cantaStokForDay(dayKey)`
`zuhal_canta_stok_YYYY-MM-DD` anahtarını okur; girilmemişse `DEFAULT_CANTA_STOK = 30`.
**Girilmiş 0 ile girilmemiş ayrımı önemli** (`cantaStokGirildiMi()`): "bugün hiç çanta yok"
demek isteyen personelin girdiği 0, varsayılan 30'a düşmemeli. `#cantaStokInput` alanı
odaktayken `renderStockInfo()` değerin üzerine YAZMAZ — panel 4 saniyede bir yenilendiği
için personelin yazdığı rakam siliniyordu.

**Ödül ürünü değişirse `code` ön ekini de değiştir.** Kulaklık Roland RH-5 iken stok bitti,
Kozmos S-200 ile yenilendi ve ön ek `RH5KL` → `KS200` oldu. Sayaç ön eke baktığı için eski
ürünün kuponları yeni ürünün sınırını doldurmaz (yeni ürün = yeni stok). Müşterinin
elindeki eski kupon kasada YİNE doğrulanır — arama kod metnine bakar, geçerli ön ek listesine
değil. Ön eki değiştirmezsen eski kuponlar yeni sınırı yer.

Kalan adetler kasa panelinde `renderStockInfo()` ile görünür (yalnızca bugün seçiliyken).

### Android / Dokunmatik Ekran
- Touch cihazlarda sadece `touchstart`, mouse'ta sadece `click` kullanılır (çift tetik önlemi)
- `unlockAC()` — AudioContext'i kullanıcı etkileşimiyle açar (browser politikası)
- Tüm butonlarda `touch-action:manipulation`

### İstatistik / Kazananlar Paneli
- Günlük oyun kayıtları localStorage'dan XLS olarak indirilebilir (`downloadStats()`)
- **Veri BUGÜN hâlâ yalnızca kioskun kendi tarayıcısında.** Supabase projesi kuruldu
  (Faz 1: tablolar + RLS + RPC hazır ve doğrulandı) ama **kiosk henüz ona bağlı DEĞİL** —
  `index.html` içinde tek satır Supabase kodu yok. Yani bugün hiçbir kayıt buluta gitmiyor. Cihaz sıfırlanır veya tarayıcı verisi temizlenirse kayıtlar gider. `cleanOldData()` 90 gün saklar — bu süre `couponsIssuedAllTime()` doğru sayabilsin diye 30'dan çıkarıldı, kısaltma.
- **Gün seçici** (`#statsDay`): panel ve İNDİR eskiden yalnızca bugünü gösteriyordu, önceki günün verisi cihazda durduğu halde alınamıyordu. Artık `selectedDay` / `selectedDayKey()` / `playsForPanel()` üçlüsü seçili günü verir. **`loadPlays()` ASLA bu seçime bağlanmamalı** — oyun, `makeCode()` ve `headphonesIssuedToday()` her zaman bugüne yazıp okumalı; aksi halde personel dünü seçtiğinde oyun dünün dosyasına yazardı. Seçici sadece `openStats()` içinde doldurulur (`fillDaySelect()`); `refreshStatsAll()` içinde doldurulsaydı 4 saniyede bir seçim bugüne dönerdi. Panel her açılışta bugüne sıfırlanır ve geçmiş gün seçiliyken `#dayWarn` uyarısı çıkar (kupon doğrulaması yanıltmasın).

## Dikkat Edilmesi Gerekenler

- Kullanıcı girdisini (oyuncu adı vb.) `innerHTML` ile ekrana basarken **her zaman `escapeHtml()`** kullan — geçmişte Kazananlar/İstatistik panelinde XSS açığı olmuştu, düzeltildi.
- `.vs-t` / `.hs-i` scroll animasyonlarında `translateX(-50%)` / `translateY(-50%)` animasyon keyframe'lerin içinde olmalı — dışında olursa animasyon çalışmaz.
- `display:flex; align-items:center` kayan şerit containerına uygulanmamalı — text elementini ortalar ve scroll animasyonu bozulur.
- Sayfa 5 dakikada bir yenilenir ama **`meta http-equiv="refresh"` ile DEĞİL** — `scheduleIdleReload()` ile. Meta refresh oyunun ortasında sayfayı sıfırlayıp oyuncunun hakkını yakıyordu. Yeni mantık: oyun çalarken (`gameRunning`) veya personel panelde aktifken asla yenilemez; ekran 60 sn hareketsiz kalırsa terk edilmiş sayıp yeniler. Yenileme koşullarını değiştirirken `isBusyNow()`'a bak.
- **XLS'teki hücre renkleri AÇIK ton olmalı.** `downloadStats()` kioskun karanlık paletini (`#3a1a1a`, `#1a2a4a`…) dosyaya kopyalıyordu; Excel hücre yazısını siyah çizdiği için satırlar siyah üstüne siyah çıkıyor ve dosya okunmuyordu. `resultColors` artık pastel tonlar, ayrıca her veri hücresine `color:#000` açıkça veriliyor. Tek koyu kalan `#222222` başlık satırı — yazısı altın sarısı olduğu için okunuyor. Renk değiştirirken kontrastı ekrana göre değil **Excel'e göre** düşün.
- XLS indirme iOS'ta `<a download>` ile çalışmaz; `downloadStats()` **yalnızca iOS'ta** (`isIOSDevice()`) önce Web Share API'yi (`shareFile()`) dener, diğer her yerde doğrudan `triggerDownload()` çağırır. Android'de paylaş sayfası denenmemeli — dosyayı alacak uygulama olmayan kioskta "hiçbir şey olmuyor" gibi görünüyordu.
- **`#btnStatsDownload` bilerek `bindTap` KULLANMAZ**, düz `click` dinleyicisine bağlıdır. `bindTap` `pointerdown`a bağlanır; tarayıcı indirmesi ve `navigator.share()` ise *geçici kullanıcı etkileşimi* ister, Chrome bunu dokunuşun başında değil sonunda (tap/click) verir. `pointerdown`a bağlıyken share sessizce `NotAllowedError` ile reddediliyor, `shareFile()` yine de `true` döndürdüğü için klasik indirmeye de düşülmüyordu → buton ölüydü. `shareFile()` artık `AbortError` dışındaki hatalarda indirmeye düşer; `onDownloadClick()` butonda görünür geri bildirim verir (`✓ İNDİRİLDİ` / `✕ HATA`).
- `whitney-halftime.mp3` harici dosya olduğu için tarayıcı tarafından cache'lenir; her 5 dakikalık yenilemede tekrar indirilmez (base64 gömme dönemindeki performans sorunu buydu).
- Yeni medya dosyası eklerken repoya bırakmadan önce `index.html` içinde gerçekten kullanıldığından emin ol (bkz. Dosya Yapısı notu) — geçmişte ~100MB kullanılmayan dosya birikmişti.

## Supabase Faz 2 — canlıya çıkmadan kapatılması gereken iki açık

Şema (`supabase/schema.sql`) kuruldu ve doğrulandı: 7 tablo, 11 RLS politikası,
5 fonksiyon; ödül merdiveni test edildi (günlük tavan dolunca `odul_sec('AKD1AY')`
gerçekten `AKDRS` döndürüyor). Ama kiosk bağlanmadan önce iki nokta düzeltilmeli —
sonradan düzeltmek çok daha pahalı, çünkü o zaman canlı kupon verisi olacak.

1. **Kupon uydurulabiliyor.** `p_kuponlar_insert` politikası `anon`'a serbest INSERT
   veriyor; `anon` anahtarı tarayıcıda göründüğü için isteyen kendine istediği ödülde
   kupon yazabilir (`kullanildi=false` şartı bunu engellemiyor — sadece "kullanılmış
   olarak doğmasını" engelliyor). Kasa kuponu veritabanından doğrulayacaksa bu delik
   doğrulamanın anlamını kaldırır. **Çözüm:** kupon üretimi de `security definer` bir
   fonksiyona alınmalı, `anon`'un doğrudan INSERT hakkı çekilmeli.

2. **Son ödül yarışı hâlâ açık.** Şemadaki yorum *"ödül kararı sunucuda verildiği için
   iki ekran son bez çantayı aynı anda veremez"* diyor; ama `odul_sec` yalnızca sayıp
   cevap veriyor, kuponu **ayırmıyor**. Karar ile kupon yazımı iki ayrı adım olduğu
   için iki ekran aynı anda "verilebilir" cevabı alabilir. **Çözüm:** karar + kupon
   üretimi tek fonksiyonda, `kuponlar` üzerinde kilitle (`for update`).

Ayrıca kiosk bağlanırken: `localStorage` bugünkü tek kaynak. Buluta geçişte iki kaynağın
aynı anda yazması (ve stok sayaçlarının ikisinden birden okunması) en olası hata sınıfı —
sayaç TEK yerden okunmalı.
