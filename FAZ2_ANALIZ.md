# Faz 2 — Karara bağlanmış analiz ve iş planı

**Tarih:** 2026-09-11 (revizyon 2) · **Durum:** kararlar kilitlendi, uygulamaya hazır
**Okunabilir sürüm:** https://claude.ai/code/artifact/e4154db4-2bd4-4e4a-a578-608a60024690

---

## 0. Bu revizyonda ne değişti

İlk analizdeki dokuz sorunun tamamı cevaplandı. İki sonuç:

1. **Kimlik çatlağı kapandı.** Model B seçildi: kişi kaydı `auth.users`'tan ayrılıyor,
   telefon numarası kişiyi tanımlıyor. Faz 0 engeli kalktı — artık her faz
   planlanabilir.
2. **Kapsam büyüdü.** Gelen fiyat listesi, uygulamadaki dört sabit hizmetin
   **hiçbirini** içermiyor. Gerçek katalog 7 ana işlem + 8 ekstra, ikisi fiyat
   aralıklı. Bu, tek bir `service_id` alanının taşıyamayacağı bir model.

**Zamanlama avantajı:** veritabanı şu anda boş — 0 randevu, 0 profil, 1 personel
hesabı. Bu şema göçünün maliyeti bugün neredeyse sıfır; ilk gerçek müşteriden sonra
aynı iş veri taşıma işine dönüşür. **Göç, canlı kullanıma açmadan önce yapılmalı.**

---

## 1. Kilitlenen kararlar

| | Konu | Karar |
|---|---|---|
| S1 | Kimlik modeli | **B** — `customers` tablosu. İlk randevuda ad + telefon zorunlu, kişi yoksa oluşur, her şey o ID ile yürür. OTP/e-posta **yok** |
| S2 | Misafir eşleşmesi | Admin randevu girdiğinde telefon varsa mevcut kişiye bağlanır; kişi sonra uygulamadan aynı numarayla randevu alınca aynı kayda düşer |
| S3 | 3 haftalık kural | Admin **muaf** |
| S4 | Pencere | **21 gün** (1 Eylül → 22 Eylül) |
| S5 | Silme | **Soft delete** — hiçbir veri gerçekten silinmez, uygulamada görünmez |
| S6 | İptal ve pencere | İptal edilen sayılmaz; kontrol kalan aktif randevulara göre. Geçmişe randevu yok, bugün ve sonrası |
| S7 | İptal sınırı | Müşteri randevuya **1 saat** kalaya kadar iptal eder. Admin her zaman iptal edebilir. Ayrıca admin'e **istatistik sayfası** |
| S8 | Kapalı günler | **Pazar kapalı.** Admin ek olarak gün veya tarih aralığı kapatabilir |
| S9 | Hizmet ve fiyatlar | `dosyalar/minerva hizmet ve fiyat lsitesi.jpeg` — aşağıda veri olarak çıkarıldı |

---

## 2. Fiyat listesinden çıkanlar

### İşlemler (ana hizmetler)

| Hizmet | Fiyat | Açıklama |
|---|---|---|
| Protez Tırnak | 1.000 TL | Medikal manikür + 2 tırnak Nail art |
| Protez Tırnak Bakım | 900 TL | Medikal manikür + 2 tırnak Nail art |
| Düz Kalıcı Oje | 850 TL | Medikal manikür + 2 tırnak Nail art |
| Jel Destekli Kalıcı Oje | 900 TL | Medikal manikür + 2 tırnak Nail art |
| Ayak Kalıcı Oje | 1.000 TL | |
| Medikal Manikür | 450 TL | |
| Medikal Pedikür | 600 TL | |

### Ekstralar

| Ekstra | Fiyat |
|---|---|
| Şablon Sistem Protez | 1.300 TL |
| Nail Art | **20 – 300 TL** |
| Cat Eye | 250 TL |
| French / Ombre | 350 TL |
| İnci / Krom Tozu | 250 TL |
| Charm / Taş | **20 – 300 TL** |
| Tek Tırnak Protez | 50 TL |
| Tırnak Çıkarma | 350 TL |

> Dipnot: *"Farklı merkezlerde yapılan işlemlerde tek seferlik çıkarma ücreti
> alınmaktadır."*

### Üç yapısal sonuç

1. **Mevcut katalog tamamen geçersiz.** `classic_manicure`, `gel_manicure`,
   `nail_art_design`, `pedicure` — dördü de listede yok, dördü de "1.000 TL" yazıyor.
   Hem Dart modeli hem CHECK kısıtı sıfırdan yazılacak.
2. **İki seviyeli model gerekiyor.** Ana işlem + birden çok ekstra. Bugünkü tek
   `service_id` alanı bunu taşıyamaz.
3. **Fiyat tek sayı değil.** İki ekstra aralıklı (20–300 TL). Yani **gelir
   istatistiği katalogdan hesaplanamaz** — randevu başına gerçekte alınan tutarın
   kaydedilmesi gerekir.

---

## 3. Hedef veri modeli

### `customers` — kişi (yeni)

`id`, `first_name`, `last_name` *(opsiyonel — bkz. Y2)*, `phone` **unique**,
`created_at`, `updated_at`, `deleted_at`, `created_by_admin`.

Telefon numarası kişiyi tanımlar; teklik kısıtı eşleşmenin temeli.

### `customer_devices` — cihaz ↔ kişi bağı (yeni, `profiles`'ın yerine)

`auth_user_id` (pk, → `auth.users`), `customer_id` (→ `customers`), `linked_at`.

Bir kişi zaman içinde birden çok cihaz kullanabilir; ayrı tablo bunu taşır.
`profiles` tablosu işlevsiz kalıyor ve kaldırılıyor — ad/telefon `customers`'a taşındı.

### `appointments` — değişiklikler

- `user_id` → **`customer_id`** (→ `customers`)
- `created_by` (→ `auth.users`, null olabilir) — randevuyu kimin girdiği; admin
  kaydını ayırt etmek ve denetim için
- `status` enum genişliyor: `confirmed` · `cancelled` · **`completed`** · **`no_show`**
- `cancelled_by` (`customer` | `admin`) — S7'deki istatistik için
- `deleted_at` — soft delete
- `total_amount` numeric, null — randevu tamamlandığında gerçekte alınan tutar
- `service_id` tekil alanı kalkıyor, yerine `appointment_services`
- `first_name` / `last_name` / `phone` anlık kopyaları **kalıyor** — "bu randevuyu kim
  aldı" sorusunun cevabı, kişi sonradan bilgisini değiştirse de değişmemeli
- Mevcut `cancelled_at_matches_status` kısıtı yeni durumlara göre yeniden yazılacak

### `services` — katalog (yeni)

`id`, `kind` (`main` | `extra`), `name_tr`, `name_en`, `description_tr`,
`price_min`, `price_max` *(null = sabit fiyat)*, `currency`, `is_active`,
`sort_order`, `deleted_at`.

### `appointment_services` — randevuda ne yapıldı (yeni)

`appointment_id`, `service_id`, `amount` — seçim anındaki fiyatın **kopyası**.
Katalog fiyatı sonradan değişince geçmiş randevular etkilenmez.

### `salon_closures` — kapalı günler (yeni)

`id`, `start_date`, `end_date`, `reason`, `created_by`, `created_at`.
Tek gün için `start_date = end_date`.

Pazar kapalılığı ayrı bir tablo değil, trigger'da sabit kural.

### Trigger'lar

| Trigger | Ne yapar | SQLSTATE |
|---|---|---|
| `reject_past_appointments` | Geçmişe randevu engeli — **INSERT ve UPDATE** | `MN001` (mevcut) |
| `enforce_booking_window` | 21 gün kuralı; admin muaf | `MN002` |
| `reject_closed_days` | Pazar + `salon_closures` kontrolü | `MN003` |
| `enforce_cancel_deadline` | Müşteri iptali randevuya 1 saatten az kala reddedilir; admin muaf | `MN004` |

Dördü de `MN001` için kurduğumuz desenin aynısı: kendi SQLSTATE'i, `translateError`'da
kendi eşlemesi, kendi hata mesajı, kendi testi.

### RLS haritası

| Tablo | Müşteri | Admin |
|---|---|---|
| `customers` | Yalnızca `customer_devices` üzerinden bağlı olduğu kayıt — select + update | Tümü — select, insert, update |
| `customer_devices` | Kendi `auth.uid()` satırı — select + insert | select |
| `appointments` | Bağlı olduğu `customer_id` — select, insert, update | Tümü — select, insert, update |
| `services` | Aktif olanlar — select | Tümü — select, insert, update |
| `salon_closures` | select *(takvimde göstermek için)* | Tümü |

DELETE politikası **hiçbir tabloda yok** — S5 gereği her şey soft delete. Denetim
scriptindeki mevcut "no DELETE policy anywhere" kontrolü olduğu gibi kalıyor ve
artık bir tasarım kuralını koruyor.

---

## 4. Yeni riskler ve kesinleşen sorunlar

### R1 — Telefonla sahiplenme, doğrulama olmadan ❗ en kritik

**S2'nin kaçınılmaz sonucu.** Doğrulama olmadığı için, bir kişinin telefon numarasını
yazan **herkes** o kişinin kaydına bağlanır: adını, geçmiş ve gelecek randevularını
görür, randevusunu iptal edebilir.

Bu, K3 kuralıyla ("kullanıcı başkasının bilgilerini göremez") doğrudan çelişiyor.

OTP olmadan bunu *çözmek* mümkün değil; ancak zorlaştırılabilir:

- **Ad + telefon birlikte eşleşsin.** Sadece numara yetmez, girilen ad da kayıttaki
  adla tutmalı. Güvenlik değil, sürtünme — ama rastgele numara denemesini durdurur.
- **Görünen geçmiş sınırlansın.** Eşleşen kayıt açıldığında tüm geçmiş değil, yalnızca
  **gelecek randevular** gösterilsin.
- **İptal yetkisi sınırlansın.** Yalnızca o cihazdan alınan randevu cihazdan iptal
  edilebilsin; admin'in girdiği randevu için salonu araması gereksin.

*Önerim: üçü birden.* Bu kombinasyon, "ben randevumu göreyim" ihtiyacını karşılarken
zarar yüzeyini gelecek randevularla sınırlar. → **Y1**

### R2 — "Soyad zorunlu" çelişkisi

Şema bugün `first_name` ve `last_name` alanlarının **ikisini de** zorunlu tutuyor.
Senin kararın "sadece ad ve telefon zorunlu". Admin ekranında ise "ad soyad telefon"
yazıyor.

Yani `last_name` **nullable** olmalı ve form soyadı isteğe bağlı sormalı. → **Y2**

### R3 — Gelir istatistiği katalogdan hesaplanamaz

İki ekstra aralıklı fiyatlı (20–300 TL). Bir randevunun gerçekte kaç para ettiği
ancak salon söylerse bilinir. Bu yüzden `appointments.total_amount` alanı ve admin
tarafında bir "randevuyu tamamla + tutarı gir" adımı gerekiyor. Aksi halde S7'deki
"kazanılan para" rakamı tahmin olur. → **Y4**

### R4 — İki durumlu enum istatistiğe yetmiyor

S7 üç şey istiyor: iptal edilen, yapılan, kazanılan. Bugünkü enum yalnızca
`confirmed` ve `cancelled` biliyor — "yapıldı" diye bir durum yok. `completed` ve
`no_show` eklenmezse istatistik sayfası yazılamaz.

Bir de operasyonel soru: bir randevu `completed` olduğunu nereden bilecek? Admin elle
mi işaretleyecek, yoksa saati geçen randevular otomatik mi sayılacak? → **Y5**

### R5 — `profiles` tablosu işlevsiz kalıyor

Ad ve telefon `customers`'a taşındığında `profiles` yalnızca bir cihaz-kişi bağı
olarak kalıyor ki bunun adı artık `customer_devices`. Tablo kaldırılmalı — canlıda
zaten 0 satır var.

---

## 5. Revize iş planı

Faz 0 (kimlik kararı) kapandı. Fazlar artık sırayla uygulanabilir.

### Faz 1 — Şema göçü 🔴 canlıya açmadan önce

Tek bir migration olarak, çünkü parçaları birbirine bağlı:

1. `customers` + `customer_devices` tabloları, `profiles`'ın kaldırılması
2. `appointments` yeniden yapılandırma: `customer_id`, genişletilmiş enum,
   `cancelled_by`, `deleted_at`, `total_amount`, `created_by`
3. `services` + `appointment_services`, fiyat listesinin veri olarak yüklenmesi
   (7 ana + 8 ekstra), eski CHECK kısıtının kaldırılması
4. `salon_closures`
5. Dört trigger: geçmiş (INSERT+UPDATE), 21 gün, kapalı gün, iptal sınırı
6. RLS politikalarının tamamının yeniden yazılması (§3 tablosu)
7. `01_schema_audit.sql`'in yeni şemaya göre baştan yazılması

### Faz 2 — Uygulama çekirdeği

1. `BookingRepository` arayüzünün yeni modele göre yeniden yazılması
2. `Customer`, `SalonService`, `Closure` modelleri; `Profile` kaldırılıyor
3. Telefonla eşleşme akışı (R1'deki üç sınırlamayla)
4. Dört yeni SQLSTATE için `translateError` eşlemesi, `BookingException` alt
   sınıfları, l10n metinleri
5. `error_mapping_test.dart` genişletme

### Faz 3 — Müşteri uygulaması

1. Takvimde ay bazında dolu/boş gün + **kapalı gün** gösterimi
2. Katalogdan hizmet seçimi — yeni 7 ana işlem, fiyatlarıyla
3. Ad + telefon zorunlu, soyad opsiyonel form
4. Profil düzenleme ekranı
5. Randevu düzenleme akışı — tarih, saat, işlem
6. 1 saat iptal sınırı ve 21 gün kuralı için kilitli gün gösterimi + hata mesajları
7. Akış sırası düzeltmesi: işlem seçimi ad/soyad'dan **önce**

### Faz 4 — Admin uygulaması

1. Randevu oluşturma — telefonla kişi arama, yoksa yeni kişi
2. Randevu düzenleme ve iptal (zaman sınırı yok)
3. Randevuyu tamamlama + tutar girişi
4. Kişi listesi — arama, düzenleme, soft delete
5. Hizmet ve fiyat yönetimi — ana işlemler ve ekstralar
6. Takvim kapatma — tek gün ve tarih aralığı
7. İstatistik sayfası — yapılan, iptal edilen, gelmeyen, kazanılan

### Faz 5 — Doğrulama

1. Yeni kuralların testleri: 21 gün penceresi, kapalı gün, iptal sınırı, telefon
   eşleşmesi
2. Denetim scriptlerinin yeniden yazılması
3. Canlı duman testi

---

## 6. Cevabını beklediğim yeni sorular

Üçü işe başlamadan gerekli, kalanı ilgili faza gelince konuşulabilir.

### Şimdi gereken

**Y1 — R1'deki üç sınırlama kabul mü?** Ad + telefon birlikte eşleşsin, yalnızca
gelecek randevular görünsün, admin'in girdiği randevu cihazdan iptal edilemesin.
*Önerim: üçü birden.*

**Y2 — Soyad tamamen opsiyonel mi?** Şema bugün zorunlu tutuyor; kararın "sadece ad ve
telefon". Soyad formda sorulsun ama boş bırakılabilsin mi?
*Önerim: evet, nullable.*

**Y3 — Ekstraları müşteri mi seçecek?** Yoksa müşteri sadece ana işlemi seçsin,
ekstraları salon tamamlarken mi girsin?
*Önerim: müşteri sadece ana işlem — ekstralar yerinde belli oluyor ve ikisi aralıklı
fiyatlı.*

### Fazına gelince

**Y4 — Tutar ne zaman girilir?** Admin randevuyu "tamamlandı" işaretlerken mi?
(Faz 4)

**Y5 — `completed` nasıl oluşur?** Admin elle mi işaretler, saati geçenler otomatik
mi sayılır? Gelmeyen için `no_show`'u admin mi işaretler? (Faz 4)

**Y6 — `no_show` 21 günlük pencereye sayılır mı?** Gelmeyen kişi slotu harcadı ama
hizmet almadı. *Önerim: sayılsın.* (Faz 1)

**Y7 — Admin bir Pazar'ı istisnai olarak açabilir mi?** Bugünkü öneri Pazar'ı sabit
kapalı tutuyor. (Faz 1)

**Y8 — Yeni hizmetlerin İngilizce karşılıkları?** Uygulama iki dilli; "Protez Tırnak",
"Kalıcı Oje" gibi terimlerin İngilizcesi lazım. (Faz 3)

**Y9 — Dipnottaki çıkarma ücreti.** *"Farklı merkezlerde yapılan işlemlerde tek
seferlik çıkarma ücreti"* — bu otomatik eklenen bir ekstra mı, yoksa salonun duruma
göre eklediği bir kalem mi? (Faz 4)
