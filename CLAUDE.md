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
index.html                  ← Tek kaynak dosya (tüm CSS + JS + base64 MP3 burada)
Zuhal_HALFTIM_v04.mp4       ← Ana sayfa banner videosu (autoplay, muted, loop)
zuhal-muzik.wav             ← Banner arka plan müziği (dokunuşla aç/kapat)
zuhal-fifty-year-black.jpg  ← Oyun ekranı logosu (filter:invert(1) ile beyaza çevrilmiş)
ZuhalHalftimeoyunilksayfa.png ← Yedek banner görseli (artık kullanılmıyor)
```

## index.html Mimarisi

Tüm uygulama tek HTML dosyasında, 3 katman:

### Sayfa 1 — Banner (`.banner`)
- `<video class="banner-vid">` → `Zuhal_HALFTIM_v04.mp4` tam ekran
- Sol/sağ dikey kayan şeritler (`.vs-l`, `.vs-r`) — SINIRLI STOK yazısı, CSS animasyonlu
- `#btnGame` → Oyun ekranını açar, banner sesini durdurur

### Sayfa 2+3 — Oyun Ekranı (`#gameOverlay`, `z-index:9999`)
- `#gameStart` → İsim girişi, ödül listesi, BAŞLA butonu
- `#gamePlay` → Oyun alanı (aktif vuruş)
- `#gameWin` → Sonuç ve ödül gösterimi
- `#overlayLogoBar` → Zuhal 50. Yıl logosu (tüm oyun sayfalarında sabit, üstte)

### Ses Mimarisi (kritik — karışık olmaması için ayrı tutulmuş)
| Ses | Kaynak | Nasıl |
|-----|--------|-------|
| Banner müziği | `zuhal-muzik.wav` | `new Audio()` HTML element, dokunuşla toggle |
| Oyun müziği | `MP3_B64` (base64 MP3 embedded) | Web Audio API `wBuffer`, `AudioBufferSourceNode` |
| Metronom | Web Audio API oscillator | `PAT_NORMAL` / `PAT_HALF` pattern dizileri |

**Önemli:** Banner sesi ve oyun sesi birbirinden tamamen bağımsız. `openGameOverlay()` → `stopBannerAudio()`, `closeGame()` → `startBannerAudio()`.

### Oyun Mantığı

**Timing:**
- `TOM_HIT_TIME = 12.18` — Whitney Houston parçasında snare'in tam zamanı (saniye)
- `WIN_PERFECT = 0.05` (±50ms), `WIN_GREAT = 0.13`, `WIN_GOOD = 0.28`, `WIN_IDAREDER = 0.50`

**Hak sistemi:**
- `MAX_PLAYS_PER_DAY = 2` — `localStorage`'da oyuncu adına göre takip
- 2 denemenin **en iyisi** kazanır (1. daha iyiyse, 1.'nin ödülü verilir)

**Metronom:**
- 100 BPM, 4/4 — `PAT_NORMAL` (2 ölçü) → `PAT_HALF` halftime (2 ölçü) döngüsü
- Web Audio API scheduler: `schedule()` → `rafLoop()` → `drawStep()`
- `start()` / `stop()` null-safe yazılmıştır (oyun ekranında bazı metronom UI elementleri yoktur)

**Ödüller:** `whitneyPrizes` objesi, `makeCode()` → `HT50-{KOD}-{DDMM}-{4rakam}` formatında kod üretir

### Android / Dokunmatik Ekran
- Touch cihazlarda sadece `touchstart`, mouse'ta sadece `click` kullanılır (çift tetik önlemi)
- `unlockAC()` — AudioContext'i kullanıcı etkileşimiyle açar (browser politikası)
- Tüm butonlarda `touch-action:manipulation`

### İstatistik Paneli
- `#overlayLogo`'ya 5 kez hızlı basınca gizli panel açılır (`openStats()`)
- Günlük oyun kayıtları localStorage'dan XLS olarak indirilebilir

## Dikkat Edilmesi Gerekenler

- **`index.html` içindeki `MP3_B64`** çok büyük (~600KB base64). Dosyayı düzenlerken kaydetmemeye dikkat et — sadece gerekli satırları değiştir.
- `.vs-t` scroll animasyonunda `translateX(-50%)` animasyon keyframe'lerin içinde olmalı — dışında olursa animasyon çalışmaz.
- `display:flex; align-items:center` kayan şerit containerına uygulanmamalı — text elementini ortalar ve scroll animasyonu bozulur.
- Sayfa **5 dakikada bir** (`<meta http-equiv="refresh" content="300">`) yenilenir.
