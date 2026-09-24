# Faz 1 — şema göçü: uygulama adımları

**Proje:** `dycjvupgvuxkguorzaqz` · **Durum:** çalıştırılmaya hazır

Bu dosya, Faz 2 tasarımının veritabanı tarafını canlıya almak için **senin**
yapacağın işleri sırasıyla anlatır. Tasarımın gerekçesi `FAZ2_ANALIZ.md`'de.

---

## ✅ Sıra geldi — Faz 2 tamamlandı

Bu göç, uygulama kodu eski şemaya göreyken hazırlanmıştı. **Artık değil:** Faz 2
bitti, `lib/` altındaki her şey yeni şemaya taşındı ve `profiles`, `user_id`, tek
`service_id` kolonu kodda hiç kalmadı.

Yani uygulama şu anda **yeni şemayı bekliyor**. Bu SQL çalıştırılmadan derlenen bir
build canlı veritabanına bağlanamaz — tablolar tutmuyor.

**Şimdi çalıştırılabilir.** 250/250 test geçiyor, `flutter analyze` temiz.

## Ne değişiyor

| Eski | Yeni |
|---|---|
| `profiles` (kimlik = cihaz) | `customers` (kimlik = telefon) + `customer_devices` |
| `appointments.user_id` → `auth.users` | `appointments.customer_id` → `customers` |
| `service_id` kolonu + CHECK kısıtı | `services` tablosu + `appointment_services` satırları |
| 2 durum (`confirmed`, `cancelled`) | 4 durum (+ `completed`, `no_show`) |
| Gerçek silme yok, kolon da yok | Her tabloda `deleted_at` — soft delete |
| 1 kural trigger'ı (`MN001`) | 5 trigger: `MN001`–`MN005` |
| — | `salon_closures` (Pazar + tatil günleri) |

---

## Adımlar

### 0. Kontrol et — gerçekten boş mu?

`04_faz2_reset.sql`'in başındaki sorgu bunun için var. Çalıştır:

```sql
select
  (select count(*) from public.appointments)                            as appointments,
  (select count(*) from public.profiles)                                as profiles,
  (select count(*) from auth.users where coalesce(is_anonymous, false)) as anonymous_users,
  (select count(*) from public.admins)                                  as staff;
```

**Beklenen: 0 · 0 · 0 · 1.**

Başka bir şey görürsen **dur ve bana söyle** — biri uygulamayı kullanmış demektir
ve bu göç onun randevularını da götürür. 11 Eylül'den bu yana zaman geçti, bu
yüzden bu adım atlanmamalı.

### 1. (İsteğe bağlı) Yedek

Panel → **Database → Backups**. Atılacak veri değersiz ama ihtiyaç duymadığın bir
yedek, tersinden iyidir.

### 2. Eski şemayı düşür

`supabase/checks/04_faz2_reset.sql` → **Section 1**'deki `/* */` bloğunu aç ve
çalıştır.

### 3. Yeni şemayı kur

SQL editöründe, bu sırayla, her birini ayrı çalıştır:

1. `supabase/migrations/20260921120000_schema.sql`
2. `supabase/migrations/20260921120100_catalogue.sql`

İkincisi bir özet sorgusuyla bitiyor: **7 satır `main`, 8 satır `extra`** görmelisin.

### 4. Personel yetkisini geri ver

> ⚠️ Bu adım bitene kadar admin uygulaması kilitli — `admins` tablosu yeniden
> kuruldu ve boş. Personel hesabının kendisi `auth.users`'da duruyor, kaybolmadı.

```sql
insert into public.admins (id)
values ('8ee7ffc9-b007-46ac-b6a8-7dd2d69fec44')
on conflict (id) do nothing;
```

Doğrula — tam **1** satır, `admin@minerva.com.tr`:

```sql
select ad.id, u.email, ad.created_at as admin_since
from public.admins ad left join auth.users u on u.id = ad.id;
```

### 5. Denetimi çalıştır

`supabase/checks/01_schema_audit.sql` → **tek bir FAIL kalmamalı.**

Bu denetim baştan yazıldı ve artık kuralların gerçekten yerinde olduğunu da
kontrol ediyor — sadece tabloların varlığını değil:

- `appointments_one_active_per_slot` indeksi doğru şartla duruyor mu *(çifte
  rezervasyon garantisi)*
- Beş trigger da bağlı mı, `MN001`–`MN005` kodlarını gerçekten fırlatıyor mu
- `created_by_admin` istemciden değil trigger'dan geliyor mu *(gelmiyorsa bir
  müşteri kendini 21 gün kuralından muaf tutabilir)*
- Hiçbir tabloda DELETE politikası yok mu *(soft delete kuralı)*
- `anon` yalnızca `booked_slots` ve `closed_days` çağırabiliyor mu

### 5b. İki trigger eksikse — 2026-09-23'te öyle oldu

İlk denetim şu ikisini `MISSING` döndürdü:

```
FAIL  5. triggers  appointments_enforce_window   MISSING
FAIL  5. triggers  appointments_reject_closed    MISSING
```

Fonksiyonlar oluşmuştu, onları çağıran trigger'lar oluşmamıştı — yani 21 gün ve
kapalı gün kuralları **uygulanmıyordu**. Sebebi kesin olarak bilinmiyor; şema
dosyası artık her trigger'ı oluşturmadan önce düşürdüğü için dosyayı yeniden
çalıştırmak bu durumu onarır.

Daha küçük çözüm: **`supabase/checks/05_missing_triggers.sql`** çalıştır, sonra
denetimi tekrarla.

### 6. Veriyi gözden geçir

`supabase/checks/02_data_audit.sql` → bölüm bölüm çalıştır. **1. sorgu boş
dönmeli** (aynı slotta iki canlı randevu). 7. bölümde katalog özeti görünür.

---

## Bundan sonra

Faz 2, 3 ve 4 tamamlandı: müşteri ve personel uygulamalarının tamamı yazıldı.

`04_faz2_reset.sql` bu göçten sonra bir daha **çalıştırılmamalı** — ilk gerçek
randevudan itibaren salonun kayıtlarını siler.

---

## Duman testi — hazır, senin onayınla

Sen söylemeden yapmıyorum. Sıra geldiğinde listesi bu; her madde bir kuralı
uçtan uca doğruluyor, ekranları gezmiyor.

### Müşteri uygulaması

1. **Hiçbir şey yazılmıyor:** uygulamayı aç, takvimi gez, **randevu alma**, kapat.
   → `02_data_audit.sql` 2. sorgu: `customers` ve `appointments` **0** olmalı
2. **Kapalı günler görünüyor:** takvimde Pazar soluk ve tıklanamaz olmalı
3. **Randevu al:** ad + telefon (soyadı boş bırak) → kayıt oluşmalı
   → `02` 2. sorgu: 1 müşteri, 1 randevu. Soyad `null`
4. **21 gün kuralı:** aynı cihazdan bir hafta sonrasına ikinci randevu dene
   → "Üç haftada bir randevu alabilirsiniz. En erken **[tarih]**" demeli — tarihi
   söylemesi önemli, "şu an alamazsınız" demesi yeterli değil
5. **İptal penceresi:** randevun bir saatten uzaksa "İptal" ve "Değiştir" görünür;
   cihazın saatini randevuya yarım saat kalaya alırsan **ikisi de kaybolmalı**
6. **Profil düzenleme:** soyadı ekle, kaydet → profilde görünmeli ama
   **randevunun üstündeki isim değişmemeli**

### Personel uygulaması

7. **Giriş:** `admin@minerva.com.tr`
8. **Gün takvimi:** 3. adımda aldığın randevu görünmeli
9. **İşlem ve tutar:** randevuyu aç, bir ekstra ekle, tutarını değiştir
   → kart üzerinde toplam görünmeli
10. **Muafiyetler:** aynı kişiye iki gün sonrasına randevu gir → **geçmeli**
    (müşteri geçemezdi). Bir Pazar'a randevu gir → **geçmeli**
11. **Dolu slot:** 3. adımdaki randevunun tam saatine ikinci randevu gir
    → **geçmemeli.** Bu, hiç kimsenin muaf olmadığı tek kural
12. **Gelmedi:** randevuyu `no_show` işaretle → müşteri uygulamasından aynı kişi
    hemen yeni randevu alabilmeli (kilit açılmalı)
13. **İstatistik:** yapılan/gelmeyen sayıları ve kazanılan tutar tutmalı
14. **Kapalı gün ilan et:** bir aralık kapat → müşteri takviminde soluk görünmeli

### Test sonrası

Duman testinde oluşan kayıtlar veritabanında kalır. Gerçek müşterilere açmadan
önce temizlemek istersen `04_faz2_reset.sql` Section 1 + migration'ları yeniden
çalıştırmak gerekir — **o an**, gerçek kimse girmeden.

---

## Panelde SQL'in göremediği ayarlar

Faz 1 bunları değiştirmiyor, ama canlıya çıkmadan önce tek tek geçilmeli:

- [ ] **Authentication → Sign In / Providers**: Anonim giriş **AÇIK** (kapalıysa
      müşteri uygulaması hiç giremez), E-posta sağlayıcı **AÇIK**
- [ ] **Şifre politikası / sızmış şifre koruması**: personel hesabı her müşterinin
      adına ve telefonuna erişiyor
- [ ] **Database → Backups**: ücretsiz planda point-in-time recovery yok. Gerçek
      müşteri adı ve telefonu kişisel veri
- [ ] **Project → General**: ücretsiz proje 7 gün hareketsizlikte duraklar
- [ ] **API → Exposed schemas**: sadece `public`
- [ ] **Project → API keys**: `service_role` anahtarı uygulamaya, git'e veya build
      komutuna asla girmemeli
