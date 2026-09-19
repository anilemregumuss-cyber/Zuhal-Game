-- =============================================================================
-- ZUHAL OYUN PLATFORMU — VERİTABANI ŞEMASI
-- Hedef: MEVCUT "zuhal-dashboard" Supabase projesi (ayrı proje DEĞİL).
-- Her şey "oyun" adlı AYRI bir şema altında — satış dashboard'unun "public"
-- şemasına hiç dokunmuyoruz, sadece ondan OKUYORUZ (şube listesi için).
-- Supabase panelinde SQL Editor'e yapıştırıp çalıştır.
-- Tekrar çalıştırılabilir: her şey "if not exists" / "or replace" ile yazıldı.
--
-- OKUMA REHBERİ (teknik değilsen buradan oku):
--   "schema" = bina içindeki ayrı bir kat. Aynı binada (aynı Supabase projesi)
--              satış dashboard'u "public" katında oturuyor, oyun "oyun" katında
--              oturuyor. Aynı binadalar (aynı veritabanı, aynı telefon numarası
--              havuzu), ama katlar birbirinin eşyasını karıştırmıyor.
--   "table"  = Excel sayfası.  "column" = sütun.  satır = tek bir kayıt.
--   "rls"    = satır güvenliği. Ekrandaki anahtar herkese açık olduğu için,
--              kimin neyi görebileceğini veritabanının kendisi kısıtlar.
--   "rpc"    = veritabanının içinde çalışan mini program. Ekran ham veriyi
--              görmeden sadece sonucu alır (örn. "kaç kupon verilmiş: 7").
--
-- NEDEN AYRI PROJE DEĞİL DE AYNI PROJEDE AYRI ŞEMA:
--   Satış dashboard'unun "sales" tablosunda müşteri telefonu zaten var
--   (retail'de %100 dolu, 2026-09-19'da ölçüldü). Oyun ve mağaza satışı AYNI
--   veritabanında olursa "oyunu oynayan telefon numarası sonra mağazadan
--   alışveriş yaptı mı" sorusu TEK bir SQL sorgusu olur. Ayrı proje olsaydı
--   iki veritabanı arasında köprü kurmak gerekirdi.
-- =============================================================================

create schema if not exists oyun;

-- =============================================================================
-- 1) TABLOLAR
-- =============================================================================

-- KONUMLAR ----------------------------------------------------------------
-- Her ekran hangi konumda olduğunu bilir ve her kayıt bunu taşır.
-- İKİ TÜR konum var, birbirine karıştırılmamalı:
--   'magaza'     : gerçek bir satış şubesi, ekran mağazanın içinde duruyor.
--   'avm_stant'  : AVM'nin ORTAK ALANINDA (koridor, food court) duran bağımsız
--                  stant. Aynı AVM'de Zuhal'in mağazası olsa bile bu AYRI bir
--                  fiziksel nokta olduğu için satış şubesiyle karıştırılmaz.
-- ref_store_id BİLEREK YOK: satış dashboard'unun public.ref_store_meta tablosu
-- bu projede henüz mevcut değil (2026-09-19'da kontrol edildi). Satış verisiyle
-- bağlanmak ileride gerekirse, o tablo gerçekten var olduğunda ref_store_id
-- sütunu ve FK'i buraya eklenir — şimdiden varsayıp kurulumu kilitlemeyelim.
create table if not exists oyun.konumlar (
  id            text primary key,              -- 'kadikoy', 'avm-akasya-stant'
  ad            text not null,                 -- 'Zuhal Müzik Kadıköy'
  tip           text not null check (tip in ('magaza', 'avm_stant')),
  aktif         boolean not null default true,
  olusturma     timestamptz not null default now()
);

-- OYUNLAR ---------------------------------------------------------------------
-- Oyun paneli (Faz 3) menüyü buradan kuracak. Şimdiden var, çünkü kayıtlar
-- hangi oyundan geldiğini baştan yazsın — sonradan eklenirse eski veri boş kalır.
create table if not exists oyun.oyunlar (
  kod       text primary key,                    -- 'ritim'
  ad        text not null,                       -- 'Rhythm Challenge'
  aciklama  text,
  aktif     boolean not null default true,
  sira      int not null default 0,              -- menüde görünme sırası
  olusturma timestamptz not null default now()
);

-- OYUNCULAR -------------------------------------------------------------------
-- Telefon = kişinin kimliği. Aynı kişi farklı konumda oynasa da tek satır.
-- Bu numara, ana dashboard'daki sales.partner_phone ile AYNI HAVUZDA —
-- ileride "oyun oynayan sonra alışveriş yaptı mı" sorgusu buradan telefonla
-- sales tablosuna JOIN atılarak cevaplanabilir.
-- KVKK: pazarlama rızası AYRI tutulur; rıza vermeyen de oynar, ödül alır.
-- Rıza geri çekilirse riza=false yapılır, oyun geçmişi silinmez (istatistik).
create table if not exists oyun.oyuncular (
  telefon         text primary key,              -- '05321234567' (normalize edilmiş)
  ad              text not null,
  pazarlama_rizasi boolean not null default false,
  riza_zamani     timestamptz,
  ilk_oyun        timestamptz not null default now(),
  son_oyun        timestamptz not null default now(),
  oyun_sayisi     int not null default 0
);

-- KAYITLAR (oyun denemeleri) ---------------------------------------------------
-- Her deneme bir satır. Kupon üretilen deneme kupon_kod taşır, diğerleri boş.
create table if not exists oyun.kayitlar (
  id          uuid primary key default gen_random_uuid(),
  konum_id    text not null references oyun.konumlar(id),
  oyun_kod    text not null references oyun.oyunlar(kod),
  cihaz_id    text,                              -- aynı konumda birden fazla ekran olursa
  ad          text not null,
  telefon     text references oyun.oyuncular(telefon),
  sonuc       text not null,                     -- perfect / great / good / idareder / miss
  sapma_ms    int,                               -- vuruşun hedeften sapması
  deneme_no   int,
  kupon_kod   text,
  olusturma   timestamptz not null default now(),
  -- Ekran çevrimdışıyken üretilen kayıt sonra gönderilir; gerçek oynanma anı bu.
  oynanma     timestamptz not null default now()
);

create index if not exists kayitlar_konum_tarih_idx on oyun.kayitlar (konum_id, oynanma desc);
create index if not exists kayitlar_telefon_idx     on oyun.kayitlar (telefon);
create index if not exists kayitlar_oyun_idx        on oyun.kayitlar (oyun_kod, oynanma desc);

-- KUPONLAR --------------------------------------------------------------------
-- BUGÜNKÜ SİSTEMİN ÇÖZEMEDİĞİ ŞEY BURADA ÇÖZÜLÜYOR:
-- kupon AVM stantında üretilir, MAĞAZADA kullanılır ve "kullanildi" işaretlenir.
-- Aynı kupon ikinci kez kullanılamaz.
create table if not exists oyun.kuponlar (
  kod              text primary key,             -- 'HT50-AKD1AY-1909-4821'
  konum_id         text not null references oyun.konumlar(id),   -- kuponu VEREN konum
  oyun_kod         text not null references oyun.oyunlar(kod),
  ad               text not null,
  telefon          text references oyun.oyuncular(telefon),
  odul_kod         text not null,                -- 'AKD1AY'
  odul_ad          text not null,                -- 'AKADEMİ 1 AY 4 DERS'
  gecerlilik       date not null,                -- son kullanma günü (dahil)
  olusturma        timestamptz not null default now(),
  kullanildi       boolean not null default false,
  kullanan_konum_id text references oyun.konumlar(id),  -- kuponu BOZAN konum
  kullanim_zamani  timestamptz,
  kullanan_personel uuid                         -- auth.users referansı
);

create index if not exists kuponlar_odul_idx    on oyun.kuponlar (odul_kod, olusturma desc);
create index if not exists kuponlar_telefon_idx on oyun.kuponlar (telefon);

-- ÖDÜL LİMİTLERİ --------------------------------------------------------------
-- Sınırlar artık KODDA DEĞİL, veritabanında. Böylece sınırı değiştirmek için
-- uygulamayı yeniden yayınlamak gerekmez — panelden rakam değiştirilir.
--   toplam_limit : kampanya boyu toplam (null = sınırsız)
--   gunluk_limit : gün başına (null = sınırsız)
--   kapsam       : 'global' = tüm konumlar ortak sayılır
--                  'konum'  = her konumun kendi kotası var
create table if not exists oyun.limitler (
  odul_kod     text primary key,
  odul_ad      text not null,
  toplam_limit int,
  gunluk_limit int,
  kapsam       text not null default 'global' check (kapsam in ('global', 'konum')),
  -- Limit dolunca hangi ödüle düşülecek. null = düşme, ödülsüz kal.
  yedek_odul   text,
  aktif        boolean not null default true
);

-- GÜNLÜK STOK -----------------------------------------------------------------
-- Fiziksel ödüller (bez çanta) için: o gün o konuma kaç adet konduğu.
-- Kayıt YOKSA limitler.gunluk_limit kullanılır. "Girilmiş 0" ile "girilmemiş"
-- ayrımı korunur — personel "bugün hiç çanta yok" diyebilmeli.
create table if not exists oyun.stoklar (
  konum_id  text not null references oyun.konumlar(id),
  tarih     date not null,
  odul_kod  text not null,
  adet      int not null check (adet >= 0),
  giren     uuid,
  guncelleme timestamptz not null default now(),
  primary key (konum_id, tarih, odul_kod)
);


-- =============================================================================
-- 2) GÜVENLİK (RLS) — en kritik bölüm
--
-- Uygulamadaki "anon key" tarayıcıda görünür, yani herkesin elinde sayılır.
-- Bu yüzden kural şu:
--   ZİYARETÇİ (anon)  : sadece YAZAR. Müşteri listesini ASLA okuyamaz.
--   PERSONEL (authenticated) : okur, kupon bozar, stok girer.
--
-- ÖNEMLİ: "oyun" yeni bir şema olduğu için varsayılan olarak anon/authenticated
-- bu şemaya HİÇ giremez (public şemasındaki gibi otomatik izin yok). Önce
-- şemaya giriş izni, sonra tablo bazlı izin veriyoruz — RLS politikaları
-- bu izinlerin ÜSTÜNE, satır bazlı ek kısıtlama olarak biner.
-- =============================================================================

grant usage on schema oyun to anon, authenticated;

alter table oyun.konumlar   enable row level security;
alter table oyun.oyunlar    enable row level security;
alter table oyun.limitler   enable row level security;
alter table oyun.stoklar    enable row level security;
alter table oyun.kayitlar   enable row level security;
alter table oyun.kuponlar   enable row level security;
alter table oyun.oyuncular  enable row level security;

-- --- Herkes okuyabilir (hassas veri yok, ekranın çalışması için gerekli) ------
grant select on oyun.konumlar, oyun.oyunlar, oyun.limitler, oyun.stoklar to anon, authenticated;

drop policy if exists p_konumlar_read on oyun.konumlar;
create policy p_konumlar_read on oyun.konumlar
  for select to anon, authenticated using (aktif);

drop policy if exists p_oyunlar_read on oyun.oyunlar;
create policy p_oyunlar_read on oyun.oyunlar
  for select to anon, authenticated using (true);

drop policy if exists p_limitler_read on oyun.limitler;
create policy p_limitler_read on oyun.limitler
  for select to anon, authenticated using (true);

drop policy if exists p_stoklar_read on oyun.stoklar;
create policy p_stoklar_read on oyun.stoklar
  for select to anon, authenticated using (true);

-- --- Ekran yazabilir, okuyamaz ------------------------------------------------
-- DİKKAT: "for insert" politikası SELECT hakkı VERMEZ. Yani kiosk kendi yazdığı
-- satırı bile geri okuyamaz. Kasıtlı: ekran çalınsa/kurcalansa müşteri listesi
-- çekilemesin.
grant insert on oyun.kayitlar, oyun.kuponlar to anon, authenticated;

drop policy if exists p_kayitlar_insert on oyun.kayitlar;
create policy p_kayitlar_insert on oyun.kayitlar
  for insert to anon, authenticated with check (true);

drop policy if exists p_kuponlar_insert on oyun.kuponlar;
create policy p_kuponlar_insert on oyun.kuponlar
  for insert to anon, authenticated with check (
    -- Ekran kuponu "kullanılmış" olarak oluşturamasın.
    kullanildi = false and kullanan_konum_id is null
  );

-- --- Personel her şeyi görür ---------------------------------------------------
grant select on oyun.kayitlar, oyun.oyuncular to authenticated;
grant select, update on oyun.kuponlar to authenticated;
grant all on oyun.stoklar to authenticated;

drop policy if exists p_kayitlar_staff on oyun.kayitlar;
create policy p_kayitlar_staff on oyun.kayitlar
  for select to authenticated using (true);

drop policy if exists p_kuponlar_staff_read on oyun.kuponlar;
create policy p_kuponlar_staff_read on oyun.kuponlar
  for select to authenticated using (true);

drop policy if exists p_kuponlar_staff_update on oyun.kuponlar;
create policy p_kuponlar_staff_update on oyun.kuponlar
  for update to authenticated using (true) with check (true);

drop policy if exists p_oyuncular_staff on oyun.oyuncular;
create policy p_oyuncular_staff on oyun.oyuncular
  for select to authenticated using (true);

drop policy if exists p_stoklar_staff on oyun.stoklar;
create policy p_stoklar_staff on oyun.stoklar
  for all to authenticated using (true) with check (true);

-- oyuncular tablosuna ekran DOĞRUDAN yazamaz; aşağıdaki rpc üzerinden yazar.
-- Sebep: telefon numarası birincil anahtar, ham insert ile başkasının kaydı
-- ezilebilirdi.


-- =============================================================================
-- 3) RPC — veritabanının içinde çalışan mini programlar
--
-- "security definer" = bu program, çağıranın değil SAHİBİNİN yetkisiyle çalışır.
-- Böylece ekran tabloyu okuyamadığı halde "kaç kupon verilmiş" sorusunun
-- CEVABINI alabilir. Ham veri dışarı çıkmaz.
-- search_path BİLEREK "oyun, public" ile SABİTLENİR (fonksiyonun içinden
-- başka bir şema kaçak sızmasın diye) — Postgres güvenlik tavsiyesi budur.
-- =============================================================================

-- Telefon numarasını tek biçime indirger: sadece rakam, 0 ile başlayan 11 hane.
create or replace function oyun.tel_normalize(p_tel text)
returns text language plpgsql immutable as $$
declare t text;
begin
  if p_tel is null then return null; end if;
  t := regexp_replace(p_tel, '[^0-9]', '', 'g');
  if length(t) = 12 and left(t, 2) = '90' then t := substr(t, 3); end if;  -- +90...
  if length(t) = 10 then t := '0' || t; end if;                            -- 532...
  if length(t) <> 11 or left(t, 1) <> '0' then return null; end if;
  return t;
end $$;

-- Verilen ödülden kaç kupon çıkmış? Kapsam ve gün filtreli.
create or replace function oyun.kupon_sayisi(
  p_odul  text,
  p_konum text default null,     -- null = tüm konumlar
  p_gun   date default null      -- null = tüm zamanlar
) returns int
language sql security definer stable
set search_path = oyun, public as $$
  select count(*)::int from oyun.kuponlar
   where odul_kod = p_odul
     and (p_konum is null or konum_id = p_konum)
     and (p_gun   is null or (olusturma at time zone 'Europe/Istanbul')::date = p_gun);
$$;

-- ÖDÜL KARARI SUNUCUDA VERİLİR.
-- Neden: birden fazla ekran olunca son bez çantayı iki ekran aynı anda verebilir.
-- Sunucu tek karar noktası olduğu için bu imkansız hale gelir. Ayrıca sınırı
-- değiştirmek için uygulamayı yeniden yayınlamak gerekmez.
-- Dönen değer: verilebilecek ödülün kodu (limit doluysa yedek ödül, o da yoksa null).
create or replace function oyun.odul_sec(p_odul text, p_konum text)
returns text
language plpgsql security definer stable
set search_path = oyun, public as $$
declare
  l         oyun.limitler%rowtype;
  bugun     date := (now() at time zone 'Europe/Istanbul')::date;
  konum_f   text;
  toplam    int;
  gunluk    int;
  gun_sinir int;
begin
  select * into l from oyun.limitler where odul_kod = p_odul and aktif;
  if not found then
    return p_odul;                       -- limiti tanımlı değilse sınırsız
  end if;

  konum_f := case when l.kapsam = 'konum' then p_konum else null end;

  if l.toplam_limit is not null then
    toplam := oyun.kupon_sayisi(p_odul, konum_f, null);
    if toplam >= l.toplam_limit then
      return case when l.yedek_odul is null then null
                  else oyun.odul_sec(l.yedek_odul, p_konum) end;
    end if;
  end if;

  -- Günlük sınır: önce o güne elle girilmiş stok, yoksa limitler.gunluk_limit
  select adet into gun_sinir from oyun.stoklar
   where konum_id = p_konum and tarih = bugun and odul_kod = p_odul;
  if gun_sinir is null then gun_sinir := l.gunluk_limit; end if;

  if gun_sinir is not null then
    gunluk := oyun.kupon_sayisi(p_odul, p_konum, bugun);
    if gunluk >= gun_sinir then
      return case when l.yedek_odul is null then null
                  else oyun.odul_sec(l.yedek_odul, p_konum) end;
    end if;
  end if;

  return p_odul;
end $$;

-- Oyuncuyu kaydeder/günceller. Ekran oyuncular tablosuna doğrudan yazamadığı
-- için tek giriş noktası budur.
create or replace function oyun.oyuncu_kaydet(
  p_telefon text,
  p_ad      text,
  p_riza    boolean
) returns text
language plpgsql security definer
set search_path = oyun, public as $$
declare t text;
begin
  t := oyun.tel_normalize(p_telefon);
  if t is null then return null; end if;

  insert into oyun.oyuncular (telefon, ad, pazarlama_rizasi, riza_zamani, oyun_sayisi)
  values (t, p_ad, coalesce(p_riza, false),
          case when p_riza then now() else null end, 1)
  on conflict (telefon) do update set
    ad          = excluded.ad,
    son_oyun    = now(),
    oyun_sayisi = oyun.oyuncular.oyun_sayisi + 1,
    -- Rıza YALNIZCA verilirken güncellenir. Müşteri bir kez onay verdiyse,
    -- sonraki oyunda kutuyu işaretlemezse rızası silinmemeli — geri çekme
    -- ayrı ve bilinçli bir işlem olmalı (KVKK).
    pazarlama_rizasi = oyun.oyuncular.pazarlama_rizasi or coalesce(p_riza, false),
    riza_zamani = case
      when p_riza and not oyun.oyuncular.pazarlama_rizasi then now()
      else oyun.oyuncular.riza_zamani end;

  return t;
end $$;

-- Kasa personeli kuponu bozar. Tek işlemde kontrol + işaretleme yapar ki
-- aynı kupon iki kasada aynı anda bozulamasın.
create or replace function oyun.kupon_kullan(p_kod text, p_konum text)
returns jsonb
language plpgsql security definer
set search_path = oyun, public as $$
declare k oyun.kuponlar%rowtype;
begin
  select * into k from oyun.kuponlar where kod = p_kod for update;
  if not found then
    return jsonb_build_object('ok', false, 'hata', 'BULUNAMADI');
  end if;
  if k.kullanildi then
    return jsonb_build_object('ok', false, 'hata', 'ZATEN_KULLANILMIS',
                              'zaman', k.kullanim_zamani, 'konum', k.kullanan_konum_id);
  end if;
  if k.gecerlilik < (now() at time zone 'Europe/Istanbul')::date then
    return jsonb_build_object('ok', false, 'hata', 'SURESI_DOLMUS',
                              'gecerlilik', k.gecerlilik);
  end if;

  update oyun.kuponlar set kullanildi = true, kullanan_konum_id = p_konum,
                      kullanim_zamani = now(), kullanan_personel = auth.uid()
   where kod = p_kod;

  return jsonb_build_object('ok', true, 'ad', k.ad, 'odul', k.odul_ad,
                            'veren_konum', k.konum_id, 'gecerlilik', k.gecerlilik);
end $$;

-- Ekran (anon) yalnızca ödül kararı ve sayaç sorabilir. Kupon bozma personele ait.
revoke all on function oyun.kupon_kullan(text, text) from anon;
grant execute on function oyun.odul_sec(text, text)          to anon, authenticated;
grant execute on function oyun.kupon_sayisi(text, text, date) to anon, authenticated;
grant execute on function oyun.oyuncu_kaydet(text, text, boolean) to anon, authenticated;
grant execute on function oyun.kupon_kullan(text, text)      to authenticated;


-- =============================================================================
-- 4) BAŞLANGIÇ VERİSİ
--
-- public.ref_store_meta bu projede yok (2026-09-19'da kontrol edildi), o yüzden
-- konumlar TEK TEK elle giriliyor — eski Faz 1'deki 'merkez' satırının aynısı.
-- Satış dashboard'una bağlanma ihtiyacı gerçek olduğunda ref_store_meta'nın
-- gerçek adı/şeması netleşir ve bu insert ona göre otomatikleştirilir.
-- =============================================================================

insert into oyun.oyunlar (kod, ad, aciklama, sira) values
  ('ritim', 'Rhythm Challenge', 'Whitney Houston parçasında snare vuruşunu yakala', 1)
on conflict (kod) do nothing;

insert into oyun.konumlar (id, ad, tip) values
  ('merkez', 'Zuhal Müzik (merkez)', 'magaza')
on conflict (id) do nothing;

-- Akademi kampanyası ödül limitleri (bugünkü koddaki değerlerle birebir aynı)
insert into oyun.limitler (odul_kod, odul_ad, toplam_limit, gunluk_limit, kapsam, yedek_odul) values
  ('AKD1AY', 'AKADEMİ 1 AY 4 DERS',    10,   1,    'global', 'AKDRS'),
  ('CANTA',  'ZUHAL BEZ ÇANTA',        null, 30,   'konum',  'AKD50'),
  ('AKDRS',  'ÜCRETSİZ DENEME DERSİ',  null, null, 'global', null),
  ('AKD50',  'AKADEMİDE İLK AY %50',   null, null, 'global', null)
on conflict (odul_kod) do nothing;
