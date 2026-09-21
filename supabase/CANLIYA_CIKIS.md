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

### 6. Veriyi gözden geçir

`supabase/checks/02_data_audit.sql` → bölüm bölüm çalıştır. **1. sorgu boş
dönmeli** (aynı slotta iki canlı randevu). 7. bölümde katalog özeti görünür.

---

## Bundan sonra

Sırada Faz 3 ve 4 var: müşteri ve admin ekranlarının tamamlanması. Çekirdek hazır,
eksik olan yalnızca arayüz — bu yüzden SQL çalıştıktan sonra uygulama temel akışı
(gez → gün seç → saat seç → bilgi gir → randevu al) baştan sona yapabilir.

`04_faz2_reset.sql` bu göçten sonra bir daha **çalıştırılmamalı** — ilk gerçek
randevudan itibaren salonun kayıtlarını siler.

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
