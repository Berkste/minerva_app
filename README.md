# Minerva Nail Art

A minimal Flutter appointment-booking app for a nail salon, built to the
Minerva UI/UX spec: modern, minimalist, purple / pink / white.

## Running it

```bash
flutter pub get
flutter run
```

To preview in a browser instead of on a device, add the web target first:

```bash
flutter create --platforms=web .
flutter run -d chrome
```

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

Typography is Poppins (via `google_fonts`). Corner radius, card surface, field
decoration and button geometry are defined once in `lib/theme/app_theme.dart`,
so screens stay declarative.

The logo is drawn with a `CustomPainter` (`lib/widgets/minerva_logo.dart`)
rather than shipped as an image — it stays crisp at any size and the app needs
no asset bundle.

## Architecture

```
lib/
  main.dart                 App entry, providers, locale wiring
  l10n/
    app_tr.arb / app_en.arb String catalogues (tr is the template)
    app_localizations*.dart Generated — do not edit by hand
  models/
    appointment.dart        Booking record + JSON round trip
    salon_service.dart      Fixed catalogue; names resolved per language
  providers/
    booking_provider.dart   The in-progress booking (not persisted)
    appointment_provider.dart  Confirmed bookings, keeps storage in sync
    locale_provider.dart    Language choice, remembered between launches
  services/
    storage_service.dart    SharedPreferences read/write as one JSON array
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

171 tests:

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
