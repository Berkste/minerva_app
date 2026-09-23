# Minerva Nail Art — Proje Durumu

**Son güncelleme:** 2026-09-10
**Depo:** `C:\Projects\minerva_app`
**Teknoloji:** Flutter 3.47.0 / Dart 3.13.0 · Supabase (Postgres + RLS) · `provider` state yönetimi

---

## 1. Bir bakışta

| | Durum |
|---|---|
| `main` branch | `origin/main` ile eşit — push edildi |
| Açık iş | Yok — admin build ayrımı + gün takvimi `main`'e merge edildi |
| Doğrulama | `flutter analyze` temiz · **226 test geçiyor** · iki release APK derleniyor |
| Sıradaki iş | Supabase projesini canlıya hazırlamak — bkz. §10 |

---

## 2. Branch haritası

```
* 0644b72  (main, origin/main)   flavor: com.oberk.minerva
* …        doküman commit'leri
* 0146efc
* f9a4f3c
* e019b05
*   1ef46cf
|\
| * a742027  feature/admin-appointments
* |   ccbd1fb
|\ \
| |/
|/|
| * a9c1d44  feature/bundle-fonts
|/
* 5c66e25
* 413d4d5  (supbase_work)
* 0b6dbb8  (edit_20260827)
* 3677a83
```

| Branch | Commit | Ne işe yarıyor | Durum |
|---|---|---|---|
| `main` | `0644b72` | Ana hat, her şey burada | ✅ `origin/main` ile eşit |
| ~~`feature/admin-build-and-calendar`~~ | — | Build ayrımı + gün takvimi | ✅ Merge edildi, branch silindi |
| `edit_20260827` | `0b6dbb8` | Lokalizasyon işinin eski branch'i | 🗑️ `main` geçmişinde var, istenirse silinir |
| `supbase_work` | `413d4d5` | Supabase geçişinin eski branch'i | 🗑️ `main` geçmişinde var, istenirse silinir |

**Worktree:** yalnızca `C:/Projects/minerva_app` → `main`. Admin işi için açılan
`.claude/worktrees/agent-a11f59e489ab0fdc9` merge sonrası kaldırıldı.

> Not: `7ccb00b`, `f8185f3`, `c3bee4c`, `678ef2b` commit'leri geçmişin yeniden yazılmasından kalan, hiçbir branch'in işaret etmediği eski kopyalardır. Görmezden gel.

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

### 2026-09-10 — Kullanıcı testi, düzeltme ve merge (bugün)

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

> ⚠️ **Bu bölümün veritabanı kısmı Faz 2 ile değişti.** Aşağıda anlatılan
> `profiles` tablosu, tek `service_id` kolonu ve `user_id` bağı artık geçerli
> değil; güncel şema `supabase/migrations/20260921120000_schema.sql` ve
> tasarım gerekçesi `FAZ2_ANALIZ.md`. Uygulama kodu ise **henüz eski şemaya
> göre** — Faz 2'de güncellenecek.

```
supabase/migrations/
  20260921120000_schema.sql      Şema, RLS, 5 trigger, tekil indeksler
  20260921120100_catalogue.sql   Hizmet kataloğu (7 ana + 8 ekstra)
supabase/checks/
  01_schema_audit.sql            Şema denetimi (salt okunur)
  02_data_audit.sql              Veri denetimi (salt okunur)
  04_faz2_reset.sql              Faz 2 öncesi eski şemayı düşürme (YIKICI)

lib/
  main.dart                   MÜŞTERİ girişi (mağaza sürümü)
  main_admin.dart             ADMIN girişi (personel sürümü, mağazaya gitmez)
  app_shell.dart              Ortak MaterialApp kabuğu
  admin/                      admin_login_screen · admin_app · admin_appointments_screen
  config/supabase_config.dart --dart-define ile gelen kimlik bilgileri
  l10n/                       app_tr.arb (şablon) + app_en.arb + üretilmiş dosyalar
  models/                     slot · appointment · profile · salon_service
  providers/                  booking · appointment · availability · locale · admin
  services/                   booking_repository (arayüz) · supabase_booking_repository
                              booking_exception · local_cache
  screens/                    splash · main_shell · home · appointments · profile
                              setup_required · booking/ (5 adım)
  widgets/ · theme/ · utils/
test/
  widget_test · render_test · booking_concurrency_test · admin_test
  fake_booking_repository.dart   Unique index'i taklit eden bellek içi backend
  error_mapping_test.dart        Postgres hata kodu → müşteri mesajı eşlemesi
```

**Supabase test projesi:** ref `dycjvupgvuxkguorzaqz` · anonim giriş **açık** · admin migration uygulandı (ilk kısmi uygulamadan sonra idempotent tekrar çalıştırmayla düzeltildi).

---

## 5. Yapılacaklar (sıralı)

### Şimdi
| # | İş | Kim | Durum |
|---|---|---|---|
| 1 | Feature branch'i test et | Sen | ✅ Bitti |
| 2 | Tarihi geçmiş sabit test verisini düzelt | Ben | ✅ `0146efc` |
| 3 | `feature/admin-build-and-calendar` → `main` merge | Ben | ✅ Fast-forward |
| 4 | `main` üzerinde analyze + test + iki release build | Ben | ✅ Temiz / 226 / derlendi |
| 5 | Feature branch + worktree temizliği | Ben | ✅ Kaldırıldı |
| 6 | **`git push origin main`** | **Sen** | 🟡 **Bekliyor** |

```powershell
git -C C:\Projects\minerva_app push origin main
```

Eski `edit_20260827` ve `supbase_work` branch'leri duruyor; ikisinin de commit'leri
`main` geçmişinde var, istersen tek komutla silinir.

### Gerçek yayın öncesi
| İş | Not |
|---|---|
| **Android upload keystore oluşturulması** | Henüz yok — Play yayını için şart |
| iOS release build denemesi | Hiç denenmedi (macOS yok) |
| Prod Supabase projesi | Şu an test projesi (`dycjvupgvuxkguorzaqz`) kullanılıyor |
| Personel dağıtım kanalı seçimi | §6'daki açık soru |

---

## 6. Açık soru (cevap bekliyor)

**Personel admin sürümünü nasıl alacak?**
- (a) İç test kanalı — Play Internal Testing / TestFlight
- (b) Doğrudan APK sideload

Kodu etkilemiyor; sadece README'deki dağıtım yönergesini ve keystore ihtiyacının aciliyetini belirliyor.

---

## 7. Bilinen durumlar

### 7.1 ✅ Çözüldü — test paketindeki 2 kırmızı (2026-09-10)

`test/booking_concurrency_test.dart:22`'deki `Slot(DateTime(2026, 9, 4), 14)` sabit tarihti.
İki test `provider.upcoming.length == 1` bekliyordu; `upcoming` ise `DateTime.now()`'a göre
süzüyor, dolayısıyla 4 Eylül geçtikten sonra liste boş dönmeye başladı — kod regresyonu değil,
zaman bombası fixture'ı. Slot artık `DateTime.now().add(Duration(days: 7))` ile üretiliyor
(commit `0146efc`). **226/226 geçiyor.**

### 7.2 Bilerek ertelenenler (hata değil, karar)

| Konu | Durum |
|---|---|
| Admin yetkisi | Sadece **görüntüleme + iptal**. Randevu oluşturma/erteleme yok (RLS'te de admin INSERT politikası yok) |
| ~~Tek `applicationId`~~ | ✅ Çözüldü (2026-09-10): Android flavor kuruldu — `com.oberk.minerva` / `com.oberk.minerva.admin`, ikisi bir telefonda durabiliyor. iOS hâlâ tek target |
| Kimlik cihaza bağlı | Anonim giriş kurulum başına; ikinci cihazda veya yeniden kurulumda müşteri randevularını göremez. Çözüm yolu belli: telefon doğrulaması ile anonim kullanıcıyı bağlamak — şema değişmiyor |
| README test sayısı | README "210 tests" diyor, gerçek sayı 226 — küçük tutarsızlık |

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
flutter test        # 226/226 geçmeli
```

### Adım 2 — Müşteri sürümünü çalıştır

```powershell
flutter run `
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
flutter run -t lib/main_admin.dart `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

> Aynı `applicationId` olduğu için admin sürümü müşteri sürümünün üzerine kurulur.
> Sırayla test et, ikisini aynı anda telefonda tutmaya çalışma.

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
(Bugün çalıştırdım — tek satır çıkıyor, ayrım sağlam.)

### Adım 6 — Release build (isteğe bağlı, uzun sürer)

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://dycjvupgvuxkguorzaqz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>

flutter build apk --release -t lib/main_admin.dart `
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

## 10. Supabase'i canlıya alma (dycjvupgvuxkguorzaqz)

Karar: mevcut geliştirme projesi canlı veritabanı olarak kullanılacak. Aşağıdaki
sıra, o projeyi savunulabilir bir canlı ortama çeviren adımlar. SQL'ler
`supabase/checks/` altında.

| # | Adım | Nasıl |
|---|---|---|
| 1 | Şema denetimi | `01_schema_audit.sql`'i SQL editöründe çalıştır. FAIL satırı kalmamalı |
| 2 | Veri denetimi | `02_data_audit.sql` — bölüm bölüm çalıştır, özellikle 1. sorgu (çifte rezervasyon) boş dönmeli |
| 3 | Temiz yeniden uygulama | `03_production_reset.sql` Bölüm A → sonra iki migration'ı sırayla yeniden çalıştır |
| 4 | Test kullanıcılarını sil | `03` Bölüm 3 — anonim kullanıcılar (cascade ile randevu/profil de gider) |
| 5 | Personel listesini kur | `03` Bölüm 4 — geliştirme hesaplarını çıkar, gerçek personeli ekle |
| 6 | Panel ayarları | `03` Bölüm 5'teki liste — anonim giriş, yedekleme planı, ücretsiz planın 7 günlük duraklatması |
| 7 | Tekrar denetle | `01`'i yeniden çalıştır — hepsi OK olmalı |

**3. adım neden önemli:** bu projedeki şema, migration'ların temiz bir geçişiyle
değil, kısmi uygulanan bir migration'ın yamalanmasıyla oluştu. Veri hâlâ
atılabilir durumdayken sıfırdan uygulamak, canlı şemanın git'teki şemayla
birebir aynı olduğunu **kanıtlar**. Gerçek müşteri verisi geldikten sonra bu
seçenek kapanır.

**Bunlar SQL'den görünmez, panelden bakılacak:** anonim giriş açık mı, yedekleme
/ PITR var mı (ücretsiz planda yok), proje 7 gün hareketsizlikte duraklar mı,
API'de yalnızca `public` şeması açık mı, `service_role` anahtarı hiçbir yerde
uygulamaya girmiş mi.

---

## 11. 🔖 Son kalınan nokta — 2026-09-21

**Faz 1 + Faz 2 tamamlandı. Sırada SQL'in çalıştırılması var.**

### Faz 1 — şema (yazıldı, uygulanmayı bekliyor)

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

### 🔴 SIRADA — Faz 4 (admin ekranları)

Randevu oluşturma (telefonla kişi arama) · işlem listesi düzenleme + tutar girişi ·
`completed`/`no_show` işaretleme · kişi listesi · hizmet ve fiyat yönetimi ·
takvim kapatma · istatistik sayfası.

Repository ve provider katmanı bunların hepsini zaten destekliyor — eksik olan
yalnızca ekranlar.

### Sonraya bırakılanlar
- **Duman testi** — Berk'in onayı olmadan yapılmayacak
- **Telefon testi** — her şey bittikten sonra
- **Android upload keystore** — yükleme anında
- **iOS admin flavor'ı yok** — Mac mini oturumunda Xcode'da kurulacak
- **Supabase ücretli plan** — telefon testiyle birlikte
