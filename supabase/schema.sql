-- =============================================================================
-- ZUHAL OYUN PLATFORMU — VERİTABANI ŞEMASI
-- Supabase (PostgreSQL). Supabase panelinde SQL Editor'e yapıştırıp çalıştır.
-- Tekrar çalıştırılabilir: her şey "if not exists" / "or replace" ile yazıldı.
--
-- OKUMA REHBERİ (teknik değilsen buradan oku):
--   "table"  = Excel sayfası.  "column" = sütun.  satır = tek bir kayıt.
--   "rls"    = satır güvenliği. Ekrandaki anahtar herkese açık olduğu için,
--              kimin neyi görebileceğini veritabanının kendisi kısıtlar.
--   "rpc"    = veritabanının içinde çalışan mini program. Ekran ham veriyi
--              görmeden sadece sonucu alır (örn. "kaç kupon verilmiş: 7").
-- =============================================================================


-- =============================================================================
-- 1) TABLOLAR
-- =============================================================================

-- ŞUBELER ---------------------------------------------------------------------
-- Her ekran hangi şubede olduğunu bilir ve her kayıt bunu taşır.
-- tip='avm' olan şubelerde kupon MAĞAZADA kullanılmak üzere verilir.
create table if not exists subeler (
  id        text primary key,                    -- 'kadikoy', 'avm-akasya'
  ad        text not null,                       -- 'Zuhal Müzik Kadıköy'
  tip       text not null default 'magaza' check (tip in ('magaza', 'avm')),
  aktif     boolean not null default true,
  olusturma timestamptz not null default now()
);

-- OYUNLAR ---------------------------------------------------------------------
-- Oyun paneli (Faz 3) menüyü buradan kuracak. Şimdiden var, çünkü kayıtlar
-- hangi oyundan geldiğini baştan yazsın — sonradan eklenirse eski veri boş kalır.
create table if not exists oyunlar (
  kod       text primary key,                    -- 'ritim'
  ad        text not null,                       -- 'Rhythm Challenge'
  aciklama  text,
  aktif     boolean not null default true,
  sira      int not null default 0,              -- menüde görünme sırası
  olusturma timestamptz not null default now()
);

-- OYUNCULAR -------------------------------------------------------------------
-- Telefon = kişinin kimliği. Aynı kişi farklı şubede oynasa da tek satır.
-- KVKK: pazarlama rızası AYRI tutulur; rıza vermeyen de oynar, ödül alır.
-- Rıza geri çekilirse riza=false yapılır, oyun geçmişi silinmez (istatistik).
create table if not exists oyuncular (
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
create table if not exists kayitlar (
  id          uuid primary key default gen_random_uuid(),
  sube_id     text not null references subeler(id),
  oyun_kod    text not null references oyunlar(kod),
  cihaz_id    text,                              -- aynı şubede birden fazla ekran olursa
  ad          text not null,
  telefon     text references oyuncular(telefon),
  sonuc       text not null,                     -- perfect / great / good / idareder / miss
  sapma_ms    int,                               -- vuruşun hedeften sapması
  deneme_no   int,
  kupon_kod   text,
  olusturma   timestamptz not null default now(),
  -- Ekran çevrimdışıyken üretilen kayıt sonra gönderilir; gerçek oynanma anı bu.
  oynanma     timestamptz not null default now()
);

create index if not exists kayitlar_sube_tarih_idx on kayitlar (sube_id, oynanma desc);
create index if not exists kayitlar_telefon_idx     on kayitlar (telefon);
create index if not exists kayitlar_oyun_idx        on kayitlar (oyun_kod, oynanma desc);

-- KUPONLAR --------------------------------------------------------------------
-- BUGÜNKÜ SİSTEMİN ÇÖZEMEDİĞİ ŞEY BURADA ÇÖZÜLÜYOR:
-- kupon AVM ekranında üretilir, MAĞAZADA kullanılır ve "kullanildi" işaretlenir.
-- Aynı kupon ikinci kez kullanılamaz.
create table if not exists kuponlar (
  kod              text primary key,             -- 'HT50-AKD1AY-1909-4821'
  sube_id          text not null references subeler(id),   -- kuponu VEREN şube
  oyun_kod         text not null references oyunlar(kod),
  ad               text not null,
  telefon          text references oyuncular(telefon),
  odul_kod         text not null,                -- 'AKD1AY'
  odul_ad          text not null,                -- 'AKADEMİ 1 AY 4 DERS'
  gecerlilik       date not null,                -- son kullanma günü (dahil)
  olusturma        timestamptz not null default now(),
  kullanildi       boolean not null default false,
  kullanan_sube_id text references subeler(id),  -- kuponu BOZAN şube
  kullanim_zamani  timestamptz,
  kullanan_personel uuid                         -- auth.users referansı
);

create index if not exists kuponlar_odul_idx    on kuponlar (odul_kod, olusturma desc);
create index if not exists kuponlar_telefon_idx on kuponlar (telefon);

-- ÖDÜL LİMİTLERİ --------------------------------------------------------------
-- Sınırlar artık KODDA DEĞİL, veritabanında. Böylece sınırı değiştirmek için
-- uygulamayı yeniden yayınlamak gerekmez — panelden rakam değiştirilir.
--   toplam_limit : kampanya boyu toplam (null = sınırsız)
--   gunluk_limit : gün başına (null = sınırsız)
--   kapsam       : 'global' = tüm şubeler ortak sayılır
--                  'sube'   = her şubenin kendi kotası var
create table if not exists limitler (
  odul_kod     text primary key,
  odul_ad      text not null,
  toplam_limit int,
  gunluk_limit int,
  kapsam       text not null default 'global' check (kapsam in ('global', 'sube')),
  -- Limit dolunca hangi ödüle düşülecek. null = düşme, ödülsüz kal.
  yedek_odul   text,
  aktif        boolean not null default true
);

-- GÜNLÜK STOK -----------------------------------------------------------------
-- Fiziksel ödüller (bez çanta) için: o gün o şubeye kaç adet konduğu.
-- Kayıt YOKSA limitler.gunluk_limit kullanılır. "Girilmiş 0" ile "girilmemiş"
-- ayrımı korunur — personel "bugün hiç çanta yok" diyebilmeli.
create table if not exists stoklar (
  sube_id   text not null references subeler(id),
  tarih     date not null,
  odul_kod  text not null,
  adet      int not null check (adet >= 0),
  giren     uuid,
  guncelleme timestamptz not null default now(),
  primary key (sube_id, tarih, odul_kod)
);


-- =============================================================================
-- 2) GÜVENLİK (RLS) — en kritik bölüm
--
-- Uygulamadaki "anon key" tarayıcıda görünür, yani herkesin elinde sayılır.
-- Bu yüzden kural şu:
--   ZİYARETÇİ (anon)  : sadece YAZAR. Müşteri listesini ASLA okuyamaz.
--   PERSONEL (authenticated) : okur, kupon bozar, stok girer.
-- =============================================================================

alter table subeler   enable row level security;
alter table oyunlar   enable row level security;
alter table limitler  enable row level security;
alter table stoklar   enable row level security;
alter table kayitlar  enable row level security;
alter table kuponlar  enable row level security;
alter table oyuncular enable row level security;

-- --- Herkes okuyabilir (hassas veri yok, ekranın çalışması için gerekli) ------
drop policy if exists p_subeler_read on subeler;
create policy p_subeler_read on subeler
  for select to anon, authenticated using (aktif);

drop policy if exists p_oyunlar_read on oyunlar;
create policy p_oyunlar_read on oyunlar
  for select to anon, authenticated using (true);

drop policy if exists p_limitler_read on limitler;
create policy p_limitler_read on limitler
  for select to anon, authenticated using (true);

drop policy if exists p_stoklar_read on stoklar;
create policy p_stoklar_read on stoklar
  for select to anon, authenticated using (true);

-- --- Ekran yazabilir, okuyamaz ------------------------------------------------
-- DİKKAT: "for insert" politikası SELECT hakkı VERMEZ. Yani kiosk kendi yazdığı
-- satırı bile geri okuyamaz. Kasıtlı: ekran çalınsa/kurcalansa müşteri listesi
-- çekilemesin.
drop policy if exists p_kayitlar_insert on kayitlar;
create policy p_kayitlar_insert on kayitlar
  for insert to anon, authenticated with check (true);

drop policy if exists p_kuponlar_insert on kuponlar;
create policy p_kuponlar_insert on kuponlar
  for insert to anon, authenticated with check (
    -- Ekran kuponu "kullanılmış" olarak oluşturamasın.
    kullanildi = false and kullanan_sube_id is null
  );

-- --- Personel her şeyi görür ---------------------------------------------------
drop policy if exists p_kayitlar_staff on kayitlar;
create policy p_kayitlar_staff on kayitlar
  for select to authenticated using (true);

drop policy if exists p_kuponlar_staff_read on kuponlar;
create policy p_kuponlar_staff_read on kuponlar
  for select to authenticated using (true);

drop policy if exists p_kuponlar_staff_update on kuponlar;
create policy p_kuponlar_staff_update on kuponlar
  for update to authenticated using (true) with check (true);

drop policy if exists p_oyuncular_staff on oyuncular;
create policy p_oyuncular_staff on oyuncular
  for select to authenticated using (true);

drop policy if exists p_stoklar_staff on stoklar;
create policy p_stoklar_staff on stoklar
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
-- =============================================================================

-- Telefon numarasını tek biçime indirger: sadece rakam, 0 ile başlayan 11 hane.
create or replace function tel_normalize(p_tel text)
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
create or replace function kupon_sayisi(
  p_odul  text,
  p_sube  text default null,     -- null = tüm şubeler
  p_gun   date default null      -- null = tüm zamanlar
) returns int
language sql security definer stable
set search_path = public as $$
  select count(*)::int from kuponlar
   where odul_kod = p_odul
     and (p_sube is null or sube_id = p_sube)
     and (p_gun  is null or (olusturma at time zone 'Europe/Istanbul')::date = p_gun);
$$;

-- ÖDÜL KARARI SUNUCUDA VERİLİR.
-- Neden: birden fazla ekran olunca son bez çantayı iki ekran aynı anda verebilir.
-- Sunucu tek karar noktası olduğu için bu imkansız hale gelir. Ayrıca sınırı
-- değiştirmek için uygulamayı yeniden yayınlamak gerekmez.
-- Dönen değer: verilebilecek ödülün kodu (limit doluysa yedek ödül, o da yoksa null).
create or replace function odul_sec(p_odul text, p_sube text)
returns text
language plpgsql security definer stable
set search_path = public as $$
declare
  l        limitler%rowtype;
  bugun    date := (now() at time zone 'Europe/Istanbul')::date;
  sube_f   text;
  toplam   int;
  gunluk   int;
  gun_sinir int;
begin
  select * into l from limitler where odul_kod = p_odul and aktif;
  if not found then
    return p_odul;                       -- limiti tanımlı değilse sınırsız
  end if;

  sube_f := case when l.kapsam = 'sube' then p_sube else null end;

  if l.toplam_limit is not null then
    toplam := kupon_sayisi(p_odul, sube_f, null);
    if toplam >= l.toplam_limit then
      return case when l.yedek_odul is null then null
                  else odul_sec(l.yedek_odul, p_sube) end;
    end if;
  end if;

  -- Günlük sınır: önce o güne elle girilmiş stok, yoksa limitler.gunluk_limit
  select adet into gun_sinir from stoklar
   where sube_id = p_sube and tarih = bugun and odul_kod = p_odul;
  if gun_sinir is null then gun_sinir := l.gunluk_limit; end if;

  if gun_sinir is not null then
    gunluk := kupon_sayisi(p_odul, p_sube, bugun);
    if gunluk >= gun_sinir then
      return case when l.yedek_odul is null then null
                  else odul_sec(l.yedek_odul, p_sube) end;
    end if;
  end if;

  return p_odul;
end $$;

-- Oyuncuyu kaydeder/günceller. Ekran oyuncular tablosuna doğrudan yazamadığı
-- için tek giriş noktası budur.
create or replace function oyuncu_kaydet(
  p_telefon text,
  p_ad      text,
  p_riza    boolean
) returns text
language plpgsql security definer
set search_path = public as $$
declare t text;
begin
  t := tel_normalize(p_telefon);
  if t is null then return null; end if;

  insert into oyuncular (telefon, ad, pazarlama_rizasi, riza_zamani, oyun_sayisi)
  values (t, p_ad, coalesce(p_riza, false),
          case when p_riza then now() else null end, 1)
  on conflict (telefon) do update set
    ad          = excluded.ad,
    son_oyun    = now(),
    oyun_sayisi = oyuncular.oyun_sayisi + 1,
    -- Rıza YALNIZCA verilirken güncellenir. Müşteri bir kez onay verdiyse,
    -- sonraki oyunda kutuyu işaretlemezse rızası silinmemeli — geri çekme
    -- ayrı ve bilinçli bir işlem olmalı (KVKK).
    pazarlama_rizasi = oyuncular.pazarlama_rizasi or coalesce(p_riza, false),
    riza_zamani = case
      when p_riza and not oyuncular.pazarlama_rizasi then now()
      else oyuncular.riza_zamani end;

  return t;
end $$;

-- Kasa personeli kuponu bozar. Tek işlemde kontrol + işaretleme yapar ki
-- aynı kupon iki kasada aynı anda bozulamasın.
create or replace function kupon_kullan(p_kod text, p_sube text)
returns jsonb
language plpgsql security definer
set search_path = public as $$
declare k kuponlar%rowtype;
begin
  select * into k from kuponlar where kod = p_kod for update;
  if not found then
    return jsonb_build_object('ok', false, 'hata', 'BULUNAMADI');
  end if;
  if k.kullanildi then
    return jsonb_build_object('ok', false, 'hata', 'ZATEN_KULLANILMIS',
                              'zaman', k.kullanim_zamani, 'sube', k.kullanan_sube_id);
  end if;
  if k.gecerlilik < (now() at time zone 'Europe/Istanbul')::date then
    return jsonb_build_object('ok', false, 'hata', 'SURESI_DOLMUS',
                              'gecerlilik', k.gecerlilik);
  end if;

  update kuponlar set kullanildi = true, kullanan_sube_id = p_sube,
                      kullanim_zamani = now(), kullanan_personel = auth.uid()
   where kod = p_kod;

  return jsonb_build_object('ok', true, 'ad', k.ad, 'odul', k.odul_ad,
                            'veren_sube', k.sube_id, 'gecerlilik', k.gecerlilik);
end $$;

-- Ekran (anon) yalnızca ödül kararı ve sayaç sorabilir. Kupon bozma personele ait.
revoke all on function kupon_kullan(text, text) from anon;
grant execute on function odul_sec(text, text)          to anon, authenticated;
grant execute on function kupon_sayisi(text, text, date) to anon, authenticated;
grant execute on function oyuncu_kaydet(text, text, boolean) to anon, authenticated;
grant execute on function kupon_kullan(text, text)      to authenticated;


-- =============================================================================
-- 4) BAŞLANGIÇ VERİSİ — kendi şube adlarınla değiştir
-- =============================================================================

insert into oyunlar (kod, ad, aciklama, sira) values
  ('ritim', 'Rhythm Challenge', 'Whitney Houston parçasında snare vuruşunu yakala', 1)
on conflict (kod) do nothing;

insert into subeler (id, ad, tip) values
  ('merkez', 'Zuhal Müzik (merkez)', 'magaza')
on conflict (id) do nothing;

-- Akademi kampanyası ödül limitleri (bugünkü koddaki değerlerle birebir aynı)
insert into limitler (odul_kod, odul_ad, toplam_limit, gunluk_limit, kapsam, yedek_odul) values
  ('AKD1AY', 'AKADEMİ 1 AY 4 DERS',    10,   1,    'global', 'AKDRS'),
  ('CANTA',  'ZUHAL BEZ ÇANTA',        null, 30,   'sube',   'AKD50'),
  ('AKDRS',  'ÜCRETSİZ DENEME DERSİ',  null, null, 'global', null),
  ('AKD50',  'AKADEMİDE İLK AY %50',   null, null, 'global', null)
on conflict (odul_kod) do nothing;
