# Canlıya çıkış — uygulama adımları

**Proje:** `dycjvupgvuxkguorzaqz` · **Veritabanı durumu:** ✅ tamam (2026-09-11)

---

## ✅ Bitti — veritabanı canlıya hazır

Temiz yeniden uygulama (A yolu) yapıldı ve doğrulandı. `01_schema_audit.sql`
**sıfır FAIL, sıfır WARN** döndü; daha önce kırmızı olan üç satır ve yeni eklenen
kontrol artık yeşil:

| Kontrol | Sonuç |
|---|---|
| `admins.created_at` | OK — kolon yerinde |
| `admins → auth.users on delete cascade` | OK — `on delete = c` |
| `anon may execute public.is_admin()` | OK — `actual=false` |
| `reject_past_appointments() raises its own SQLSTATE` | OK — **raises MN001** |
| `profiles_select_admin` | Hiç görünmüyor, "unexpected policy" uyarısı da yok |

`02_data_audit.sql`: 0 randevu, 0 profil, 1 admin, 1 auth kullanıcı (sadece
personel), anonim kullanıcı yok, çifte onaylı slot yok, bozuk invariant yok.

Personel hesabı: **`admin@minerva.com.tr`** (`8ee7ffc9-b007-46ac-b6a8-7dd2d69fec44`),
`admin_since 2026-09-11` — gerçek ve tek admin hesabı olarak karara bağlandı.

> ⚠️ **Bundan sonra `03_production_reset.sql`'i çalıştırma.** Section 3'teki
> `delete from auth.users where coalesce(is_anonymous, false)` artık test
> cihazlarını değil, gerçek müşterileri siler. Dosya kayıt olarak duruyor.

---

## 🟡 Kalan işler

### 0. ✅ Yeni migration'ı uygula — **YAPILDI (2026-09-11)**

`supabase/migrations/20260911120000_browse_before_signin.sql` — tek satır:

```sql
grant execute on function public.booked_slots(date, date) to anon;
```

**Neden:** uygulama artık açılışta oturum açmıyor, dolayısıyla randevu ızgarası
oturumsuz bir çağıranın da yüklenebilmesi gerekiyor. `booked_slots()` security
definer ve yalnızca `(slot_date, slot_hour)` döndürüyor — isim, telefon, kullanıcı
id'si yok. Yani oturumsuz çağıran, salona girip "saat dörtte boş musunuz?" diye
soran birinin öğrendiğinden fazlasını öğrenmiyor.

`is_admin()` **bilerek** anon'a verilmedi; personel yetkisi hâlâ gerçek oturum
istiyor.

Uyguladıktan sonra `01_schema_audit.sql`'i tekrar çalıştır: artık
`anon may execute public.booked_slots(date,date)` satırı **actual=true** ve OK
olmalı (denetim dosyasındaki beklenti de bu yönde güncellendi).

### 1. APK/IPA'ları yeniden derle

Zorunlu: `MN001` değişikliği hem veritabanını hem uygulamayı ilgilendiriyor.
Elindeki eski build hâlâ `23514` bekliyor; onunla test edersen geçmiş-saat hatası
yanlış görünür. Flavor'sız komut da artık çalışmaz:

```
flutter build apk --release --flavor customer
flutter build apk --release --flavor admin
```

### 2. Duman testi (senin cihazlarında)

- **Müşteri:** anonim giriş → randevu al → "randevularım"da görünsün → iptal et
- **Personel:** `admin@minerva.com.tr` ile giriş → gün takviminde o randevuyu gör → iptal et
- **Geçmiş saat:** cihaz saatini ileri alıp geçmiş bir slota rezervasyon dene →
  **"bu saat geçti"** mesajı gelmeli. `MN001` eşlemesinin canlı doğrulaması budur
  (birim testi artık var, ama uçtan uca yolu yalnızca bu doğrular).
- **Kayıt oluşmadığını doğrula:** uygulamayı aç, gez, randevu **alma** ve kapat.
  Ardından `02_data_audit.sql`'in 3. sorgusunu çalıştır — anonim kullanıcı satırı
  **hiç gelmemeli**. Sonra bir randevu al ve tekrar çalıştır: tam **1** anonim
  kullanıcı görünmeli. Bu, yeni davranışın uçtan uca kanıtı.
- **Temizlik:** duman testinde oluşturduğun randevular veritabanında kalır.
  Gerçek müşteriler girmeden önce silmek istersen `03` Section 3'ü **o an** kullan.

### 3. Dağıtım

- **Android:** sideload APK
- **iOS:** TestFlight
- İkisini de sen test edeceksin; ardından canlı test gerçek kullanıcılarla.

### 4. Panelde SQL'in göremediği ayarlar

- [ ] **Authentication → Sign In / Providers**: Anonim giriş **AÇIK** (kapalıysa
      müşteri uygulaması hiç giremez), E-posta sağlayıcı **AÇIK**
- [ ] **Şifre politikası / sızmış şifre koruması**: `admin@minerva.com.tr` her
      müşterinin adına ve telefonuna erişiyor — açık olsun
- [ ] **Database → Backups**: ücretsiz planda point-in-time recovery yok. Gerçek
      müşteri adı ve telefonu kişisel veri; planı ve saklama süresini **canlıya
      çıkmadan** kararlaştır
- [ ] **Project → General**: ücretsiz proje 7 gün hareketsizlikte duraklar. Salonda
      sessiz bir hafta uygulamayı kapatır — ücretli plana geçmeyi değerlendir
- [ ] **API → Exposed schemas**: sadece `public`
- [ ] **Project → API keys**: `service_role` anahtarı uygulamaya, git'e veya build
      komutuna asla girmemeli

---

## 📌 Sonraya bırakılanlar (bilinçli)

| Konu | Plan |
|---|---|
| Android upload keystore | AAB/APK yükleme anında oluşturulacak |
| iOS release derlemesi | Mac mini üzerinde, Claude Code bu projede çalıştırılarak yapılacak |

---

## Geçmiş: neden bu yol seçildi

İlk denetim üç FAIL döndü ve üçü de `20260828120000_admin.sql`'in git'te olup
veritabanında olmayan parçalarıydı: `admins.created_at` yok, `admins` foreign
key'i cascade değil, `anon` hâlâ `is_admin()` üzerinde execute tutuyor. Policy'ler
ve fonksiyon gövdesi tutuyordu — bu, dosyanın eski bir taslağının elle uygulanıp
bir daha çalıştırılmamış olmasının imzası (`create or replace` fonksiyonu günceller,
`create table` ve `revoke` güncellemez).

Veri tarafında saklanacak hiçbir şey yoktu: 6 test randevusu, 1 profil, 45 anonim
cihaz, çifte onaylı slot yok. Bu yüzden şema migration dosyalarından sıfırdan
kuruldu — ve bu, iki uyumluluk bulgusunu bedavaya düzeltmek için doğru andı:

1. **`23514` çakışması giderildi.** `reject_past_appointments()` artık kendine ait
   `MN001` SQLSTATE'ini fırlatıyor. Tablonun kendi CHECK kısıtları (telefon, isim
   uzunluğu, saat, servis) da `23514` ürettiği için, eski eşleme müşteriye telefon
   numarası hatalıyken "bu saat geçti" diyordu. PostgREST tanımadığı kodu HTTP
   400'e eşliyor — yani yanıtta başka hiçbir şey değişmedi.
2. **`profiles_select_admin` kaldırıldı.** Admin ekranları `profiles` tablosuna hiç
   gitmiyor; iletişim bilgisi randevu satırına kopyalanıyor. Policy dururken her
   personel, hiç randevusu olmayanlar dahil her kayıtlı müşterinin güncel telefonunu
   okuyabiliyordu.

Bu eşlemenin artık birim testi de var: `test/error_mapping_test.dart`.
