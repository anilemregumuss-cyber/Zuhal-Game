-- =============================================================================
-- MIGRATION 002 — Faz 2 öncesi kapatılması gereken iki güvenlik açığı
-- Hedef: schema.sql'deki "oyun" şeması (henüz commit edilmemiş/uygulanmamış olabilir —
-- önce schema.sql, sonra bu dosya uygulanmalı).
--
--   1) KUPON UYDURULABİLİYOR
--      p_kuponlar_insert politikası anon'a serbest INSERT veriyor. anon anahtarı
--      tarayıcıda göründüğü için isteyen kendine istediği ödülde kupon yazabilir —
--      "kullanildi=false" şartı bunu engellemiyor, sadece "kullanılmış doğmasını"
--      engelliyor. Kasa Faz 2'de kuponu veritabanından doğrulayacaksa bu delik
--      doğrulamanın anlamını kaldırır.
--
--   2) SON ÖDÜL YARIŞI HÂLÂ AÇIK
--      odul_sec yalnızca sayıp cevap veriyor, kuponu AYIRMIYOR. Karar ile kupon
--      yazımı iki ayrı adım olduğu için iki ekran aynı anda "verilebilir" cevabı
--      alabilir (son bez çanta / son AKD1AY kontenjanı iki kişiye birden çıkabilir).
--
-- ÇÖZÜM: kupon üretimini TEK security-definer fonksiyona topluyoruz. Fonksiyon,
-- karar verdiği ödülün limitler satırını "for update" ile kilitleyerek karar +
-- kupon yazımını aynı transaction'da yapıyor — aynı ödül için eşzamanlı çağrılar
-- bu kilitte sıraya girer, ikinci çağrı ilkinin yazdığı sayacı görerek karar verir.
-- anon'un kuponlar tablosuna doğrudan INSERT hakkı tamamen kaldırılıyor; tek giriş
-- noktası bu fonksiyon oluyor.
--
-- NOT: kupon_uret çağrılmadan önce telefon dolu geçiliyorsa oyun.oyuncu_kaydet()
-- ile önceden kaydedilmiş olmalı — kuponlar.telefon, oyuncular'a FK'dir, kayıtsız
-- bir telefonla çağırmak hata döndürür (kasıtlı, mevcut şemanın davranışı).
--
-- Uygulama: psql "postgresql://anil:<sifre>@db.cglwmzrsbzuirlwgfxqc.supabase.co:5432/postgres" -f supabase/002_kupon_guvenligi_ve_son_odul_kilidi.sql
-- Tekrar çalıştırılabilir (idempotent).
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1) Kupon uydurma deliğini kapat: anon/authenticated artık kuponlar'a
--    DOĞRUDAN yazamaz. Tek yol aşağıdaki oyun.kupon_uret() fonksiyonu.
-- -----------------------------------------------------------------------------

drop policy if exists p_kuponlar_insert on oyun.kuponlar;
revoke insert on oyun.kuponlar from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2) addOneMonth() portu (index.html'deki JS ile birebir aynı davranmalı):
--    ay sonunu kırpar, taşırmaz (31 Ocak + 1 ay -> 28/29 Şubat, 3 Mart'a DEĞİL).
--    index.html'deki addOneMonth değişirse bu fonksiyon da güncellenmeli.
-- -----------------------------------------------------------------------------

create or replace function oyun.son_kullanma(p_gun date)
returns date language sql immutable as $$
  select least(
    p_gun + interval '1 month',
    date_trunc('month', p_gun) + interval '2 month' - interval '1 day'
  )::date;
$$;

-- -----------------------------------------------------------------------------
-- 3) Karar + kupon üretimi TEK fonksiyonda, ilgili limit satırı kilitli.
--
--    p_odul_istenen : oyunun ham sonucuna göre istenen ödül kodu (örn. "perfect"
--                      sonucu -> 'AKD1AY'). Sonuç -> ödül eşlemesi çağıran tarafta
--                      yapılır, bu fonksiyon yalnızca STOK/LİMİT kararını verir.
--    Dönen ödül istenenden farklıysa (limit doluysa) yedek_odul'e düşülür; o da
--    dolu/tanımsızsa kupon üretilmez ({ok:true, kod:null}) — ÇALIŞMAYA DEVAM'daki
--    gibi hediyesiz sonuç, hata değil.
-- -----------------------------------------------------------------------------

create or replace function oyun.kupon_uret(
  p_odul_istenen text,
  p_konum        text,
  p_oyun_kod     text,
  p_ad           text,
  p_telefon      text default null
) returns jsonb
language plpgsql security definer
set search_path = oyun, public as $$
declare
  v_bugun      date := (now() at time zone 'Europe/Istanbul')::date;
  v_odul       text := p_odul_istenen;
  v_odul_ad    text;
  l            oyun.limitler%rowtype;
  v_konum_f    text;
  v_toplam     int;
  v_gunluk     int;
  v_gun_sinir  int;
  v_tel        text := oyun.tel_normalize(p_telefon);
  v_kod        text;
  v_gecerlilik date;
  v_dusme      int := 0;
  v_try        int;
begin
  if p_konum is null or not exists (select 1 from oyun.konumlar where id = p_konum and aktif) then
    return jsonb_build_object('ok', false, 'hata', 'GECERSIZ_KONUM');
  end if;
  if p_oyun_kod is null or not exists (select 1 from oyun.oyunlar where kod = p_oyun_kod and aktif) then
    return jsonb_build_object('ok', false, 'hata', 'GECERSIZ_OYUN');
  end if;

  -- Ödülsüz sonuç (örn. ÇALIŞMAYA DEVAM): kupon yok, hata da yok.
  if v_odul is null then
    return jsonb_build_object('ok', true, 'kod', null, 'odul_kod', null);
  end if;

  -- Mevcut ödül merdiveninde yedekler hep sınırsız; yine de zincirleme düşüşe
  -- karşı güvenlik payı olarak en fazla 5 kademe iniyoruz.
  loop
    select * into l from oyun.limitler where odul_kod = v_odul and aktif for update;

    if not found then
      exit; -- limiti tanımlı değil = sınırsız, olduğu gibi ver
    end if;

    v_konum_f := case when l.kapsam = 'konum' then p_konum else null end;

    if l.toplam_limit is not null then
      v_toplam := oyun.kupon_sayisi(v_odul, v_konum_f, null);
      if v_toplam >= l.toplam_limit then
        v_odul := l.yedek_odul;
        v_dusme := v_dusme + 1;
        exit when v_odul is null or v_dusme > 5;
        continue;
      end if;
    end if;

    select adet into v_gun_sinir from oyun.stoklar
     where konum_id = p_konum and tarih = v_bugun and odul_kod = l.odul_kod;
    if v_gun_sinir is null then v_gun_sinir := l.gunluk_limit; end if;

    if v_gun_sinir is not null then
      v_gunluk := oyun.kupon_sayisi(v_odul, p_konum, v_bugun);
      if v_gunluk >= v_gun_sinir then
        v_odul := l.yedek_odul;
        v_dusme := v_dusme + 1;
        exit when v_odul is null or v_dusme > 5;
        continue;
      end if;
    end if;

    exit; -- bu ödül veriliyor; limitler satırı transaction sonuna kadar kilitli kalır
  end loop;

  if v_odul is null then
    return jsonb_build_object('ok', true, 'kod', null, 'odul_kod', null);
  end if;

  -- odul_ad'ı ayrıca ve koşulsuz çek: yukarıdaki döngü "limit tanımlı değil"
  -- dalından çıkmışsa l boş kalmış olabilir.
  select odul_ad into v_odul_ad from oyun.limitler where odul_kod = v_odul;
  if v_odul_ad is null then v_odul_ad := v_odul; end if;

  v_gecerlilik := oyun.son_kullanma(v_bugun);

  -- Kod çakışması pratikte imkansıza yakın (4 haneli rastgele + ödül + gün) ama
  -- primary key ihlaline karşı birkaç deneme hakkı bırakıyoruz.
  for v_try in 1..5 loop
    v_kod := 'HT50-' || v_odul || '-' ||
             to_char(now() at time zone 'Europe/Istanbul', 'DDMM') || '-' ||
             lpad(floor(random() * 10000)::int::text, 4, '0');
    begin
      insert into oyun.kuponlar (kod, konum_id, oyun_kod, ad, telefon, odul_kod, odul_ad, gecerlilik)
      values (v_kod, p_konum, p_oyun_kod, p_ad, v_tel, v_odul, v_odul_ad, v_gecerlilik);
      exit;
    exception when unique_violation then
      if v_try = 5 then
        return jsonb_build_object('ok', false, 'hata', 'KOD_URETILEMEDI');
      end if;
    end;
  end loop;

  return jsonb_build_object(
    'ok', true, 'kod', v_kod, 'odul_kod', v_odul,
    'odul_ad', v_odul_ad, 'gecerlilik', v_gecerlilik
  );
end $$;

revoke all on function oyun.kupon_uret(text, text, text, text, text) from public;
grant execute on function oyun.kupon_uret(text, text, text, text, text) to anon, authenticated;

commit;
