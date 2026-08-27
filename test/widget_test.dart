import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/l10n/app_localizations.dart';
import 'package:minerva_app/main.dart';
import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/providers/booking_provider.dart';
import 'package:minerva_app/providers/locale_provider.dart';
import 'package:minerva_app/screens/booking/calendar_screen.dart';
import 'package:minerva_app/screens/booking/details_screen.dart';
import 'package:minerva_app/services/storage_service.dart';
import 'package:minerva_app/utils/formatting.dart';
import 'package:minerva_app/utils/phone_formatter.dart';

/// Builds a [Fmt] bound to [locale], by reading it out of a live widget tree.
Future<Fmt> _fmtFor(WidgetTester tester, Locale locale) async {
  late Fmt fmt;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          fmt = Fmt.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return fmt;
}

/// Wraps a booking step in the providers and localizations it expects.
Widget _wrapBookingScreen(Widget child, Locale locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppointmentProvider()..load()),
      ChangeNotifierProvider(
        create: (_) => BookingProvider()
          ..selectDate(DateTime.now().add(const Duration(days: 2)))
          ..selectHour(16),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUpAll(() async {
    // Month and weekday names for both languages.
    await initializeDateFormatting();
  });

  setUp(() {
    // Every test starts from an empty local store.
    SharedPreferences.setMockInitialValues({});
  });

  group('Appointment', () {
    final appointment = Appointment(
      id: 'a1',
      start: DateTime(2026, 8, 14, 16),
      firstName: 'Elif',
      lastName: 'Yilmaz',
      phone: '+90 555 123 45 67',
      serviceId: 'classic_manicure',
    );

    test('ends two hours after it starts', () {
      expect(appointment.end, DateTime(2026, 8, 14, 18));
    });

    test('survives a JSON round trip', () {
      final restored = Appointment.fromJson(appointment.toJson());

      expect(restored.id, appointment.id);
      expect(restored.start, appointment.start);
      expect(restored.fullName, 'Elif Yilmaz');
      expect(restored.serviceId, 'classic_manicure');
    });

    test('is upcoming only until it has finished', () {
      final start = DateTime(2026, 8, 14, 16);

      expect(appointment.isUpcoming(now: start.subtract(const Duration(days: 1))),
          isTrue);
      // Still upcoming halfway through the slot.
      expect(appointment.isUpcoming(now: start.add(const Duration(hours: 1))),
          isTrue);
      expect(appointment.isUpcoming(now: start.add(const Duration(hours: 3))),
          isFalse);
    });
  });

  group('BookingProvider', () {
    test('offers 10:00 to 20:00 in two-hour steps', () {
      expect(BookingProvider.availableHours, [10, 12, 14, 16, 18, 20]);
    });

    test('combines the chosen date and hour into one instant', () {
      final booking = BookingProvider()
        ..selectDate(DateTime(2026, 8, 14, 9, 30))
        ..selectHour(16);

      // The time part of the picked date is discarded.
      expect(booking.start, DateTime(2026, 8, 14, 16));
      expect(booking.end, DateTime(2026, 8, 14, 18));
    });

    test('clears the chosen hour when the date changes', () {
      final booking = BookingProvider()
        ..selectDate(DateTime(2026, 8, 14))
        ..selectHour(16);

      booking.selectDate(DateTime(2026, 8, 15));

      expect(booking.hour, isNull);
      expect(booking.start, isNull);
    });

    test('reset() empties every field', () {
      final booking = BookingProvider()
        ..selectDate(DateTime(2026, 8, 14))
        ..selectHour(16)
        ..setDetails(firstName: 'Elif', lastName: 'Yilmaz', phone: '05551234567')
        ..selectService('gel_manicure');

      booking.reset();

      expect(booking.date, isNull);
      expect(booking.hour, isNull);
      expect(booking.firstName, isEmpty);
      expect(booking.serviceId, isNull);
    });

    test('trims whitespace out of the customer details', () {
      final booking = BookingProvider()
        ..setDetails(
          firstName: '  Elif ',
          lastName: ' Yilmaz  ',
          phone: ' +90 555 123 45 67 ',
        );

      expect(booking.firstName, 'Elif');
      expect(booking.lastName, 'Yilmaz');
      expect(booking.phone, '+90 555 123 45 67');
    });
  });

  group('AppointmentProvider', () {
    test('persists appointments and reloads them sorted by start', () async {
      final provider = AppointmentProvider();
      await provider.load();

      await provider.add(_appointmentAt(DateTime(2026, 8, 20, 12), id: 'later'));
      await provider.add(_appointmentAt(DateTime(2026, 8, 14, 16), id: 'sooner'));

      expect(
        provider.appointments.map((a) => a.id),
        ['sooner', 'later'],
      );

      // A fresh provider reads the same data back out of storage.
      final reloaded = AppointmentProvider();
      await reloaded.load();
      expect(reloaded.appointments.map((a) => a.id), ['sooner', 'later']);
    });

    test('flags a slot as taken once it is booked', () async {
      final provider = AppointmentProvider();
      await provider.load();

      final slot = DateTime(2026, 8, 14, 16);
      expect(provider.isSlotTaken(slot), isFalse);

      await provider.add(_appointmentAt(slot));
      expect(provider.isSlotTaken(slot), isTrue);
      expect(provider.isSlotTaken(DateTime(2026, 8, 14, 18)), isFalse);
    });

    test('remove() deletes from memory and storage', () async {
      final provider = AppointmentProvider();
      await provider.load();
      await provider.add(_appointmentAt(DateTime(2026, 8, 14, 16), id: 'x'));

      await provider.remove('x');

      expect(provider.appointments, isEmpty);
      expect(await StorageService().loadAppointments(), isEmpty);
    });

    test('nextAppointment ignores anything already finished', () async {
      final provider = AppointmentProvider();
      await provider.load();

      final past = DateTime.now().subtract(const Duration(days: 3));
      final future = DateTime.now().add(const Duration(days: 3));
      await provider.add(_appointmentAt(past, id: 'past'));
      await provider.add(_appointmentAt(future, id: 'future'));

      expect(provider.nextAppointment?.id, 'future');
      expect(provider.past.map((a) => a.id), ['past']);
    });
  });

  group('Formatting', () {
    testWidgets('renders English date shapes', (tester) async {
      final fmt = await _fmtFor(tester, const Locale('en'));
      final start = DateTime(2026, 8, 14, 16);

      expect(fmt.fullDate(start), 'Friday, 14 August 2026');
      expect(fmt.monthYear(start), 'August 2026');
      expect(fmt.durationLabel(), '2 hours');
      expect(fmt.weekdayLabels().first, 'Mon');
    });

    testWidgets('renders Turkish date shapes', (tester) async {
      final fmt = await _fmtFor(tester, const Locale('tr'));
      final start = DateTime(2026, 8, 14, 16);

      // Turkish convention puts the weekday last.
      expect(fmt.fullDate(start), '14 Ağustos 2026 Cuma');
      expect(fmt.monthYear(start), 'Ağustos 2026');
      expect(fmt.durationLabel(), '2 saat');
      expect(fmt.weekdayLabels().first, 'Pzt');
    });

    test('times are 24-hour in every language', () {
      final start = DateTime(2026, 8, 14, 16);

      expect(Fmt.time(start), '16:00');
      expect(Fmt.hour(9), '09:00');
      expect(Fmt.timeRange(start), '16:00 – 18:00');
    });

    test('isSameDay ignores the time component', () {
      expect(
        isSameDay(DateTime(2026, 8, 14, 1), DateTime(2026, 8, 14, 23)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 8, 14), DateTime(2026, 8, 15)), isFalse);
      expect(isSameDay(null, DateTime(2026, 8, 14)), isFalse);
    });
  });

  group('Phone number', () {
    String mask(String input) => TurkishPhoneInputFormatter.format(
          TurkishPhoneInputFormatter.extractDigits(input),
        );

    test('masks a full number as (555) 555 55 55', () {
      expect(mask('5551234567'), '(555) 123 45 67');
    });

    test('builds up the mask as digits arrive', () {
      expect(mask(''), '');
      expect(mask('5'), '(5');
      expect(mask('555'), '(555)');
      expect(mask('5551'), '(555) 1');
      expect(mask('555123'), '(555) 123');
      expect(mask('5551234'), '(555) 123 4');
      expect(mask('55512345'), '(555) 123 45');
      expect(mask('555123456'), '(555) 123 45 6');
    });

    test('strips country and trunk prefixes', () {
      const expected = '(555) 123 45 67';

      expect(mask('05551234567'), expected);
      expect(mask('+90 555 123 45 67'), expected);
      expect(mask('905551234567'), expected);
      expect(mask('00905551234567'), expected);
      expect(mask('(555) 123 45 67'), expected);
    });

    test('ignores letters and stray punctuation', () {
      expect(mask('555-123-45-67'), '(555) 123 45 67');
      expect(mask('555abc1234567xyz'), '(555) 123 45 67');
    });

    test('never exceeds ten digits', () {
      expect(mask('55512345679999'), '(555) 123 45 67');
    });

    test('isComplete only accepts a full ten-digit number', () {
      expect(TurkishPhoneInputFormatter.isComplete('(555) 123 45 67'), isTrue);
      expect(TurkishPhoneInputFormatter.isComplete('+905551234567'), isTrue);
      expect(TurkishPhoneInputFormatter.isComplete('(555) 123 45'), isFalse);
      expect(TurkishPhoneInputFormatter.isComplete(''), isFalse);
    });

    test('formatter rewrites the field and keeps the caret after the digit',
        () {
      const formatter = TurkishPhoneInputFormatter();

      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '(555) 12'),
        const TextEditingValue(
          text: '(555) 123',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );

      expect(result.text, '(555) 123');
      expect(result.selection.baseOffset, 9);
    });

    test('typing the third digit skips past the inserted bracket', () {
      const formatter = TurkishPhoneInputFormatter();

      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '(55'),
        const TextEditingValue(
          text: '(555',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      // The caret lands after ")" so the next keystroke starts the next group.
      expect(result.text, '(555)');
      expect(result.selection.baseOffset, 5);
    });

    test('display formatting re-masks legacy stored numbers', () {
      expect(Fmt.phone('+90 555 123 45 67'), '(555) 123 45 67');
      // Anything unparseable is shown as-is rather than mangled.
      expect(Fmt.phone('123'), '123');
    });
  });

  group('StorageService', () {
    test('returns an empty list when nothing has been stored', () async {
      expect(await StorageService().loadAppointments(), isEmpty);
    });

    test('recovers from corrupted stored data instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'minerva.appointments.v1': 'not json at all',
      });

      expect(await StorageService().loadAppointments(), isEmpty);
    });
  });

  group('LocaleProvider', () {
    test('falls back to Turkish for a language we do not ship', () {
      const supported = LocaleProvider.supportedLocales;

      expect(LocaleProvider.resolve(const Locale('de'), supported),
          const Locale('tr'));
      expect(LocaleProvider.resolve(null, supported), const Locale('tr'));
    });

    test('matches on language code, ignoring the country', () {
      const supported = LocaleProvider.supportedLocales;

      expect(LocaleProvider.resolve(const Locale('en', 'GB'), supported),
          const Locale('en'));
      expect(LocaleProvider.resolve(const Locale('tr', 'TR'), supported),
          const Locale('tr'));
    });

    test('remembers the chosen language across launches', () async {
      final provider = LocaleProvider();
      await provider.load();
      expect(provider.locale, isNull, reason: 'defaults to following device');

      await provider.setLocale(const Locale('en'));

      final reloaded = LocaleProvider();
      await reloaded.load();
      expect(reloaded.locale, const Locale('en'));
    });

    test('clearing the choice goes back to following the device', () async {
      final provider = LocaleProvider();
      await provider.load();
      await provider.setLocale(const Locale('en'));

      await provider.setLocale(null);

      final reloaded = LocaleProvider();
      await reloaded.load();
      expect(reloaded.locale, isNull);
    });
  });

  group('Widgets', () {
    testWidgets('the phone field masks digits as they are typed',
        (tester) async {
      await tester.pumpWidget(
        _wrapBookingScreen(const DetailsScreen(), const Locale('tr')),
      );
      await tester.pumpAndSettle();

      final phoneField = find.widgetWithText(TextFormField, '(555) 555 55 55');
      await tester.enterText(phoneField, '5551234567');
      await tester.pumpAndSettle();

      expect(find.text('(555) 123 45 67'), findsOneWidget);
    });

    testWidgets('a pasted +90 number is reduced to the plain mask',
        (tester) async {
      await tester.pumpWidget(
        _wrapBookingScreen(const DetailsScreen(), const Locale('tr')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '(555) 555 55 55'),
        '+90 555 123 45 67',
      );
      await tester.pumpAndSettle();

      expect(find.text('(555) 123 45 67'), findsOneWidget);
    });

    testWidgets('an incomplete phone number blocks the step', (tester) async {
      await tester.pumpWidget(
        _wrapBookingScreen(const DetailsScreen(), const Locale('tr')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '(555) 555 55 55'),
        '55512',
      );
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();

      expect(find.text('Numarayı (555) 555 55 55 biçiminde girin.'),
          findsOneWidget);
      // Still on the details step.
      expect(find.text('Bilgileriniz'), findsWidgets);
    });

    testWidgets('switching language on Profile re-renders the app',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MinervaApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başlayalım'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Dil'), findsOneWidget);

      await tester.tap(find.text('İngilizce'));
      await tester.pumpAndSettle();

      // The whole shell is now English, navigation bar included.
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Salon'), findsOneWidget);
    });

    testWidgets('the splash screen leads into the app, in Turkish',
        (tester) async {
      // The test harness reports en_US by default, so ask for Turkish
      // explicitly rather than relying on the fallback.
      tester.platformDispatcher.localesTestValue = const [Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MinervaApp());
      await tester.pumpAndSettle();

      expect(find.text('MINERVA'), findsOneWidget);
      expect(find.text('Güzel tırnaklar,\nmükemmel zaman.'), findsOneWidget);

      await tester.tap(find.text('Başlayalım'));
      await tester.pumpAndSettle();

      expect(find.text('Yeni Randevu'), findsOneWidget);
      expect(find.text('Sonraki Randevum'), findsOneWidget);
    });

    testWidgets('an unsupported device language falls back to Turkish',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MinervaApp());
      await tester.pumpAndSettle();

      expect(find.text('Başlayalım'), findsOneWidget);
    });

    testWidgets('an English device gets English', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MinervaApp());
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('"Select Time" stays disabled until a day is picked',
        (tester) async {
      // The default 800x600 test surface pushes the calendar's footer off
      // screen; use a phone-shaped viewport so the layout matches the target.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final booking = BookingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: booking),
            ChangeNotifierProvider(create: (_) => AppointmentProvider()..load()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick a day above'), findsOneWidget);

      // The gradient button renders its disabled state as a faded overlay.
      Opacity buttonOpacity() => tester.widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Select Time'),
                  matching: find.byType(Opacity),
                )
                .last,
          );
      expect(buttonOpacity().opacity, lessThan(1));

      // Selecting a day enables it.
      booking.selectDate(DateTime.now());
      await tester.pumpAndSettle();

      expect(buttonOpacity().opacity, 1);
    });
  });
}

/// Builds a throwaway appointment at [start] for storage/provider tests.
Appointment _appointmentAt(DateTime start, {String id = 'test'}) {
  return Appointment(
    id: id,
    start: start,
    firstName: 'Test',
    lastName: 'Customer',
    phone: '05551234567',
  );
}
