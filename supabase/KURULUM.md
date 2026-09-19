# Supabase Kurulumu — Senin Yapacakların

Bu adımları **senin** yapman gerekiyor, çünkü hesap açma ve şifre girme işleri
bana bırakılmaz. Her adım birkaç dakika sürer.

---

## 1. Hesap aç

1. `supabase.com` → **Start your project** → GitHub hesabınla giriş yap
   (zaten GitHub kullanıyorsun, ayrı şifre gerekmez).
2. **New project**
   - **Name:** `zuhal-oyun`
   - **Database Password:** güçlü bir şifre üret ve **parola yöneticine kaydet**.
     Bu şifreyi bir daha göremezsin, ama günlük kullanımda da gerekmez.
   - **Region:** `Central EU (Frankfurt)` — Türkiye'ye en yakın bölge.
     ⚠ Veriler yurt dışında (AB) tutulacak. KVKK'da yurt dışına veri aktarımı
     açık rıza ister; aydınlatma metnimize bunu yazacağız. Muhasebecine/avukatına
     bir kez teyit ettir.
   - **Plan:** Free (ücretsiz). Günde 1000 oyun bile aylarca sığar.
3. Proje kurulması ~2 dakika sürer.

---

## 2. Tabloları kur

1. Sol menü → **SQL Editor** → **New query**
2. Bu klasördeki `schema.sql` dosyasının **tamamını** kopyala, yapıştır.
3. **Run** (sağ altta).
4. "Success. No rows returned" görmelisin.

Sol menüden **Table Editor**'e girince şu tablolar görünmeli:
`subeler, oyunlar, oyuncular, kayitlar, kuponlar, limitler, stoklar`

---

## 3. Bana iki bilgi ver

Sol menü → **Project Settings** → **API**

| Alan | Ne yapayım |
|---|---|
| **Project URL** | `https://xxxx.supabase.co` — bana ver, açıkça paylaşılabilir |
| **anon public** anahtarı | Bana ver, bu da açıkça paylaşılabilir (tarayıcıda zaten görünür) |
| **service_role** anahtarı | ❌ **KİMSEYE VERME, BANA DA VERME.** Bu anahtar tüm güvenliği atlar. |

---

## 4. Şubeleri gir

**Table Editor → subeler → Insert row.** Her ekran için bir satır:

| id | ad | tip |
|---|---|---|
| `kadikoy` | Zuhal Müzik Kadıköy | magaza |
| `avm-akasya` | Akasya AVM Standı | avm |

`id` kısa, boşluksuz, Türkçe karaktersiz olmalı — ekranlar bununla tanınacak.

---

## 5. Personel hesapları

Sol menü → **Authentication → Users → Add user**.
Kasa personeli için e-posta + şifre oluştur. Bu hesaplar **yönetim paneline**
(Faz 2) girecek. Müşteri hesabı yok, müşteri hiçbir yere giriş yapmıyor.

---

## Kontrol listesi

- [ ] Proje kuruldu (Frankfurt, Free)
- [ ] `schema.sql` çalıştırıldı, 7 tablo göründü
- [ ] Project URL + anon key bana verildi
- [ ] service_role anahtarı **paylaşılmadı**
- [ ] Şubeler girildi
- [ ] En az 1 personel hesabı açıldı
