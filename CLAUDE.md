# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Kuralları

- **Her zaman `main` branch üzerinde çalış ve push et.** Feature branch kullanma.
- Her değişiklikten sonra: `git add <dosya>`, `git commit -m "..."`, `git push origin main`
- Commit mesajları Türkçe olabilir.

## Proje Özeti

32" dokunmatik mağaza ekranı için tek dosya HTML oyunu: **`index.html`**

Zuhal Müzik 50. Yıl — Rhythm Challenge. Müşteriler Whitney Houston parçası çalarken snare vuruşunu tam zamanında yaparak indirim/ödül kazanıyor.

## Dosya Yapısı

```
index.html                  ← Tek kaynak dosya (tüm CSS + JS burada, ses artık harici)
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

Repoda bu 5 dosya dışında hiçbir medya kullanılmıyor — yeni bir görsel/video eklerken önce `index.html` içinde gerçekten referans verildiğinden emin ol, aksi halde GitHub Pages deploy boyutu şişer.

## index.html Mimarisi

Tüm uygulama tek HTML dosyasında, 3 katman:

### Sayfa 1 — Banner (`.banner`)
- `<video class="banner-vid">` → `Genel-Halftime-v3.mp4` tam ekran
- Sol/sağ dikey kayan şeritler (`.vs-l`, `.vs-r`) ve üst/alt yatay bantlar (`.hs-t`, `.hs-b`) — SINIRLI STOK yazısı, CSS animasyonlu
- `#btnGame` → Oyun ekranını açar, banner sesini durdurur
- `#btnKasaAccess` (sağ üstte, sabit/fixed, düşük opaklık) → Kasa PIN ekranını açar, sayfa durumundan bağımsız her zaman görünür

### Sayfa 2+3 — Oyun Ekranı (`#gameOverlay`, `z-index:9999`)
- `#gameStart` → İsim girişi, ödül listesi, BAŞLA butonu
- `#gamePlay` → Oyun alanı (aktif vuruş)
- `#gameWin` → Sonuç ve ödül gösterimi
- `#overlayLogoBar` → Zuhal 50. Yıl logosu (tüm oyun sayfalarında sabit, üstte)

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
  o pencereye girmek imkansız. Tepkiyle vuran en iyi %10 alır (test edildi).
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

**Ödül merdiveni:** MÜKEMMEL → Roland RH-5 Kulaklık (`RH5KL`), HARİKA → %15 (`IND15`),
İYİ → %10 (`IND10`), İDARE EDER → Akademi 1 Ders (`AKDRS`), ÇALIŞMAYA DEVAM → Bez Çanta (`CANTA`).

**Kulaklık stok sınırı:** `MAX_HEADPHONES_PER_DAY = 3`. `headphonesIssuedToday()` bugünün
kayıtlarında `-RH5KL-` içeren kupon kodlarını sayar; sınır dolunca `prizeForResult("perfect")`
`perfectSoldOutPrize`'ı (%15 indirim, etiket yine MÜKEMMEL!) döndürür. Kayıttaki `result`
"perfect" olarak kalır — istatistik bozulmaz. Sayı günlük anahtardan geldiği için her gün sıfırlanır.
Personel kasa panelinde `RH5KL` arayıp gün içinde kaç kulaklık verildiğini görebilir.

### Android / Dokunmatik Ekran
- Touch cihazlarda sadece `touchstart`, mouse'ta sadece `click` kullanılır (çift tetik önlemi)
- `unlockAC()` — AudioContext'i kullanıcı etkileşimiyle açar (browser politikası)
- Tüm butonlarda `touch-action:manipulation`

### İstatistik / Kazananlar Paneli
- Günlük oyun kayıtları localStorage'dan XLS olarak indirilebilir (`downloadStats()`)

## Dikkat Edilmesi Gerekenler

- Kullanıcı girdisini (oyuncu adı vb.) `innerHTML` ile ekrana basarken **her zaman `escapeHtml()`** kullan — geçmişte Kazananlar/İstatistik panelinde XSS açığı olmuştu, düzeltildi.
- `.vs-t` / `.hs-i` scroll animasyonlarında `translateX(-50%)` / `translateY(-50%)` animasyon keyframe'lerin içinde olmalı — dışında olursa animasyon çalışmaz.
- `display:flex; align-items:center` kayan şerit containerına uygulanmamalı — text elementini ortalar ve scroll animasyonu bozulur.
- Sayfa 5 dakikada bir yenilenir ama **`meta http-equiv="refresh"` ile DEĞİL** — `scheduleIdleReload()` ile. Meta refresh oyunun ortasında sayfayı sıfırlayıp oyuncunun hakkını yakıyordu. Yeni mantık: oyun çalarken (`gameRunning`) veya personel panelde aktifken asla yenilemez; ekran 60 sn hareketsiz kalırsa terk edilmiş sayıp yeniler. Yenileme koşullarını değiştirirken `isBusyNow()`'a bak.
- XLS indirme iOS'ta `<a download>` ile çalışmaz; `downloadStats()` önce Web Share API'yi (`shareFile()`) dener, sonra klasik indirmeye düşer. Bu sırayı bozma.
- `whitney-halftime.mp3` harici dosya olduğu için tarayıcı tarafından cache'lenir; her 5 dakikalık yenilemede tekrar indirilmez (base64 gömme dönemindeki performans sorunu buydu).
- Yeni medya dosyası eklerken repoya bırakmadan önce `index.html` içinde gerçekten kullanıldığından emin ol (bkz. Dosya Yapısı notu) — geçmişte ~100MB kullanılmayan dosya birikmişti.
