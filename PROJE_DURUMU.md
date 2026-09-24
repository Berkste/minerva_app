# Minerva Nail Art — Proje Durumu

**Son güncelleme:** 2026-09-24
**Depo:** `C:\Projects\minerva_app`
**Teknoloji:** Flutter 3.47.0 / Dart 3.13.0 · Supabase (Postgres + RLS) · `provider` state yönetimi

---

## 1. Bir bakışta

| | Durum |
|---|---|
| `main` branch | `origin/main` ile eşit — `37660c9`, çalışma alanı temiz |
| Kod | Faz 1–5 bitti: şema canlıda, müşteri ve personel uygulamalarının tamamı yazıldı |
| Doğrulama | `flutter analyze` temiz · **358/358 test geçiyor** — ikisi de bugün çalıştırıldı |
| Duman testi | Müşteri yarısı (1–6) yapıldı ✅ · personel yarısı (7–14) **bekliyor** |
| Sıradaki iş | §5.1 — duman testinin personel yarısı, ardından test verisinin silinmesi |
| Yayına engel | Android upload keystore yok · iOS admin flavor'ı yok · Supabase ücretsiz planda |

---

## 2. Branch haritası

Tek branch kaldı. Faz 2 öncesi feature branch'leri (`feature/admin-appointments`,
`feature/admin-build-and-calendar`, `feature/bundle-fonts`) ve eski
`edit_20260827` / `supbase_work` branch'leri merge edilip silindi — commit'lerinin
hepsi `main` geçmişinde duruyor.

| Branch | Commit | Durum |
|---|---|---|
| `main` | `37660c9` | ✅ `origin/main` ile eşit |

**Worktree:** yalnızca `C:/Projects/minerva_app` → `main`. Başka worktree yok.

Son beş commit:

```
37660c9  Run the customer half of the smoke test against production
269be32  Check the things nothing was checking
732738a  Give the salon the screens it runs on
c148158  Show the customer what is possible before they ask
e5c0761  Record the schema as applied and verified
```

---

## 3. Tarih tarih, adım adım geçmiş

### 2026-08-27 — Uygulamanın ilk hali
**Commit `3677a83`** — *Add Minerva Nail Art appointment booking app* (91 dosya, +6.371 satır)

- Flutter iskeleti (Android + iOS), Minerva UI/UX spesifikasyonuna göre mor/pembe/beyaz tema
- Randevu akışı: Splash → Home → **Takvim → Saat → Bilgiler → Hizmet (opsiyonel) → Özet → Başarılı**
- Alt navigasyon: Home · Randevularım · Profil
- Tema token'ları tek yerde (`lib/theme/app_theme.dart`), logo `CustomPainter` ile çizili (asset yok)
- Depolama: `shared_preferences` (yerel)
- Testler: `widget_test.dart`, `render_test.dart`

**Commit `0b6dbb8`** — *Add Turkish/English localization and a masked phone number field* (29 dosya, +2.675)

- Türkçe/İngilizce dil desteği, cihaz diline uyum, bilinmeyen dilde **Türkçe**'ye düşüş
- Profil ekranında dil değiştirici (cihaz varsayılanı / Türkçe / İngilizce), tercih hatırlanıyor
- `lib/utils/phone_formatter.dart` — `(555) 555 55 55` maskesi, yapıştırılan her formatı 10 haneye indirger
- Tarih kalıpları da dil kataloğunda (TR ve EN parça sırası farklı)

### 2026-08-28 — Backend Supabase'e taşındı
**Commit `413d4d5`** — *Move bookings to Supabase, with double booking made impossible* (54 dosya, +4.013)

Projenin etrafında döndüğü garanti burada kuruldu:

- `supabase/migrations/20260827120000_init.sql` — şema, RLS, kısmi tekil indeks
- **Çifte rezervasyon imkânsız:** `appointments_one_confirmed_per_slot` kısmi unique index. Uygulama önce müsaitlik sormaz, doğrudan insert eder; `23505` hatası `SlotTakenException`'a çevrilir. "Kontrol et → yaz" arasında açık pencere yok.
- **Slot = duvar saati** (`slot_date` + `slot_hour`), `timestamptz` değil — farklı saat dilimlerindeki iki telefon "14:00"ı iki farklı ana çevirmesin diye
- **Kimlik:** kayıt yok; ilk açılışta anonim giriş, ilk randevuda `profiles` satırı yazılır (misafir → müşteri)
- **Gizlilik:** RLS her satırı sahibine kilitler; müsaitlik `booked_slots()` `security definer` fonksiyonundan sadece slot anahtarı olarak döner
- **Sunucu tarafı kurallar:** geçmiş slot'a rezervasyon trigger ile reddedilir (`Europe/Istanbul`), `slot_hour` salon saatleriyle, `phone` 10 hane, isimler 2–60 karakter
- **Offline:** son bilinen randevular/profil cihazda önbellekte; liste "önbellek gösteriliyor" der. Rezervasyon her zaman bağlantı ister.
- `test/fake_booking_repository.dart` — unique index'i taklit eden bellek içi sahte backend; yarış durumu canlı veritabanı olmadan test edilebiliyor
- Windows masaüstü hedefi eklendi

### 2026-08-31 — Yayına hazırlık ve admin
**Commit `5c66e25`** — *Fix release-build blockers found in production readiness audit*
- `android/app/build.gradle.kts`, `AndroidManifest.xml`, `analysis_options.yaml` düzeltmeleri
- `tool/concurrency_probe.dart` — canlı veritabanına karşı yarış denemesi yapan yardımcı script
  *(2026-09-11'de silindi — aşağıya bakınız)*

**Commit `a9c1d44`** (branch `feature/bundle-fonts` → merge `ccbd1fb`) — *Bundle Poppins locally*
- `google_fonts` bağımlılığı kaldırıldı; Poppins 400/500/600/700 `assets/fonts/` altına gömüldü (OFL lisansı dahil)
- Uygulama çalışırken font indirmiyor (H-2 bulgusu)

**Commit `a742027`** (branch `feature/admin-appointments` → merge `1ef46cf`) — *Add admin/employee appointment management* (17 dosya, +1.323)
- `supabase/migrations/20260828120000_admin.sql`:
  - `public.admins` tablosu (personel `auth.users.id`'leri; üyelik **elle** SQL editöründen verilir, self-service yol yok)
  - `public.is_admin()` — `security definer`, `search_path` sabitlenmiş, özyineleme kırılmış
  - 3 **ek** RLS politikası: personel tüm randevuları okur, herhangi birini iptal eder, müşteri iletişim bilgilerini görür. Mevcut müşteri politikaları hiç değişmedi (RLS politikaları OR ile birleşir).
  - Admin için INSERT yok, hiçbir yerde DELETE yok
- Flutter tarafı: `lib/admin/admin_login_screen.dart` (e-posta + parola), `admin_app.dart`, `admin_appointments_screen.dart`, `providers/admin_provider.dart`
- **Güvenlik sınırı veritabanında**; uygulamadaki "admin miyim" kontrolü sadece doğru ekranı göstermek için

➡️ Bu noktada `main` = `1ef46cf`, `origin/main`'e push edildi.

### 2026-09-02 — Açık branch'teki iki iş
**Branch `feature/admin-build-and-calendar` oluşturuldu** (worktree: `.claude/worktrees/agent-a11f59e489ab0fdc9`)

**Commit `e019b05`** — *Split customer and admin into two build entry points*
- `lib/main.dart` = **müşteri/mağaza** sürümü — import grafiğinde `lib/admin/` altına giden hiçbir referans yok, mağaza binary'si personel ekranlarını **açamaz**
- `lib/main_admin.dart` = **personel** sürümü — doğrudan admin login'e açılır, anonim giriş yapmaz, müşteri provider'larını hiç bağlamaz
- `lib/app_shell.dart` = ortak `MaterialApp` kabuğu (tema, lokalizasyon, dil çözümü, metin ölçek sınırı). `lib/admin/` altına hiçbir referansı yok — bu yüzden müşteri build'ine admin kodu sızmıyor.
- `lib/screens/profile_screen.dart` içindeki admin girişi kaldırıldı (sadece açıklama satırı kaldı)
- README'ye iki ayrı build komutu eklendi

**Commit `f9a4f3c`** — *Admin schedule as a day calendar with booked-day markers*
- Admin ekranı düz listeden **gün takvimine** dönüştü: bugüne açılır, ay ızgarası, randevusu olan günlerin altında işaret, güne dokununca o günün randevuları listelenir
- Ay başına **tek** sorgu (`fetchAppointmentsInRange`) — hem işaretleri hem seçili günün listesini besliyor, ay değiştirmek tek gidiş-dönüş
- **Yeni SQL migration gerekmiyor** — mevcut RLS politikalarıyla çalışıyor
- TR/EN dil dosyalarına 5 yeni string

### 2026-09-03 — Doğrulama (worktree içinde)
- `flutter analyze` → temiz
- `flutter test` → **226 test geçti**
- Müşteri build'inde erişilebilir admin kodu yok (sadece `main_admin.dart` `admin/` import ediyor)
- İki release APK de derlendi: müşteri **52.1 MB**, admin **51.5 MB**
- 🛑 **Burada durduk** — sen test edecektin.

### 2026-09-10 — Kullanıcı testi, düzeltme ve merge

**Sabah — durum kontrolü**
- Branch'ler ve worktree yerinde, çalışma alanları temiz; bu doküman yazıldı
- Testler yeniden çalıştırıldı: **224 geçti, 2 kırmızı** → kod regresyonu değil, tarihi geçmiş sabit test verisi

**Kullanıcı testi — geçti ✅**
- Admin girişi çalışıyor, takvim görünüyor
- Randevu kaydı akışı daha önce test edilmişti

**Commit `0146efc`** — *Pin the concurrency tests to a slot relative to now*
- `test/booking_concurrency_test.dart:22` — sabit `Slot(DateTime(2026, 9, 4), 14)` yerine
  `DateTime.now().add(const Duration(days: 7))`. Zaman bombası fixture'ı kapandı.
- README'deki eski test sayısı düzeltildi (210 → 226)

**Merge**
- `feature/admin-build-and-calendar` → `main`, **fast-forward** (`1ef46cf..0146efc`, 19 dosya, +959/−310)
- `main` üzerinde doğrulama: `flutter analyze` temiz, **226 test geçti**, iki release APK derlendi
- Feature branch ve worktree kaldırıldı

🛑 **Burada duruyoruz** — `main`, `origin/main`'in önünde. **Push senin komutun.**

**Android product flavor kuruldu** (push sonrası, aynı gün)
- Kalıcı paket kimliği seçildi: **`com.oberk.minerva`** (şablondan gelen `com.minerva.minerva_app` TODO'su kapandı)
- İki flavor: `customer` → `com.oberk.minerva` / "Minerva" · `admin` → `com.oberk.minerva.admin` / "Minerva Personel"
- Kotlin paketi `com.oberk.minerva`'ya taşındı, `namespace` güncellendi, manifest etiketi `${appName}` yer tutucusuna bağlandı
- iOS bundle id'leri de aynı kimliğe hizalandı (`com.oberk.minerva`) — iOS build'i denenemedi, macOS yok
- Doğrulandı: iki flavor da derleniyor (52.1 MB / 51.5 MB), birleştirilmiş manifest'lerde paket adları ve etiketler ayrı, analyze temiz, 226 test geçiyor
- ⚠️ **Artık her `flutter run` / `flutter build` komutu `--flavor` istiyor** — flavor tanımlıyken Gradle'ın derleyeceği tek bir varyant kalmıyor

---

## 4. Şu anki mimari

Faz 2 ile veritabanı yeniden kuruldu: `profiles` gitti, kimlik telefon numarasına
bağlandı. **Uygulama kodu da bu şemaya taşındı** — `profiles`, `user_id` ve tek
`service_id` kolonu kodda hiç kalmadı. Tasarım gerekçesi `FAZ2_ANALIZ.md`'de.

```
supabase/
  migrations/
    20260921120000_schema.sql    7 tablo, 3 enum, 8 trigger, 11 fonksiyon, 26 politika
    20260921120100_catalogue.sql Hizmet kataloğu (7 ana + 8 ekstra)
  checks/
    01_schema_audit.sql          Şema denetimi (salt okunur) — canlıda sıfır FAIL
    02_data_audit.sql            Veri denetimi (salt okunur)
    04_faz2_reset.sql            Eski şemayı düşürme (YIKICI — bir daha çalıştırılmamalı)
    05_missing_triggers.sql      2026-09-23'te eksik kalan iki trigger'ın yaması
  CANLIYA_CIKIS.md               Göç adımları + 14 maddelik duman testi listesi
  DUMAN_TESTI.md                 Müşteri yarısının sonucu (28 adım) + temizlik SQL'i

lib/
  main.dart                   MÜŞTERİ girişi (mağaza sürümü)
  main_admin.dart             ADMİN girişi (personel sürümü, mağazaya gitmez)
  app_shell.dart              Ortak MaterialApp kabuğu
  admin/                      login · app · appointments (gün takvimi) · book
                              manage_appointment_sheet · customers · services
                              closures · stats · hour_chip
  config/supabase_config.dart --dart-define ile gelen kimlik bilgileri
  l10n/                       app_tr.arb (şablon) + app_en.arb + üretilmiş dosyalar
  models/                     slot · appointment · customer · salon_service · salon_closure
  providers/                  booking · appointment · availability · catalogue
                              locale · admin
  services/                   booking_repository (arayüz) · supabase_booking_repository
                              booking_exception · local_cache
  screens/                    splash · main_shell · home · appointments · profile
                              edit_profile · setup_required · booking/ (6 ekran)
  widgets/ · theme/ · utils/

test/                         358 test
  widget_test · render_test · admin_render_test · admin_test
  admin_operations_test · booking_concurrency_test · customer_rules_test
  error_mapping_test
  schema_audit_consistency_test  Denetim scriptini şema dosyasıyla karşılaştırır
  fake_booking_repository.dart   Beş kuralı da taklit eden bellek içi backend
```

**Kimlik (Faz 2):** kayıt yok, OTP yok. `claim_customer` ad + telefon eşleşmesiyle
kişiyi buluyor ya da oluşturuyor, cihazı `customer_devices` ile bağlıyor. Aynı kişi
ikinci cihazda ve yeniden kurulumda randevularını görüyor; telefon doğru ama isim
yanlışsa `MN005` dönüyor ve kayıt hakkında hiçbir şey sızmıyor.

**Supabase projesi:** ref `dycjvupgvuxkguorzaqz` — geliştirme projesi canlı olarak
kullanılıyor. Anonim giriş açık, Faz 2 şeması uygulandı ve denetlendi (2026-09-23).
Personel hesabı: `admin@minerva.com.tr`.

---

## 5. Yapılacaklar (sıralı)

### 5.1 Şimdi — sende

| # | İş | Nerede | Durum |
|---|---|---|---|
| 1 | **Duman testinin personel yarısı** — muafiyetler, dolu slot kilidi, `no_show`, işlem/tutar girişi, istatistik, kapalı gün ilanı | `supabase/CANLIYA_CIKIS.md` 7–14. maddeler | 🔴 Bekliyor |
| 2 | **Test verisini sil** — `555999…` ile başlayan ~6 kişi / ~8 randevu + ~21 anonim oturum | `supabase/DUMAN_TESTI.md` sonundaki SQL | 🔴 1'den sonra |
| 3 | **Telefon testi** — Android sideload, iOS TestFlight | — | 🔴 2'den sonra |

> 1. adım canlı veritabanına yazıyor. 2. adım **gerçek müşteri girmeden önce**
> çalıştırılmalı — `555999` filtresi sonrasında da doğru çalışır ama anonim
> kullanıcıları silen sorgu o zaman gerçek müşterileri de götürür.

### 5.2 Gerçek yayın öncesi — açık kalanlar

| İş | Neden bekliyor | Neyi engelliyor |
|---|---|---|
| **Android upload keystore** | Yükleme anında oluşturulacak; şu an yalnızca debug imzası var | Play yayını |
| **iOS admin flavor'ı** | macOS yok; Xcode'da scheme + ayrı bundle id gerekiyor | iOS'ta personel sürümü hiç çıkmaz |
| **iOS release build** | Hiç denenmedi (macOS yok) | iOS yayını |
| **Supabase ücretli plan** | Telefon testiyle birlikte karara bağlanacak | Ücretsiz plan 7 gün hareketsizlikte duraklar, PITR yedek yok |
| **Panel ayarları turu** | `CANLIYA_CIKIS.md` sonundaki 6 maddelik liste henüz tek tek geçilmedi | Kişisel veri canlıya çıkmadan geçilmeli |
| **Personel dağıtım kanalı** | §6'daki açık soru | Keystore ihtiyacının aciliyetini belirliyor |

### 5.3 Dokümantasyon borçları (kodu etkilemiyor)

| Ne | Durum |
|---|---|
| README "226 tests" diyor, gerçek sayı **358** | 🟡 Açık |
| README'nin "Identity, and guest → customer" bölümü hâlâ `profiles` tablosunu ve cihaza bağlı kimliği anlatıyor — Faz 2 ile geçersiz | 🟡 Açık |
| §3'teki tarihçe Faz 2 öncesi anlatımı koruyor | ✅ Bilinçli — geçmiş kaydı, üstüne yazılmıyor |

---

## 6. Açık soru (hâlâ cevap bekliyor)

**Personel admin sürümünü nasıl alacak?**
- (a) İç test kanalı — Play Internal Testing / TestFlight
- (b) Doğrudan APK sideload

Kodu etkilemiyor; sadece README'deki dağıtım yönergesini ve keystore ihtiyacının
aciliyetini belirliyor.

---

## 7. Bilinen durumlar

### 7.1 Çözülenler

| Konu | Nasıl çözüldü |
|---|---|
| Test paketindeki 2 kırmızı (2026-09-10) | Sabit tarihli fixture `DateTime.now()`'a bağlandı (`0146efc`) |
| Tek `applicationId` | Android flavor'ları: `com.oberk.minerva` / `com.oberk.minerva.admin` — ikisi bir telefonda yan yana durabiliyor |
| **Kimlik cihaza bağlıydı** | Faz 2: kimlik telefon numarasında. `claim_customer` ad+telefon eşleşmesiyle kişiyi buluyor, cihazı `customer_devices` ile bağlıyor. İkinci cihazda ve yeniden kurulumda randevular görünüyor — **OTP yok** |
| İki trigger sessizce eksikti (2026-09-23) | `05_missing_triggers.sql` ile kuruldu; şema dosyası artık her trigger'ı oluşturmadan önce düşürüyor, böylece yarım kalmış bir kurulum dosya yeniden çalıştırılarak onarılıyor |
| Gün takvimi küçük telefonda taşıyordu | Faz 5: takvim gün listesiyle birlikte kayıyor — hatayı `admin_render_test.dart` buldu |
| Denetim scripti ile şema sessizce ayrışabiliyordu | `schema_audit_consistency_test.dart` her `flutter test`'te ikisini karşılaştırıyor |

### 7.2 Bilerek böyle (hata değil, karar)

| Konu | Durum |
|---|---|
| Müşteri kısıtları | 21 gün kuralı (`MN002`), 1 saat penceresi, kapalı günler — hepsi veritabanında trigger, uygulamada değil |
| Personel muafiyetleri | Kapalı güne ve 21 günün içine randevu girebilir, son 1 saatte iptal edebilir — **ama dolu slotu alamaz.** Hiç kimsenin muaf olmadığı tek kural |
| iOS tek target | Admin flavor'ı yok; Mac mini oturumunda kurulacak |
| Reddedilen deneme anonim `auth.users` satırı bırakıyor | Duman testinde görüldü; zararsız, temizlik SQL'i `DUMAN_TESTI.md` sonunda |
| Pencere kontrolü unique index'ten önce çalışıyor | Dolu slota pencere içinden taşıma "dolu" değil "üç haftada bir" diyor — mesaj sırası meselesi, kural doğru çalışıyor |
| `MN004` müşteri tarafından sınanamıyor | Duman testinin personel yarısında test edilecek |

---

## 8. Test prosedürü — adım adım

> 2026-09-10'da bu adımlar çalıştırıldı ve geçti; iş `main`'e merge edildi.
> Aşağıdaki liste bundan sonraki değişiklikler için de geçerli olan referans
> prosedürdür — artık worktree'de değil, doğrudan `main` üzerinde uygulanır.

```powershell
cd C:\Projects\minerva_app
git status
flutter pub get
```

### Adım 1 — Otomatik doğrulama

```powershell
flutter analyze     # temiz çıkmalı
flutter test        # 358/358 geçmeli
```

### Adım 2 — Müşteri sürümünü çalıştır

```powershell
flutter run --flavor customer `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Kontrol listesi:
- [ ] Splash → Home açılıyor
- [ ] Yeni randevu akışı sonuna kadar gidiyor (bugünden **sonraki** bir gün seç)
- [ ] Randevu Home'da ve "Randevularım"da görünüyor
- [ ] Profil'de **admin girişi yok** — bu commit'in ana amacı
- [ ] Dil değiştirici çalışıyor (TR/EN anında)

> `--dart-define` verilmezse uygulama "Kurulum gerekli" ekranı gösterir — bu doğru davranış, hata değil.

### Adım 3 — Admin sürümünü çalıştır

Önce personel hesabı hazır olmalı (bir kereye mahsus, Supabase panelinde):

1. **Authentication → Users → Add user** → e-posta + parola, "Auto Confirm" işaretli
2. Kullanıcının `id`'sini kopyala, **SQL Editor**'de:
   ```sql
   insert into public.admins (id) values ('<kopyaladığın-uuid>');
   ```

Sonra:

```powershell
flutter run --flavor admin -t lib/main_admin.dart `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

> Artık ayrı flavor'lar var (`com.oberk.minerva` / `com.oberk.minerva.admin`),
> ikisi aynı telefonda yan yana durabilir — biri diğerinin üzerine kurulmuyor.

Kontrol listesi:
- [ ] Uygulama doğrudan **personel giriş ekranına** açılıyor (müşteri akışı hiç görünmüyor)
- [ ] Yanlış parola anlaşılır hata veriyor
- [ ] `admins` tablosunda **olmayan** geçerli bir kullanıcıyla giriş → randevuları göremiyor (RLS sınırı burada test edilir)
- [ ] Doğru personel hesabıyla giriş → **bugünün** ayına açılıyor, bugün seçili
- [ ] Adım 2'de oluşturduğun randevunun gününde **işaret** var
- [ ] O güne dokun → randevu listede, müşteri adı ve telefonu görünüyor
- [ ] Ay ileri/geri → doğru ay yükleniyor, işaretler güncelleniyor
- [ ] Randevusu olmayan bir güne dokun → boş durum düzgün görünüyor

### Adım 4 — Uçtan uca senaryo (asıl önemli olan)

1. **Müşteri sürümü:** gelecekteki bir güne randevu oluştur
2. **Admin sürümü:** o günde işaret var mı, listede randevu görünüyor mu
3. **Admin sürümü:** randevuyu **iptal et**
4. **Müşteri sürümü:** aynı saat dilimi tekrar **seçilebilir** hale geldi mi (kısmi indeks slot'u serbest bırakıyor)
5. **Müşteri sürümü:** iptal edilen randevu müşterinin listesinden düştü mü

### Adım 5 — Ayrımın gerçekten tuttuğunu doğrula

```powershell
Get-ChildItem -Recurse lib -Filter *.dart | Select-String -Pattern "import .admin/" |
  ForEach-Object { "$($_.Filename): $($_.Line.Trim())" }
```
Tek bir satır çıkmalı:
```
main_admin.dart: import 'admin/admin_app.dart';
```
Başka bir dosya listelenirse admin kodu müşteri build'ine sızmış demektir.
(2026-09-24'te yeniden çalıştırıldı — tek satır çıkıyor, ayrım sağlam.)

### Adım 6 — Release build (isteğe bağlı, uzun sürer)

```powershell
flutter build apk --release --flavor customer `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>

flutter build apk --release --flavor admin -t lib/main_admin.dart `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Play'e yüklemek için `apk` yerine `appbundle` kullanılır — ama imzalama keystore'u
henüz oluşturulmadığı için şimdilik sadece derlenebilirlik testi.

### 2026-09-10 turunun sonucu

Adım 1–5 çalıştırıldı ve geçti (admin girişi + takvim senin tarafından, randevu akışı
daha önce doğrulanmıştı). Release build'ler: müşteri **52.1 MB**, admin **51.5 MB**.
İş `main`'e merge edildi; geriye sadece `git push origin main` kaldı.

---

## 9. Komut kartı

| Amaç | Komut |
|---|---|
| Müşteri sürümü (mağaza) | `flutter build appbundle --release --flavor customer --dart-define=...` |
| Admin sürümü (personel) | `flutter build appbundle --release --flavor admin -t lib/main_admin.dart --dart-define=...` |
| Müşteri sürümünü çalıştır | `flutter run --flavor customer --dart-define=...` |
| Admin sürümünü çalıştır | `flutter run --flavor admin -t lib/main_admin.dart --dart-define=...` |
| Testler | `flutter test` |
| Statik analiz | `flutter analyze` |
| Dil dosyaları | `flutter gen-l10n` (build sırasında otomatik) |

---

## 10. Supabase — canlıya alma (dycjvupgvuxkguorzaqz)

✅ **Yapıldı (2026-09-23).** Karar: geliştirme projesi canlı veritabanı olarak
kullanılıyor. Faz 2 şeması uygulandı ve `01_schema_audit.sql` **sıfır FAIL**
döndürüyor: yedi tablo, üç enum, sekiz trigger, on bir fonksiyon, yirmi altı
politika. Adımların tamamı ve sırası `supabase/CANLIYA_CIKIS.md`'de.

> ⚠️ Eski plandaki `03_production_reset.sql` artık yok; yerini `04_faz2_reset.sql`
> aldı ve o da **bir daha çalıştırılmamalı** — ilk gerçek randevudan itibaren
> salonun kayıtlarını siler.

**Panelden bakılacak, SQL'den görünmeyenler** — `CANLIYA_CIKIS.md` sonundaki altı
maddelik liste, henüz tek tek geçilmedi: anonim giriş ve e-posta sağlayıcısı açık
mı, şifre politikası / sızmış şifre koruması, yedekleme ve PITR (ücretsiz planda
yok), 7 gün hareketsizlikte duraklama, API'de yalnızca `public` şeması,
`service_role` anahtarının uygulamaya / git'e / build komutuna hiç girmemiş olması.

---

## 11. 🔖 Son kalınan nokta — 2026-09-24

**Beş faz da tamamlandı. Sırada duman testinin personel yarısı var (§5.1).**

### Faz 1 — şema (yazıldı → 2026-09-23'te uygulandı)

| Dosya | Ne |
|---|---|
| `supabase/migrations/20260921120000_schema.sql` | 7 tablo, 3 enum, 5 trigger, 7 fonksiyon, tüm RLS |
| `supabase/migrations/20260921120100_catalogue.sql` | Katalog (7 ana + 8 ekstra), fiyat listesinden |
| `supabase/checks/01_schema_audit.sql` | Baştan yazıldı — kuralların yerinde olduğunu da doğruluyor |
| `supabase/checks/02_data_audit.sql` | Baştan yazıldı |
| `supabase/checks/04_faz2_reset.sql` | Eski şemayı düşürme (yıkıcı) |

Eski üç migration dosyası ve `03_production_reset.sql` kaldırıldı (git geçmişinde).

### Faz 2 — uygulama çekirdeği (bitti)

- `Customer`, `SalonClosure`, yeniden yazılmış `SalonService` ve `Appointment`;
  `Profile` kaldırıldı
- `BookingRepository` arayüzü baştan yazıldı; Supabase implementasyonu yeni RPC'leri
  kullanıyor (`book_appointment`, `claim_customer`, `set_appointment_service`,
  `closed_days`)
- Dört yeni kural kodu (`MN002`–`MN005`) `translateError`'da eşlendi, kendi
  `BookingException` sınıfları ve tr/en metinleri var
- `CatalogueProvider` — hizmetler artık veritabanından geliyor, sabit liste yok
- `FakeBookingRepository` beş kuralı da taklit ediyor, testler bunun üzerinden
- **250/250 test geçiyor**, `flutter analyze` temiz

### ✅ Şema canlıda — 2026-09-23

Göç uygulandı ve doğrulandı. `01_schema_audit.sql` **sıfır FAIL** döndürüyor: yedi
tablo, üç enum, sekiz trigger, on bir fonksiyon, yirmi altı politika.

İlk uygulamada iki trigger (`appointments_enforce_window`,
`appointments_reject_closed`) oluşmamıştı — fonksiyonları vardı ama onları çağıran
trigger'lar yoktu, yani 21 gün ve kapalı gün kuralları sessizce uygulanmıyordu.
`05_missing_triggers.sql` ile düzeltildi. Şema dosyası artık her trigger'ı
oluşturmadan önce düşürüyor, böylece yarım kalmış bir kurulum dosyayı yeniden
çalıştırarak onarılabiliyor.

Denetimdeki beş "unexpected security definer function" uyarısı scriptin kendi
hatasıydı (`pg_get_function_identity_arguments` parametre adlarını da döndürüyor);
düzeltildi, güncel dosya temiz dönecek.

### Faz 3 — müşteri uygulaması (bitti)

- **Takvim artık günleri işaretliyor:** dolu günler üstü çizili, Pazar ve ilan
  edilmiş tatiller soluk ve tıklanamaz. Ay başına tek istek (`booked_slots` +
  `closed_days` aralık alıyor), otuz değil
- **Akış sırası düzeltildi:** saat → **işlem** → ad/soyad → onay. Şartnamenin
  istediği sıra ve doğrusu da bu: işlem seçmek gezinmek, telefon yazmak taahhüt
- **Soyad opsiyonel** — şema da öyle (`last_name` nullable). Boş bırakılabilir,
  yarım bırakılamaz
- **Profil düzenleme ekranı** (`edit_profile_screen.dart`). Geçmiş randevular
  alındıkları bilgilerle kalıyor; kişi kaydı "şu an kim olduğu"
- **Randevu değiştirme:** kart üzerinde "Değiştir", takvim ve saat ızgarasını
  yeniden kullanıyor — aynı müsaitlik, aynı kurallar, ayrı ekran yok
- **Kurallar arayüzde önden görünüyor:** iptal ve değiştir düğmeleri randevuya
  1 saat kala ve salonun girdiği kayıtlarda hiç çıkmıyor; 21 gün hatası çakışan
  tarihi ve en erken günü söylüyor
- **269/269 test geçiyor** (+19 yeni), `flutter analyze` temiz

### Faz 4 — admin uygulaması (bitti)

Altı yeni ekran, hepsi takvimin üstündeki tek menünün arkasında — salonun
uygulamayı açma sebebi gün takvimi, gerisi ara sıra:

- **Yeni randevu** (`admin_book_screen`): tek ekran, müşterinin beş adımı değil.
  Telefon numarası tanıdıksa o kişiye bağlanıyor, değilse kişiyi oluşturuyor
- **Randevu yönetimi** (`admin_manage_appointment_sheet`): yapılan işlemleri
  ekleme/çıkarma ve tutar girişi, `completed`/`no_show` işaretleme, saat değiştirme,
  iptal
- **Kişiler**: ad veya telefonla arama, düzenleme, arşivleme ve geri getirme
- **Hizmetler ve fiyatlar**: katalog düzenleme — fiyat değişikliği müşteri
  uygulamasına anında yansıyor
- **Kapalı günler**: tek gün veya aralık ilan etme, kaldırma
- **İstatistik**: bu ay / geçen ay / bu yıl — yapılan, gelmeyen, kazanılan

Personel muafiyetleri bilinçli ve test edilmiş: kapalı güne ve üç haftalık
pencerenin içine randevu girebiliyor, son bir saatte iptal edebiliyor — ama
**dolu bir slotu alamıyor**. İki kişi bir koltuğa oturamaz, bu bir politika
kararı değil.

`no_show` işaretleme ekranında, bunun o kişinin üç haftalık kısıtını **açtığı**
yazılı — düğmeye basan bunu sonradan keşfetmemeli.

**289/289 test geçiyor** (+20 yeni), `flutter analyze` temiz.

### Faz 5 — doğrulama (bitti)

- **Admin ekranları render testine alındı** (`admin_render_test.dart`) ve hemen
  gerçek bir hata buldu: küçük telefonda 1.3× yazı ölçeğinde gün takvimi ekrana
  sığmıyordu (108 px taşma). Takvim artık gün listesiyle birlikte kayıyor —
  sabitlenmiş ama sığmayan bir şey zaten taşar
- **Denetim scripti ile şema karşılaştırıldı** (`schema_audit_consistency_test.dart`).
  Bu ikisi bugüne kadar hiç karşılaştırılmamıştı; denetimin beklentileri elle
  yazıldığı için şemaya eklenen bir policy sessizce denetimsiz kalabilir, daha
  kötüsü şemada olmayan bir şeyi bekleyen bir kontrol sonsuza dek geçer. Artık
  her `flutter test` bunu kontrol ediyor — 25 policy, 8 trigger, 7 tablo,
  13 fonksiyon ve definer listesi örtüşüyor
- **Duman testi listesi hazır** — `supabase/CANLIYA_CIKIS.md`. 14 madde, her biri
  bir kuralı uçtan uca doğruluyor. **Senin onayın olmadan çalıştırılmayacak**

**358/358 test geçiyor** (+69 bu fazda), `flutter analyze` temiz.

### Duman testi — müşteri tarafı yapıldı (2026-09-24)

**→ `supabase/DUMAN_TESTI.md`** — 28 adım, 0 uyarı, adım adım sonuçlar ve
temizlik SQL'i.

Öne çıkanlar: üç cihaz aynı slota aynı anda saldırdı, **tam biri kazandı**;
reddedilen randevular veritabanında iz bırakmadı; `MN002` çakışan tarihi mesajda
söyledi; profil düzenlemek geçmiş randevuyu değiştirmedi.

Üç not: reddedilen bir deneme anonim `auth.users` satırı bırakıyor; pencere
kontrolü unique index'ten önce çalıştığı için dolu slota pencere içinden taşıma
"dolu" değil "üç haftada bir" diyor; `MN004` müşteri tarafından sınanamıyor.

Test **canlı veritabanında ~6 kişi ve ~8 randevu** bıraktı, hepsi `555999` ile
başlayan numaralarda. Silme SQL'i raporun sonunda.

### ✅ Bu tur — 2026-09-24 (doküman güncellemesi)

Kod değişmedi; bu doküman gerçeğe çekildi. Yeniden ölçülenler: `flutter analyze`
**temiz**, `flutter test` **358/358**, `main` = `origin/main` = `37660c9`, çalışma
alanı temiz, tek branch, tek worktree.

Düzeltilen bayatlıklar: §1 özet · §2 branch haritası (silinmiş branch'leri
listeliyordu) · §4 "uygulama kodu hâlâ eski şemaya göre" uyarısı (artık değil) ·
§5 yapılacaklar · §7 kimliğin cihaza bağlı olduğu maddesi (Faz 2 çözdü) · §8
flavor'suz komutlar ve 226 test sayısı · §10 (silinmiş `03_production_reset.sql`'i
tarif ediyordu).

### 🔴 SIRADA — sende

Sıralı liste **§5.1**'de, yayın öncesi açık kalanlar **§5.2**'de, dokümantasyon
borçları **§5.3**'te. Kısaca:

1. Duman testinin **personel yarısı** — `CANLIYA_CIKIS.md` 7–14. maddeler
2. **Test verisini sil** — `DUMAN_TESTI.md` sonundaki SQL
3. **Telefon testi** — Android sideload, iOS TestFlight

Sonrası: Android upload keystore · iOS admin flavor'ı (Mac mini) · Supabase
ücretli plan · panel ayarları turu.
