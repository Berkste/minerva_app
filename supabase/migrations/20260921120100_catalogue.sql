-- Minerva Nail Art — the service catalogue, as data.
--
-- Transcribed from `dosyalar/minerva hizmet ve fiyat lsitesi.jpeg`, the salon's
-- own price list, on 2026-09-21.
--
-- Run after 20260921120000_schema.sql.
--
-- From here on this is staff's to maintain from the admin app; this file only
-- provides the starting point. It is written with `on conflict do update` so
-- re-running it restores the list to what the price list said, without
-- creating duplicates — but note that doing so overwrites any price staff have
-- since changed.
--
-- Prices are in whole Turkish lira. price_max is null for a fixed price; the
-- two open-ended extras carry a real range, which is why an appointment
-- records what was actually charged rather than deriving it from here.

-- ===========================================================================
-- Treatments — what a customer picks when booking
-- ===========================================================================

insert into public.services
  (id, kind, name_tr, name_en, description_tr, description_en,
   price_min, price_max, sort_order)
values
  ('protez_tirnak', 'main',
   'Protez Tırnak', 'Artificial Nails',
   'Medikal manikür + 2 tırnak Nail art', 'Medical manicure + nail art on 2 nails',
   1000, null, 10),

  ('protez_tirnak_bakim', 'main',
   'Protez Tırnak Bakım', 'Artificial Nail Care',
   'Medikal manikür + 2 tırnak Nail art', 'Medical manicure + nail art on 2 nails',
   900, null, 20),

  ('duz_kalici_oje', 'main',
   'Düz Kalıcı Oje', 'Classic Permanent Nail Polish',
   'Medikal manikür + 2 tırnak Nail art', 'Medical manicure + nail art on 2 nails',
   850, null, 30),

  ('jel_destekli_kalici_oje', 'main',
   'Jel Destekli Kalıcı Oje', 'Gel-Based Permanent Nail Polish',
   'Medikal manikür + 2 tırnak Nail art', 'Medical manicure + nail art on 2 nails',
   900, null, 40),

  ('ayak_kalici_oje', 'main',
   'Ayak Kalıcı Oje', 'Permanent Toenail Polish',
   null, null,
   1000, null, 50),

  ('medikal_manikur', 'main',
   'Medikal Manikür', 'Medical Manicure',
   null, null,
   450, null, 60),

  ('medikal_pedikur', 'main',
   'Medikal Pedikür', 'Medical Pedicure',
   null, null,
   600, null, 70)

on conflict (id) do update set
  kind           = excluded.kind,
  name_tr        = excluded.name_tr,
  name_en        = excluded.name_en,
  description_tr = excluded.description_tr,
  description_en = excluded.description_en,
  price_min      = excluded.price_min,
  price_max      = excluded.price_max,
  sort_order     = excluded.sort_order,
  is_active      = true,
  deleted_at     = null,
  updated_at     = now();

-- ===========================================================================
-- Extras — recorded by the salon, not offered at booking
-- ===========================================================================
-- Nail Art and Charm/Taş are priced as a range on the salon's list, so what a
-- customer is charged is decided on the day. Staff type the real figure when
-- they add the line; price_min is what it falls back to.

insert into public.services
  (id, kind, name_tr, name_en, description_tr, description_en,
   price_min, price_max, sort_order)
values
  ('sablon_sistem_protez', 'extra',
   'Şablon Sistem Protez', 'Template System Artificial Nails',
   null, null,
   1300, null, 10),

  ('nail_art', 'extra',
   'Nail Art', 'Nail Art',
   null, null,
   20, 300, 20),

  ('cat_eye', 'extra',
   'Cat Eye', 'Cat Eye',
   null, null,
   250, null, 30),

  ('french_ombre', 'extra',
   'French / Ombre', 'French / Ombré',
   null, null,
   350, null, 40),

  ('inci_krom_tozu', 'extra',
   'İnci / Krom Tozu', 'Pearl / Chrome Powder',
   null, null,
   250, null, 50),

  ('charm_tas', 'extra',
   'Charm / Taş', 'Charms / Gems',
   null, null,
   20, 300, 60),

  ('tek_tirnak_protez', 'extra',
   'Tek Tırnak Protez', 'Single Artificial Nail',
   null, null,
   50, null, 70),

  ('tirnak_cikarma', 'extra',
   'Tırnak Çıkarma', 'Nail Removal',
   null, null,
   350, null, 80)

on conflict (id) do update set
  kind           = excluded.kind,
  name_tr        = excluded.name_tr,
  name_en        = excluded.name_en,
  description_tr = excluded.description_tr,
  description_en = excluded.description_en,
  price_min      = excluded.price_min,
  price_max      = excluded.price_max,
  sort_order     = excluded.sort_order,
  is_active      = true,
  deleted_at     = null,
  updated_at     = now();

-- What landed:
select kind, count(*) as services, min(price_min) as cheapest, max(coalesce(price_max, price_min)) as dearest
from public.services
where deleted_at is null
group by kind
order by kind;
