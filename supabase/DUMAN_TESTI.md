# Duman testi — canlı veritabanı raporu

**Proje:** `dycjvupgvuxkguorzaqz` · **Tarih:** 2026-09-24 · **Sonuç:** ✅ 28 adım, 0 uyarı

Müşteri tarafı test edildi. Personel tarafı sende — şifresini paylaşmadın, doğru
olan da buydu.

---

## Nasıl çalıştırıldı, ve neden öyle

Testi Flutter'ın kendi istemcisiyle yazdım, ama **çalıştıramadım**: bu ortamda
Dart'ın internet erişimi engelli. Her adres — `example.com` dahil — başlıksız bir
`400` dönüyor, aynı adresler `curl` ile `200`. Yani uygulamayla ilgisi yok,
ortamın kısıtı.

Bunun üzerine testi doğrudan REST API'ye karşı yürüttüm: uygulamanın çağırdığı
**aynı RPC'ler** (`book_appointment`, `claim_customer`, `booked_slots`,
`closed_days`), aynı tablolar, aynı anonim oturumlar.

**Bunun kapsadığı:** kuralların canlıda gerçekten çalışması.
**Kapsamadığı:** uygulamanın o kodları cümleye çevirmesi — o `error_mapping_test.dart`
ile birim testli — ve ekranların görünümü.

Her cihaz kendi anonim oturumu. Yarış testinin gerçek bir yarış olmasının sebebi
bu: üç ayrı oturum, aynı anda, aynı slota.

---

## Adım adım sonuçlar

### A · Kimse randevu almadan önce

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 01 | Katalog oturumsuz okundu | ✅ 7 ana işlem, fiyatlar listeyle birebir: Protez Tırnak 1000, Protez Tırnak Bakım 900, Düz Kalıcı Oje 850, Jel Destekli Kalıcı Oje 900, Ayak Kalıcı Oje 1000, Medikal Manikür 450, Medikal Pedikür 600 |
| 02 | Önümüzdeki Pazar (2026-09-27) sorgulandı | ✅ Kapalı döndü |
| 03 | Oturumsuz randevu okuma denendi | ✅ HTTP 200 ama **0 satır** — RLS hiçbir şey vermiyor |

### B · İlk randevu

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 04 | Anonim cihaz açıldı | ✅ |
| 05 | Randevu almadan kişi sorgulandı | ✅ 0 — kimlik yok |
| 06 | Ad + telefon, **soyadsız** randevu | ✅ Alındı, `last_name = null`, `created_by_admin = false` |
| 07 | Cihazın kişisi okundu | ✅ Tek kişi, doğru numara |
| 08 | Cihaz kendi randevularını gördü | ✅ 1 |
| 09 | `booked_slots` herkese açık okundu | ✅ Yalnızca saat döndü, kimin olduğu değil |

### C · Üzerine her şeyin kurulu olduğu garanti

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 10 | **Üç ayrı cihaz, aynı slot, aynı an** | ✅ `200 · 409/23505 · 409/23505` |
| 11 | Sayım | ✅ **Kazanan 1, kaybeden 2** |
| 12 | Sonradan gelen dördüncü deneme | ✅ `23505` |

İki ayrı koşuda yarışı **farklı cihazlar kazandı** — yani gerçekten yarışıyorlar,
sıra garantili değil. Kaybedenler çökmüyor, temiz bir "slot dolu" alıyor.

### D · Üç haftada bir

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 13 | Pencere içinde ikinci randevu | ✅ `MN002` — *"…already has one on 2026-11-05"* |
| 14 | Reddedilenden sonra randevu sayısı | ✅ Hâlâ 1 — **geri alma çalıştı** |
| 15 | Pencere içinde **önceki** bir güne | ✅ `MN002` — kural simetrik |
| 16 | Tam 21 gün sonrası | ✅ Kabul — sınır doğru tarafta kapsayıcı |

13. adım özellikle önemli: mesaj çakışan tarihi **söylüyor**. Uygulama bundan
"en erken 26 Kasım" cümlesini kuruyor; "şu an alamazsınız" demek yetmezdi.

14. adım da öyle: `book_appointment` kişiyi oluşturup randevuyu yazmayı tek
transaction'da yaptığı için, reddedilen bir deneme **hiçbir iz bırakmıyor**.

### E · Diğer kurallar

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 17 | Pazar'a randevu | ✅ `MN003` |
| 18 | Düne randevu | ✅ `MN001` |
| 19 | Aynı numara, yanlış ad | ✅ `MN005` |

### F · Başka bir cihazdan dönmek

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 20 | İkinci cihaz, `"  ayse "` ile sahiplendi | ✅ **Aynı kişi** döndü — büyük/küçük harf ve boşluk affediliyor |
| 21 | O cihaz kişinin randevularını gördü | ✅ 2 |

Telefonu kimlik yapmanın bütün amacı buydu: cihaz değişse de kişi aynı kalıyor.

### G · Kendi bilgileri, kendi randevuları

| # | Ne yapıldı | Sonuç |
|---|---|---|
| 22 | Profile soyad eklendi | ✅ Kişi "Ayse Yilmaz" oldu, **ilk randevu hâlâ "Ayse"** |
| 23 | Randevu 14:00 → 18:00 taşındı | ✅ Taşındı, çoğalmadı |
| 24 | Dolu slota taşıma | ✅ `23505` |
| 25 | Randevu iptal edildi | ✅ |
| 26 | İptal edilen slot | ✅ Serbest kaldı |
| 27–28 | Bütün randevular iptalken pencere içine randevu | ✅ Kabul — iptal pencereyi bırakıyor |

---

## Artılar

- **Çifte rezervasyon imkânsız.** Üç eşzamanlı denemeden tam biri geçti, ikisi
  temiz kaybetti. Projenin bütün tasarımı bunun üstüne kuruluydu ve canlıda
  çalışıyor.
- **Reddedilen denemeler veritabanını kirletmiyor** — kişi oluşturma randevuyla
  aynı transaction'da.
- **Hata mesajları işe yarar bilgi taşıyor.** `MN002` çakışan tarihi söylüyor.
- **Gizlilik tutuyor.** Oturumsuz çağıran randevu göremiyor, `booked_slots`
  yalnızca saat veriyor.
- **Geçmiş değişmiyor.** Profil düzenlemek eski randevunun ismini bozmuyor.
- **Telefon gerçekten kimlik.** Yeni cihaz doğru adla aynı kişiye bağlanıyor.
- Beş kural kodunun beşi de doğru yerde ateşleniyor: `MN001`, `MN002`, `MN003`,
  `MN005` ve unique index'in `23505`'i.

## Eksiler ve notlar

**1. Reddedilen bir randevu denemesi anonim kullanıcı bırakıyor.**
Kişi ve randevu geri alınıyor ama `auth.users` satırı kalıyor — oturum açma,
randevu transaction'ından önce oluyor. Zararsız ama birikir: bu testin 21 anonim
kullanıcısının çoğu böyle oluştu. Gerçek kullanımda her "denedi, reddedildi"
bir satır demek.

**2. Kural sırası mesajı belirliyor.** Pencere kontrolü unique index'ten önce
çalışıyor. Dolu bir slota *pencere içinden* taşımaya çalışan kişi "bu saat dolu"
değil "üç haftada bir" mesajı alıyor. İkisi de doğru, ama ilki daha yardımcı
olurdu. İlk yazdığım test bu yüzden yanlış şeyi ölçüyordu; düzelttim.

**3. `MN004` (son bir saat iptal kuralı) test edilemedi.** Müşteri kendi başına
bir saat içinde başlayan randevu oluşturamıyor — `MN001` engelliyor. Sınamak için
personel yetkisi gerekiyor, o da sende.

**4. Personel tarafının tamamı test edilmedi.** Muafiyetler, `no_show` kilidi,
işlem/tutar girişi, istatistik — hepsi senin ekranlardan yapacağın kısım.

**5. `adminBook` atomik değil.** Kod incelemesinden: önce kişiyi arıyor/oluşturuyor,
sonra randevuyu yazıyor — iki ayrı çağrı. Slot doluysa **randevusuz bir kişi kaydı
kalıyor**. Müşteri tarafında bu sorun yok (tek RPC). Düzeltmesi müşteri tarafındaki
gibi bir `admin_book_appointment` RPC'si; şemaya dokunmak gerektiği için yapmadım.

**6. Ortam kısıtı.** Dart'ın ağ erişimi burada engelli olduğu için test REST
üzerinden yürüdü. Uygulamanın kod → cümle çevirisi canlıda doğrulanmadı; birim
testlerle kapsanıyor ama uçtan uca görmek istersen aşağıdaki komutu kendi
makinende çalıştırabilirsin.

---

## Veritabanında ne oluştu

Testi dört kez çalıştırdım (ikisi kısmi, ikisi tam). **Her satır `555999` ile
başlayan bir telefon numarası taşıyor** — temizlik bunu kullanıyor.

Yaklaşık beklenen:

| Tablo | Yaklaşık |
|---|---|
| `customers` | ~6 |
| `appointments` | ~8 (birkaçı iptal durumunda) |
| `appointment_services` | ~2 |
| `customer_devices` | ~6 |
| `auth.users` (anonim) | ~21 |

Kesin sayıyı aşağıdaki sorgu verir.

---

## Kontrol — önce bunu çalıştır

```sql
select 'customers' as tablo, count(*) as satir
from public.customers where phone like '555999%'
union all
select 'appointments', count(*)
from public.appointments where phone like '555999%'
union all
select 'appointment_services', count(*)
from public.appointment_services s
join public.appointments a on a.id = s.appointment_id
where a.phone like '555999%'
union all
select 'customer_devices', count(*)
from public.customer_devices d
join public.customers c on c.id = d.customer_id
where c.phone like '555999%'
union all
select 'auth.users (anonim)', count(*)
from auth.users where coalesce(is_anonymous, false);
```

Satırları tek tek görmek için:

```sql
select a.slot_date, a.slot_hour, a.status,
       a.first_name, a.last_name, a.phone,
       coalesce(sum(s.amount), 0) as tutar
from public.appointments a
left join public.appointment_services s
  on s.appointment_id = a.id and s.deleted_at is null
where a.phone like '555999%'
group by a.id
order by a.slot_date, a.slot_hour;
```

**Test dışı bir satır çıkarsa dur ve söyle.** `555999` ile başlayan gerçek bir
Türk cep numarası yok, ama kontrol etmeye değer.

---

## Silme

> ⚠️ Bu **gerçek silme**, soft delete değil. Projenin "hiçbir veri silinmez"
> kuralına bilinçli istisna: bu satırlar salonun geçmişi değil, testin kalıntısı.
> **Gerçek müşteriler girmeden önce** çalıştırılmalı.

```sql
begin;

-- Kişiyi silmek randevularını, işlem satırlarını ve cihaz bağını da götürür
-- (üçü de on delete cascade).
delete from public.customers
where phone like '555999%';

commit;
```

### Anonim kullanıcılar

Yukarıdaki `auth.users`'a dokunmaz; testin açtığı ~21 anonim oturum kalır. Önce say:

```sql
select count(*) as anonim_kullanicilar
from auth.users where coalesce(is_anonymous, false);
```

Sayı beklediğinse sil:

```sql
delete from auth.users where coalesce(is_anonymous, false);
```

> ⚠️ Bu sorgu **bütün** anonim kullanıcıları siler. Şu an hepsi testin olduğu için
> güvenli; gerçek müşteriler geldikten sonra aynı sorgu onların hepsini siler.

### Doğrula

```sql
select 'customers' as tablo, count(*) as satir
from public.customers where phone like '555999%'
union all
select 'appointments', count(*)
from public.appointments where phone like '555999%'
union all
select 'auth.users (anonim)', count(*)
from auth.users where coalesce(is_anonymous, false);
```

Üçü de **0** olmalı. `02_data_audit.sql` da göçün hemen sonrasındaki tabloyu
gösterir: boş tablolar, tek personel hesabı.

---

## Uçtan uca kendi makinende görmek istersen

Uygulamanın kendi istemcisiyle yazılmış sürüm scratchpad'de duruyor; repoya
koymadım, çünkü canlı veritabanının yanında müşteri ve randevu imal eden bir
script işi bitince durmamalı — concurrency probe'a yaptığımızın aynısı. İstersen
geri getiririm.
