# Faz 2 — Kesinleşmiş tasarım ve iş planı

**Tarih:** 2026-09-11 (revizyon 3 — final) · **Durum:** tüm kararlar alındı, uygulanabilir
**Okunabilir sürüm:** https://claude.ai/code/artifact/e4154db4-2bd4-4e4a-a578-608a60024690

Açık soru kalmadı. İki küçük varsayım §7'de işaretli; ikisi de tek satırlık SQL ile
geri alınabilir.

---

## 1. Kararlar

| | Konu | Karar |
|---|---|---|
| S1 | Kimlik modeli | **B** — `customers` tablosu, telefon numarası kişiyi tanımlar. **OTP ve e-posta yok** |
| S2 | Misafir eşleşmesi | Telefon eşleşirse aynı kişi kaydına bağlanır |
| S3 | 3 haftalık kural | Admin **muaf** |
| S4 | Pencere | **21 gün** |
| S5 | Silme | **Soft delete** — hiçbir veri gerçekten silinmez |
| S6 | İptal ve pencere | İptal edilen sayılmaz; kontrol kalan aktif randevulara göre |
| S7 | İptal sınırı | Müşteri randevuya **1 saat** kalaya kadar. Admin her zaman |
| S8 | Kapalı günler | **Pazar kapalı.** Admin tek gün veya aralık kapatabilir |
| S9 | Hizmet ve fiyatlar | Fiyat listesi görselinden çıkarıldı — §3 |
| Y1 | Sahiplenme sınırı | **Üçü birden** — ad+telefon eşleşmesi, yalnızca gelecek randevular, admin kaydı cihazdan iptal edilemez |
| Y2 | Soyad | **Nullable** |
| Y3 | Ekstralar | Müşteri yalnızca **ana işlemi** seçer; ekstraları salon sonradan girer |
| Y4 | Tutar | Randevu oluşurken seçilen işlemlerin fiyatlarından **toplanır**. Admin sonradan satır ekleyip silebilir |
| Y5 | Tamamlanma | Randevu saatini **1 saat** geçtiyse ve iptal edilmediyse tamamlanmış sayılır. Admin elle de işaretleyebilir |
| Y6 | Gelmeyen | → **V1** varsayımı |
| Y7 | Pazar istisnası | Müşteri kesinlikle alamaz → admin için **V2** varsayımı |
| Y8 | İngilizce | Zorunlu değil; en iyi çeviriler §6'da onayına sunuldu |
| Y9 | Çıkarma ücreti | İstisna yok — Tırnak Çıkarma tek fiyat, 350 TL |

---

## 2. Fiyatlandırma modeli — rev 2'den değişti

Y3 ve Y4'ün cevabı, para modelini rev 2'de önerdiğimden daha basit bir yere taşıdı.

**Rev 2'de `appointments.total_amount` diye bir kolon öneriyordum. Kaldırdım.**
Gerekçe: admin'in düzenlediği şey satırların kendisi ("yapılan işlemleri silip
ekleyebilir"). Toplamı ayrı bir kolonda tutmak, satırlarla toplamın birbirinden
ayrı düşebileceği klasik bir hata kaynağıdır. Toplam artık **türetiliyor**:

```
randevu tutarı = sum(appointment_services.amount)
```

Akış şöyle işliyor:

1. **Müşteri randevu alırken** ana işlemi seçer → `appointment_services`'e bir satır,
   `amount` = katalog fiyatı. İşlem seçmezse satır yok, tutar 0.
2. **Salon işi yaparken** ekstralar belli olur. Admin sonradan randevuyu açıp satır
   ekler veya siler.
3. **Aralıklı fiyatlı ekstralarda** (Nail Art, Charm/Taş — 20–300 TL) admin gerçekte
   alınan tutarı yazar. Zorunlu alan değil; girilmezse o satır alt sınırla kaydedilir.
4. **İstatistik**, yalnızca kayıtlı satırları toplar. Yani rakam "girildiği kadar
   doğru" — tahmin yok.

Fiyat, seçim anında `appointment_services.amount` alanına **kopyalanıyor**; katalog
fiyatı sonradan değişince geçmiş randevular etkilenmiyor. Hizmet adı için kopya
gerekmiyor: soft delete sayesinde `services` satırı hiç kaybolmuyor, birleştirme
her zaman çözülüyor.

---

## 3. Katalog

### İşlemler — müşteri bunlardan birini seçer

| Hizmet | Fiyat | Açıklama |
|---|---|---|
| Protez Tırnak | 1.000 TL | Medikal manikür + 2 tırnak Nail art |
| Protez Tırnak Bakım | 900 TL | Medikal manikür + 2 tırnak Nail art |
| Düz Kalıcı Oje | 850 TL | Medikal manikür + 2 tırnak Nail art |
| Jel Destekli Kalıcı Oje | 900 TL | Medikal manikür + 2 tırnak Nail art |
| Ayak Kalıcı Oje | 1.000 TL | |
| Medikal Manikür | 450 TL | |
| Medikal Pedikür | 600 TL | |

### Ekstralar — yalnızca admin girer

| Ekstra | Fiyat |
|---|---|
| Şablon Sistem Protez | 1.300 TL |
| Nail Art | 20 – 300 TL |
| Cat Eye | 250 TL |
| French / Ombre | 350 TL |
| İnci / Krom Tozu | 250 TL |
| Charm / Taş | 20 – 300 TL |
| Tek Tırnak Protez | 50 TL |
| Tırnak Çıkarma | 350 TL |

---

## 4. Veri modeli

### `customers` — kişi (yeni)

`id` · `first_name` **not null** · `last_name` **nullable** · `phone` **unique not
null** · `created_at` · `updated_at` · `deleted_at` · `created_by_admin`

Telefon numarası kişiyi tanımlar; teklik kısıtı eşleşmenin temeli.

### `customer_devices` — cihaz ↔ kişi bağı (yeni, `profiles` yerine)

`auth_user_id` (pk → `auth.users`) · `customer_id` (→ `customers`) · `linked_at`

Bir kişi zaman içinde birden çok cihaz kullanabilir. `profiles` tablosu kaldırılıyor —
ad ve telefon `customers`'a taşındı, geriye yalnızca bu bağ kalıyor.

### `appointments` — değişiklikler

- `user_id` → **`customer_id`**
- `created_by` (→ `auth.users`, nullable) — randevuyu kim girdi; **Y1'in üçüncü
  sınırlaması bu alandan okunur**: `created_by` admin ise cihazdan iptal edilemez
- `cancelled_by` (`customer` | `admin`, nullable)
- `deleted_at` — soft delete
- `service_id` kolonu ve CHECK kısıtı **kalkıyor** → `appointment_services`
- `total_amount` **yok** — türetiliyor (§2)
- `status` enum: `confirmed` · `cancelled` · `completed` · `no_show`
- `first_name` / `last_name` / `phone` anlık kopyaları **kalıyor** — "bu randevuyu kim
  aldı" sorusunun cevabı, kişi sonradan bilgisini değiştirse de değişmemeli

### `services` — katalog (yeni)

`id` · `kind` (`main` | `extra`) · `name_tr` · `name_en` · `description_tr` ·
`price_min` · `price_max` *(null = sabit fiyat)* · `currency` · `is_active` ·
`sort_order` · `deleted_at`

### `appointment_services` — randevuda ne yapıldı (yeni)

`appointment_id` · `service_id` · `kind` *(kopya)* · `amount`

Tek bir para modeli, admin için tek bir düzenleme listesi. `kind` kolonu kopyalanıyor
ki **"en fazla bir ana işlem"** kuralı kısmi unique index ile garanti edilebilsin:

```sql
create unique index appointment_one_main_service
  on appointment_services (appointment_id) where kind = 'main';
```

### `salon_closures` — kapalı günler (yeni)

`id` · `start_date` · `end_date` · `reason` · `created_by` · `created_at`

Tek gün için `start_date = end_date`. Pazar kapalılığı burada tutulmuyor — trigger'da
sabit kural.

---

## 5. Kuralların veritabanı karşılığı

| Trigger | Ne yapar | Kod |
|---|---|---|
| `reject_past_appointments` | Geçmişe randevu engeli — **INSERT ve UPDATE** | `MN001` *(mevcut)* |
| `enforce_booking_window` | 21 gün kuralı; admin muaf | `MN002` |
| `reject_closed_days` | Pazar + `salon_closures`; admin muaf (V2) | `MN003` |
| `enforce_cancel_deadline` | Müşteri iptali randevuya 1 saatten az kala reddedilir; admin muaf | `MN004` |

Dördü de `MN001` için kurulmuş desenin aynısı: kendi SQLSTATE'i, `translateError`'da
kendi eşlemesi, kendi hata mesajı, kendi testi.

### "Tamamlandı" neden bir kolon değil

Y5: *randevu saatini 1 saat geçtiyse ve iptal edilmediyse tamamlanmış sayılır.*

Bu kural saate bağlı olduğu için, durumu diskte tutmak birinin belirli aralıklarla
gidip satırları güncellemesini gerektirirdi — yani zamanlanmış bir iş (`pg_cron`),
ücretsiz planda ek bir kurulum ve sessizce durabilecek bir bileşen.

Gerek yok. Durum **okurken türetiliyor**:

```
gerçekleşti = status = 'completed'
           or (status = 'confirmed' and slot_start + interval '1 hour' < now())
```

Admin bir randevuyu elle `completed` işaretleyebilir (saat dolmadan kapatmak için) ya
da gelmeyen için `no_show` seçebilir. İkisi de aynı enum üzerinden; arka planda
çalışan hiçbir şey yok.

### 21 günlük pencerenin tam tanımı

Bir kişi için `D` tarihine randevu oluşturulurken ya da güncellenirken: aynı kişinin
**aktif** (silinmemiş, iptal edilmemiş) başka bir randevusu `D`'ye 21 günden yakınsa
reddedilir. Kural simetrik — sonraya da öncesine de aynı mesafe.

Randevunun kendisi kontrole dahil edilmez, yoksa kişi kendi randevusunu erteleyemez.
`created_by` admin ise kural hiç çalışmaz (S3).

### RLS haritası

| Tablo | Müşteri | Admin |
|---|---|---|
| `customers` | Yalnızca bağlı olduğu kayıt — select, update | Tümü — select, insert, update |
| `customer_devices` | Kendi `auth.uid()` satırı — select, insert | select |
| `appointments` | Bağlı olduğu kişinin randevuları — select, insert, update | Tümü — select, insert, update |
| `services` | `is_active` olanlar — select | Tümü — select, insert, update |
| `salon_closures` | select *(takvimde göstermek için)* | Tümü |

**Hiçbir tabloda DELETE politikası yok** — S5 gereği. Denetim scriptindeki mevcut
"no DELETE policy anywhere" kontrolü olduğu gibi kalıyor ve artık bir tasarım kuralını
koruyor.

---

## 6. İngilizce karşılıklar — onayına sunuldu

Uygulama bugün iki dilli (`tr` / `en`) ve testleri iki dilde de çalışıyor, yani
İngilizceyi düşürmek bir gerileme olurdu. Hizmet adları l10n metni değil **veri**,
yani `services.name_en` kolonunda duracak — sonradan düzeltmek tek bir `update`.

| Türkçe | İngilizce | |
|---|---|---|
| Protez Tırnak | Nail Extensions | |
| Protez Tırnak Bakım | Extension Refill | ⚠️ "bakım" burada dolgu/yenileme mi? |
| Düz Kalıcı Oje | Classic Gel Polish | |
| Jel Destekli Kalıcı Oje | Builder Gel Polish | ⚠️ teyit |
| Ayak Kalıcı Oje | Toenail Gel Polish | |
| Medikal Manikür | Medical Manicure | |
| Medikal Pedikür | Medical Pedicure | |
| Şablon Sistem Protez | Form-System Extensions | ⚠️ teyit |
| Nail Art | Nail Art | |
| Cat Eye | Cat Eye | |
| French / Ombre | French / Ombré | |
| İnci / Krom Tozu | Pearl / Chrome Powder | |
| Charm / Taş | Charms / Gems | |
| Tek Tırnak Protez | Single Nail Extension | |
| Tırnak Çıkarma | Nail Removal | |

İşaretli üçü tırnak terminolojisi; doğrusunu sen söylersen düzeltirim. Kalanı için
bir şey yapmana gerek yok.

---

## 7. Varsayımlar

İkisi de cevapsız kalan noktalar. Tek satırlık SQL ile geri alınabilir; yanlışsa
söylemen yeterli.

**V1 — `no_show` 21 günlük pencereye sayılır.**
Gelmeyen kişi slotu harcadı; saymamak, gelmemeyi kuralı sıfırlamanın yolu hâline
getirir. Ters karar verirsen trigger'daki durum listesinden `no_show` çıkarılır.

**V2 — Pazar müşteriye kapalı, admin için açık.**
"Pazar kesinlikle uygulamadan randevu alınamaz" dedin; bunu müşteri uygulaması olarak
okudum. Admin diğer bütün kurallardan muaf olduğu için tutarlı olan bu — salon
isterse bir Pazar bir müdavimini alabilir. Admin'in de kesinlikle alamaması
gerekiyorsa trigger'daki muafiyet kaldırılır.

---

## 8. İş planı

Veritabanı şu an boş — 0 randevu, 1 personel hesabı. Göç bugün neredeyse bedava, ilk
gerçek müşteriden sonra veri taşıma işine dönüşür. **Faz 1, uygulamayı gerçek
kullanıcılara açmadan önce yapılmalı.**

### Faz 1 — Şema göçü 🔴 canlıya açmadan önce

Tek migration; parçaları birbirine bağlı.

1. `customers` + `customer_devices`; `profiles` kaldırılıyor
2. `appointments` yeniden yapılandırma — `customer_id`, `created_by`, `cancelled_by`,
   `deleted_at`, genişletilmiş enum, `service_id` kolonunun kaldırılması
3. `services` + `appointment_services` + tek-ana-işlem unique index'i; katalogun veri
   olarak yüklenmesi (7 ana + 8 ekstra, İngilizce adlarıyla)
4. `salon_closures`
5. Dört trigger — `MN001` (INSERT+UPDATE'e genişletme), `MN002`, `MN003`, `MN004`
6. Tüm RLS politikalarının yeniden yazılması
7. `01_schema_audit.sql`'in yeni şemaya göre baştan yazılması

### Faz 2 — Uygulama çekirdeği

1. `BookingRepository` arayüzünün yeni modele göre yeniden yazılması
2. `Customer`, `SalonService`, `Closure` modelleri; `Profile` kaldırılıyor
3. Telefonla eşleşme akışı — Y1'in üç sınırlamasıyla
4. Dört yeni SQLSTATE için eşleme, `BookingException` alt sınıfları, l10n metinleri
5. `error_mapping_test.dart` genişletme

### Faz 3 — Müşteri uygulaması

1. Takvimde ay bazında dolu/boş gün + **Pazar ve kapalı gün** gösterimi
2. Katalogdan ana işlem seçimi — 7 hizmet, fiyatlarıyla
3. Ad + telefon zorunlu, soyad opsiyonel form
4. Profil düzenleme ekranı
5. Randevu düzenleme akışı — tarih, saat, işlem
6. 1 saat iptal sınırı ve 21 gün kuralı için kilitli gün gösterimi ve hata mesajları
7. Akış sırası düzeltmesi — işlem seçimi ad/soyad'dan **önce**

### Faz 4 — Admin uygulaması

1. Randevu oluşturma — telefonla kişi arama, yoksa yeni kişi
2. Randevu düzenleme ve iptal — zaman sınırı yok
3. **Randevu işlem listesi düzenleme** — ekstra ekleme/silme, aralıklı fiyatlarda
   tutar girişi
4. `completed` / `no_show` işaretleme
5. Kişi listesi — arama, düzenleme, soft delete
6. Hizmet ve fiyat yönetimi — ana işlemler ve ekstralar
7. Takvim kapatma — tek gün ve tarih aralığı
8. İstatistik sayfası — yapılan, iptal edilen, gelmeyen, kazanılan

### Faz 5 — Doğrulama

1. Yeni kuralların testleri — 21 gün penceresi, kapalı gün, iptal sınırı, telefon
   eşleşmesi, tek-ana-işlem kısıtı
2. Denetim scriptlerinin yeniden yazılması
3. Canlı duman testi
