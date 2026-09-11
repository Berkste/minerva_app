# Canlıya çıkış — uygulama adımları

**Tarih:** 2026-09-11 · **Proje:** `dycjvupgvuxkguorzaqz` (geliştirme projesi canlıya alınıyor)

Bu dosya, veritabanını temiz bir başlangıca getirmek için **senin** yapacağın işleri
sırasıyla anlatır. Kod tarafındaki her şey bitti; aşağıdakiler Supabase panelinde
ve terminalde yapılacak.

---

## ⚠️ Önce: proje SİLİNMİYOR

Bu işlem Supabase projesini silip yeniden kurmak değildir. Proje, URL'i, anon
key'i, panel ayarları ve `auth.users` (personel girişin dahil) **aynen kalıyor.**
Sadece `public` şemasının içindeki tablolar/fonksiyonlar düşürülüp migration
dosyalarından yeniden kuruluyor.

Projeyi silseydin URL ve anon key değişir, uygulamanın yapılandırması kırılırdı.

---

## Neden bu yol seçildi

`01_schema_audit.sql` üç FAIL döndü ve üçü de `20260828120000_admin.sql`'in
git'te olup veritabanında olmayan parçalarıydı:

| Bulgu | Sonuç |
|---|---|
| `admins.created_at` kolonu yok | Personel listesi sorgusu çalışmıyordu |
| `admins → auth.users` cascade değil | Personel kullanıcısı silinemiyordu |
| `anon`, `is_admin()`'i çağırabiliyor | Sömürülebilir değil (anon'a `false` döner), ama en-az-yetki ihlali |

Policy'ler ve fonksiyon gövdesi tutuyordu — bu, dosyanın **eski bir taslağının
elle uygulanıp bir daha çalıştırılmamış** olmasının imzası: `create or replace`
fonksiyonu günceller, `create table` ve `revoke` güncellemez.

`02_data_audit.sql` ise saklanacak hiçbir şey bulmadı: 6 test randevusu, 1 profil,
45 anonim cihaz, **çifte onaylı slot yok**, bozuk invariant yok.

---

## Bu arada kodda değişenler (bitti, sende iş yok)

1. **`23514` çakışması giderildi.** `reject_past_appointments()` artık
   `check_violation` yerine kendine ait `MN001` SQLSTATE'i fırlatıyor. Böylece
   telefon/isim/saat/servis CHECK ihlalleri müşteriye artık yanlışlıkla
   "bu saat geçti" diye gösterilmiyor. PostgREST tanımadığı kodu HTTP 400'e
   eşliyor — yani 23514'ün ürettiği durumun aynısı, yanıtta başka hiçbir şey
   değişmiyor.
2. **`profiles_select_admin` kaldırıldı.** Admin ekranları `profiles` tablosuna
   hiç gitmiyor; iletişim bilgisi randevu satırına kopyalanıyor. Policy dururken
   her personel, hiç randevusu olmayanlar dahil her müşterinin güncel telefonunu
   okuyabiliyordu.
3. **`01_schema_audit.sql` güncellendi.** Artık `profiles_select_admin` beklemiyor
   ve trigger'ın `MN001` fırlattığını da ayrıca doğruluyor.

---

## ❗ Sıralama uyarısı

`MN001` değişikliği **hem veritabanını hem uygulamayı** ilgilendiriyor. Telefonunda
duran eski APK hâlâ `23514` bekliyor; migration'ı uygulayıp eski build'i kullanırsan
geçmiş bir saate rezervasyon denemesi "bu saat geçti" yerine genel hata gösterir.

Yani: **migration'ları uygula → APK'ları yeniden derle.** Aradaki sürede eski
build'le test etme.

---

## Adımlar

### 0. Yedek (opsiyonel, 1 dk)
Panel → **Database → Backups** → yedek al. Atılacak veri zaten değersiz, ama
ihtiyaç duymadığın bir yedek, tersinden iyidir.

### 1. Eski şemayı düşür
`supabase/checks/03_production_reset.sql` → **Section A**'daki `/* */` bloğunu
aç ve çalıştır.

### 2. Migration'ları sırayla uygula
SQL editöründe, bu sırayla, her birini ayrı çalıştır:

1. `supabase/migrations/20260827120000_init.sql`
2. `supabase/migrations/20260828120000_admin.sql`

> Bu iki dosya artık yukarıdaki düzeltmeleri içeriyor. Git'teki güncel hallerini
> kullan, eski bir kopyayı değil.

### 3. Test kullanıcılarını sil
Önce bak:

```sql
select count(*) as anonymous_users_to_delete
from auth.users
where coalesce(is_anonymous, false);
```

**`45` görmelisin.** Sayı buysa sil:

```sql
delete from auth.users where coalesce(is_anonymous, false);
```

### 4. Personel yetkisini geri ver

> ⚠️ Bu adım bitene kadar **admin uygulaması kilitli** — `admins` tablosu boş.
> Personel hesabının kendisi `auth.users`'da durduğu için kaybolmadı; sadece
> `admins` satırı düşen tabloyla gitti.

```sql
insert into public.admins (id)
values ('8ee7ffc9-b007-46ac-b6a8-7dd2d69fec44')
on conflict (id) do nothing;
```

Doğrula — tam olarak **1** satır dönmeli:

```sql
select ad.id, u.email, ad.created_at as admin_since
from public.admins ad left join auth.users u on u.id = ad.id;
```

### 5. Denetimi tekrar çalıştır
`01_schema_audit.sql` → **tek bir FAIL kalmamalı.** Özellikle şu üçü artık OK olmalı:
`admins.created_at`, `admins → auth.users on delete cascade`,
`anon may execute public.is_admin()` (actual=false). Ayrıca yeni satır:
`reject_past_appointments() raises its own SQLSTATE` → **OK, raises MN001**.

`profiles_select_admin` hiç görünmemeli — ne eksik ne fazla olarak.

### 6. Veriyi doğrula
`02_data_audit.sql` → tablolar boş, `auth_users` = 1 (sadece personel),
anonim kullanıcı satırı hiç gelmemeli.

### 7. Uygulamaları yeniden derle
Flavor zorunlu — flavor'sız komut artık çalışmaz:

```
flutter build apk --release --flavor customer
flutter build apk --release --flavor admin
```

### 8. Duman testi
- **Müşteri:** anonim giriş → randevu al → "randevularım"da görünsün → iptal et
- **Personel:** `admin@minerva.com.tr` ile giriş → gün takviminde o randevuyu gör
- **Geçmiş saat:** cihazın saatini ileri alıp geçmiş bir slota rezervasyon dene →
  "bu saat geçti" mesajı gelmeli (MN001 eşlemesinin canlı doğrulaması)

---

## 9. Panelde SQL'in göremediği ayarlar

`03`'ün Section 5'i bunları uzun uzun anlatıyor; kontrol listesi:

- [ ] **Authentication → Sign In / Providers**: Anonim giriş **AÇIK** (kapalıysa
      müşteri uygulaması hiç giremez), E-posta sağlayıcı **AÇIK**
- [ ] **Şifre politikası / sızmış şifre koruması**: personel hesabı her müşterinin
      adına ve telefonuna erişiyor — açık olsun
- [ ] **Database → Backups**: ücretsiz planda point-in-time recovery yok. Gerçek
      müşteri adı ve telefonu kişisel veri; planı ve saklama süresini **şimdi** kararlaştır
- [ ] **Project → General**: ücretsiz proje 7 gün hareketsizlikte duraklar. Salonda
      sessiz bir hafta uygulamayı kapatır — ücretli plana geçmeyi değerlendir
- [ ] **API → Exposed schemas**: sadece `public`
- [ ] **Project → API keys**: `service_role` anahtarı uygulamaya, git'e veya build
      komutuna asla girmemeli

---

## Hâlâ açık, canlıdan önce karar bekleyen

| Konu | Durum |
|---|---|
| `admin@minerva.com.tr` gerçek personel hesabı mı? | Geliştirme hesabıysa panelden sil, gerçek adresli yenisini aç (`03` Section 4) |
| Personel dağıtımı | Play Internal Testing / TestFlight **veya** sideload APK |
| Android upload keystore | **Oluşturulmadı** — Play Store'a çıkış için şart |
| iOS release | Hiç derlenmedi (macOS yok) |
| Eski branch'ler | `edit_20260827`, `supbase_work` — commit'leri `main`'de, silinebilir |

---

## Bilinen boşluk

`SupabaseBookingRepository`'deki hata kodu eşlemesinin **testi yok** — testler
`fake_booking_repository.dart` üzerinden gidiyor ve gerçek sınıfa hiç uğramıyor.
Yani az önce değiştirdiğim `MN001` eşlemesi ancak 8. adımdaki duman testiyle
doğrulanıyor. Kapatmak istersen `_guard`'daki switch'i saf bir fonksiyona çıkarıp
birim testi yazmak gerekir; mevcut test mimarisini değiştireceği için kendi başıma
yapmadım.
