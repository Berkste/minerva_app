import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/main.dart';
import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/providers/booking_provider.dart';
import 'package:minerva_app/screens/booking/calendar_screen.dart';
import 'package:minerva_app/services/storage_service.dart';
import 'package:minerva_app/utils/formatting.dart';

void main() {
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
    test('renders the date and time shapes used across the app', () {
      final start = DateTime(2026, 8, 14, 16);

      expect(Fmt.fullDate(start), 'Friday, 14 August 2026');
      expect(Fmt.monthYear(start), 'August 2026');
      expect(Fmt.time(start), '16:00');
      expect(Fmt.hour(9), '09:00');
      expect(Fmt.timeRange(start), '16:00 – 18:00');
      expect(Fmt.durationLabel(), '2 hours');
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

  group('Widgets', () {
    testWidgets('the splash screen leads into the app', (tester) async {
      await tester.pumpWidget(const MinervaApp());
      await tester.pumpAndSettle();

      expect(find.text('MINERVA'), findsOneWidget);
      expect(find.text('Beautiful nails,\nperfect time.'), findsOneWidget);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('New Appointment'), findsOneWidget);
      expect(find.text('My Next Appointment'), findsOneWidget);
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
          child: const MaterialApp(home: CalendarScreen()),
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
