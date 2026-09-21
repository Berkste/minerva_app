# Minerva Nail Art

A minimal Flutter appointment-booking app for a nail salon, built to the
Minerva UI/UX spec: modern, minimalist, purple / pink / white.

## Running it

Bookings live in Supabase, so the app needs credentials at build time:

```bash
flutter pub get
flutter run --flavor customer \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

`--flavor` is not optional: the Android module defines two of them (see
**Builds**), so without one there is no single variant to assemble. Add
`--flavor admin -t lib/main_admin.dart` to run the staff app instead.

Built without them, the app shows a "Setup required" screen instead of failing
at the first query. See **Backend** below for the one-time project setup.

To preview in a browser instead of on a device, add the web target first:

```bash
flutter create --platforms=web .
flutter run -d chrome
```

## Builds

Two separate apps come out of this one codebase. They differ in the Dart entry
point that is compiled in and in the Android product flavor that names them:

| | Customer | Admin / employee |
| --- | --- | --- |
| Entry point | `lib/main.dart` | `lib/main_admin.dart` |
| Flavor | `customer` | `admin` |
| Application id | `com.oberk.minerva` | `com.oberk.minerva.admin` |
| Launcher name | Minerva | Minerva Personel |
| Distribution | App Store / Google Play | Internal only — never the public listings |

**Customer** contains **no admin panel and no reachable admin code**: nothing in
its import graph references `lib/admin/`, so the store binary cannot open the
staff screens at all.

```bash
flutter build appbundle --release --flavor customer \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

**Admin / employee** launches straight into the staff login. Distribute it to
staff directly (its own internal track, or a sideloaded APK).

```bash
flutter build appbundle --release --flavor admin -t lib/main_admin.dart \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

The two application ids are the point of the split. They let both apps sit on
one phone, and they keep the staff build out of the customer's Play listing —
an internal testing track belongs to one listing, so a same-id admin build
would reach testers as an *update to the customer app*. An application id is
fixed at the first store upload and cannot be changed afterwards.

iOS still has a single target (`com.oberk.minerva`); the equivalent split there
is a second target with its own bundle id, left until there is a Mac to build
and test it on.

## The booking flow

Splash → Home → **Calendar → Time → Details → Service (optional) → Review →
Success** → the booking appears on Home and in My Appointments.

| Step | Screen | Notes |
| --- | --- | --- |
| — | Splash | Logo, tagline, "Get Started" |
| — | Home | Hero banner, "New Appointment", next booking, service preview |
| 1 | Calendar | Month grid; past days disabled, today ringed |
| 2 | Time | 10:00–20:00 in 2-hour steps; past and taken slots blocked |
| 3 | Details | Name fields plus a masked phone number, all validated |
| 4 | Service | Four treatments at 1.000 TL; skippable |
| 5 | Review | Every field, one screen, before anything is saved |
| — | Success | Confetti burst and the confirmed summary |

Bottom navigation: **Home · Appointments · Profile**.

## Backend

Supabase. Schema and policies live in
`supabase/migrations/20260921120000_schema.sql`, with the service catalogue in
`20260921120100_catalogue.sql` — run them once, in that order, in the SQL
editor. `supabase/checks/01_schema_audit.sql` then verifies the result.

### One booking per slot

This is the guarantee the whole design is built around, and it is enforced in
one place:

```sql
create unique index appointments_one_confirmed_per_slot
  on public.appointments (slot_date, slot_hour)
  where status = 'confirmed';
```

Postgres evaluates that index inside each insert's own transaction, so of two
simultaneous bookings for the same slot exactly one commits and the other
fails with SQLSTATE `23505`. There is no window between "check" and "insert"
for a second booking to slip through.

The app therefore **never checks availability before writing**. It attempts
the insert and lets the database decide; `23505` is translated to
`SlotTakenException`, the customer is told someone else got there first, the
slot is greyed out, and they are dropped back on the time grid. Availability
is fetched only to grey out slots up front — it is a courtesy, never a
permission.

The index is *partial* so cancelling frees the slot: a cancelled row keeps its
slot but drops out of the index.

### Slots are wall clock, not instants

`slot_date` + `slot_hour`, never a `timestamptz` computed on the device.

If the slot were an instant, two phones in different time zones would turn
"14:00" into two different instants and uniqueness would not bite — both
bookings would succeed for what the salon considers one slot. The salon's day
is wall clock, so that is what is stored and what uniqueness is enforced on.

### Identity, and guest → customer

There is no sign-up. On first launch the app signs in **anonymously**, which
gives the device a durable `auth.uid()`. The first completed booking writes a
`profiles` row from the details form — that is the moment a guest becomes a
known customer, and later bookings prefill from it and keep it current.

Anonymous sign-ins must be enabled in the Supabase dashboard
(*Authentication → Sign In / Providers → Anonymous sign-ins*).

Two consequences worth knowing:

- The identity is per install. The same person on a second device is a
  different user and will not see their bookings there.
- Reinstalling loses the session. The bookings stay in the database and keep
  occupying their slots, but the customer can no longer see or cancel them.

Both are fixed the same way: let customers verify the phone number they
already type in, and link the anonymous user to it. The schema does not change
— `auth.uid()` survives the upgrade, and existing rows come with it.

### Privacy

RLS restricts every row to its owner, so no customer can read another's name
or phone number. Availability would be impossible under that rule, so it comes
from a `security definer` function that returns slot keys and nothing else:

```sql
select * from public.booked_slots('2026-09-01', '2026-09-30');
-- slot_date  | slot_hour
```

### Other server-side rules

- A trigger rejects bookings whose slot has already passed in
  `Europe/Istanbul`, so a device with a wrong clock cannot book yesterday.
- `slot_hour` is constrained to the salon's hours, `phone` to ten digits, and
  names to 2–60 characters — the same rules the app enforces, restated where
  they cannot be bypassed.
- There is no delete policy. Bookings are cancelled, never erased.

### Offline

Supabase is the source of truth. The last known appointments and profile are
cached on the device so the home screen is not blank without a connection; the
list says plainly when it is showing a cached copy. Booking always requires a
connection — availability is never answered from cache.

## Languages

The app ships Turkish and English. It follows the device language and falls
back to **Turkish** for anything else; Profile has a switcher (device default /
Türkçe / İngilizce) that applies immediately and is remembered.

Strings live in `lib/l10n/app_tr.arb` (the template) and `app_en.arb`, and
`AppLocalizations` is generated from them by `flutter gen-l10n` — driven by
`l10n.yaml` and regenerated automatically on build.

Only stable ids are persisted, never display text, so an appointment saved in
one language renders correctly in the other. Date *patterns* are part of the
string catalogue rather than hard-coded, because the two languages order the
parts differently:

| | Turkish | English |
| --- | --- | --- |
| Full date | 4 Eylül 2026 Cuma | Friday, 4 September 2026 |
| Weekdays | Pzt Sal Çar Per Cum Cmt Paz | Mon Tue Wed Thu Fri Sat Sun |

Times stay 24-hour (`16:00 – 18:00`) in both.

To add a string: put it in `app_tr.arb`, translate it in `app_en.arb`, and use
`AppLocalizations.of(context)`.

## Phone numbers

The phone field is masked to `(555) 555 55 55` as the user types
(`lib/utils/phone_formatter.dart`). Only digits are kept from the input, so
pasting `+90 555 123 45 67`, `0555 123 45 67` or `905551234567` all reduce to
the same ten digits; the brackets and spaces are inserted by the formatter and
the caret is moved past them so typing runs straight on. The step will not
advance until all ten digits are present.

Numbers stored before this format existed are re-masked on display, and
anything that cannot be parsed is shown unchanged rather than mangled.

## Design system

| Token | Value |
| --- | --- |
| Purple | `#7B4DFF` |
| Pink | `#FFB6C1` |
| White | `#FFFFFF` |
| Light purple | `#F3E8FF` |

Typography is Poppins, bundled as an asset under `assets/fonts/` (weights
400/500/600/700, licensed OFL) so the app never fetches it at runtime. Corner
radius, card surface, field decoration and button geometry are defined once in
`lib/theme/app_theme.dart`, so screens stay declarative.

The logo is drawn with a `CustomPainter` (`lib/widgets/minerva_logo.dart`)
rather than shipped as an image — it stays crisp at any size and the app needs
no asset bundle.

## Architecture

```
supabase/
  migrations/               Schema, RLS, the uniqueness index

lib/
  main.dart                 App entry, providers, locale wiring
  config/
    supabase_config.dart    Credentials from --dart-define
  l10n/
    app_tr.arb / app_en.arb String catalogues (tr is the template)
    app_localizations*.dart Generated — do not edit by hand
  models/
    slot.dart               Wall-clock slot identity (date + hour)
    appointment.dart        Booking record + row mapping
    profile.dart            Saved contact details
    salon_service.dart      Fixed catalogue; names resolved per language
  providers/
    booking_provider.dart   The in-progress booking (not persisted)
    appointment_provider.dart  Bookings + profile, with load/offline state
    availability_provider.dart Which slots are taken, live
    locale_provider.dart    Language choice, remembered between launches
  services/
    booking_repository.dart          The backend interface
    supabase_booking_repository.dart The Supabase implementation
    booking_exception.dart           Failures the UI can explain
    local_cache.dart                 Offline read-through copy
  screens/
    splash_screen.dart
    main_shell.dart         Bottom navigation, keeps tabs alive
    home_screen.dart
    appointments_screen.dart
    profile_screen.dart
    booking/                The five booking steps
  widgets/                  SoftCard, GradientButton, InfoRow, logo, …
  utils/
    formatting.dart         Locale-aware date/time/phone display
    phone_formatter.dart    The (555) 555 55 55 input mask
```

**State** — `provider`. The draft booking and the saved list are deliberately
separate: nothing is written to storage until the user confirms on the review
screen.

**Persistence** — `shared_preferences`, storing the appointment list as a
single JSON array. Corrupted data degrades to an empty list rather than
crashing.

**Slot conflicts** — the time grid greys out taken slots, and the review screen
re-checks immediately before saving in case the state changed mid-flow.

## Tests

```bash
flutter test
```

226 tests. `test/fake_booking_repository.dart` is an in-memory stand-in for
Supabase that reproduces the unique index, so the double-booking race is
testable without a live database — including the nasty interleaving where a
slot is taken *between* the availability check and the insert.

- **Concurrency** — the second booking of a slot is rejected; a slot taken by
  another customer cannot be booked; a slot taken mid-flight still cannot
  double book; cancelling releases it; other hours are unaffected.
- **Slot identity** — a slot is a date and an hour, so two `DateTime`s on the
  same day are the same slot whatever time they carry.


- **Unit** — appointment JSON round trip, 2-hour duration, upcoming/past
  boundaries, booking-draft rules (a new date clears the chosen hour, `reset()`
  empties everything), storage persistence and corruption recovery, locale
  resolution and persistence, date formatting in both languages.
- **Phone** — the mask as it builds up digit by digit, prefix stripping, the
  ten-digit cap, caret placement across inserted separators, and re-masking of
  legacy stored numbers.
- **Widget** — the splash leads into the app; an unsupported device language
  falls back to Turkish; "Select Time" stays disabled until a day is picked;
  the phone field masks what is typed and blocks an incomplete number;
  switching language on Profile re-renders the whole shell.
- **Render** — all 11 screens × 2 languages × 3 phone sizes (360×640, 390×844,
  430×932) × both ends of the supported text-scale range. A `RenderFlex`
  overflow surfaces as a thrown exception in widget tests, so these are a real
  check that the responsive layout holds — Turkish strings are longer than
  their English counterparts on several screens.
