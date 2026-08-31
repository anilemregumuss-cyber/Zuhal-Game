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
Genel-Halftime.mp4          ← Ana sayfa banner videosu (autoplay, muted, loop)
zuhal-muzik.wav             ← Banner arka plan müziği (dokunuşla aç/kapat)
whitney-halftime.mp3        ← Oyun içi Whitney Houston parçası (fetch + Web Audio API decode)
zuhal-fifty-year-black.jpg  ← Oyun ekranı logosu (filter:invert(1) ile beyaza çevrilmiş)
```

Repoda bu 5 dosya dışında hiçbir medya kullanılmıyor — yeni bir görsel/video eklerken önce `index.html` içinde gerçekten referans verildiğinden emin ol, aksi halde GitHub Pages deploy boyutu şişer.

## index.html Mimarisi

Tüm uygulama tek HTML dosyasında, 3 katman:

### Sayfa 1 — Banner (`.banner`)
- `<video class="banner-vid">` → `Genel-Halftime.mp4` tam ekran
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
- `WIN_PERFECT = 0.05` (±50ms), `WIN_GREAT = 0.13`, `WIN_GOOD = 0.28`, `WIN_IDAREDER = 0.50`

**Hak sistemi:**
- `MAX_PLAYS_PER_DAY = 2` — `localStorage`'da oyuncu adına göre takip
- 2 denemenin **en iyisi** kazanır (1. daha iyiyse, 1.'nin ödülü verilir)

**Ödüller:** `whitneyPrizes` objesi, `makeCode()` → `HT50-{KOD}-{DDMM}-{4rakam}` formatında kod üretir

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
