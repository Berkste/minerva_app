import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:minerva_app/services/booking_exception.dart';
import 'package:minerva_app/services/supabase_booking_repository.dart';

/// The seam between Postgres error codes and the sentence the customer reads.
///
/// This is the one piece of the Supabase repository that holds a decision
/// rather than a query, and the codes it matches on live in
/// `supabase/migrations/`, not in Dart — so nothing in the app fails loudly if
/// the two drift apart. These tests are that alarm.
void main() {
  BookingException? translate(Object error) =>
      SupabaseBookingRepository.translateError(error);

  PostgrestException postgres(String code, [String message = 'boom']) =>
      PostgrestException(code: code, message: message);

  group('Postgres codes', () {
    test('23505 means somebody else took the slot first', () {
      // The partial unique index appointments_one_confirmed_per_slot. Losing
      // this race is a normal outcome, not a failure.
      expect(translate(postgres('23505')), isA<SlotTakenException>());
    });

    test('MN001 means the slot has already started', () {
      // Raised only by the appointments_reject_past trigger.
      expect(translate(postgres('MN001')), isA<SlotInThePastException>());
    });

    test('23514 is NOT reported as a slot in the past', () {
      // The regression this mapping used to have. Every column CHECK on
      // appointments raises 23514 — phone shape, name length, slot_hour,
      // service_id — so treating it as the past-slot trigger told the customer
      // "that time has already passed" when their phone number was malformed.
      // The trigger owns MN001 now precisely so these stay separable.
      for (final message in const [
        'new row violates check constraint "appointments_phone_check"',
        'new row violates check constraint "appointments_first_name_check"',
        'new row violates check constraint "appointments_slot_hour_check"',
        'new row violates check constraint "appointments_service_id_check"',
      ]) {
        final result = translate(postgres('23514', message));

        expect(result, isNot(isA<SlotInThePastException>()));
        expect(result, isA<BookingFailedException>());
        // The constraint name has to survive: it is the only clue to which
        // client-side validation let the bad value through.
        expect((result as BookingFailedException).detail, contains(message));
      }
    });

    test('MN002 means the 21-day window, and carries the dates', () {
      // "You cannot book yet" is true but useless on its own; the trigger
      // names the clashing day so the app can say when they can.
      final result = translate(postgres(
        'MN002',
        'Only one appointment per 21 days; this customer already has one on 2026-10-03',
      ));

      expect(result, isA<BookingWindowException>());
      final window = result as BookingWindowException;
      expect(window.existingDate, DateTime(2026, 10, 3));
      expect(window.nextAvailable, DateTime(2026, 10, 24));
    });

    test('…and still explains itself when the message has no date', () {
      // Parsing a message is a best effort. Losing the detail must not cost
      // the customer the explanation.
      final result = translate(postgres('MN002', 'too soon'));

      expect(result, isA<BookingWindowException>());
      expect((result as BookingWindowException).nextAvailable, isNull);
    });

    test('MN003 means the salon is shut that day', () {
      expect(
        translate(postgres('MN003', 'The salon is closed on Sundays')),
        isA<SalonClosedException>(),
      );
    });

    test('MN004 means it is too late to cancel', () {
      expect(translate(postgres('MN004')), isA<CancelTooLateException>());
    });

    test('MN005 means the name does not match the number', () {
      expect(translate(postgres('MN005')), isA<NameDoesNotMatchException>());
    });

    test('MN006 stays generic — it is a client bug, not a rule', () {
      // Asking for a treatment that does not exist is the app's mistake. It
      // must not be dressed up as something the customer did wrong.
      final result = translate(postgres('MN006', 'No such treatment: nope'));

      expect(result, isA<BookingFailedException>());
      expect(result, isNot(isA<SalonClosedException>()));
    });

    test('every rule maps to a different outcome', () {
      // The codes exist to be told apart. If two ever collapsed onto the same
      // exception, the customer would be given the wrong reason — which is
      // exactly the bug that made MN001 necessary in the first place.
      final outcomes = <String>{
        for (final code in ['23505', 'MN001', 'MN002', 'MN003', 'MN004', 'MN005'])
          translate(postgres(code)).runtimeType.toString(),
      };

      expect(outcomes.length, 6);
    });

    test('an unrecognised code keeps its code and message', () {
      final result = translate(postgres('42501', 'permission denied'));

      expect(result, isA<BookingFailedException>());
      expect((result as BookingFailedException).detail, contains('42501'));
      expect(result.detail, contains('permission denied'));
    });
  });

  group('Auth failures', () {
    test('the anonymous provider being off is named precisely', () {
      // Off by default in a new Supabase project, so this is the single most
      // likely first-run failure — worth its own screen rather than a shrug.
      expect(
        translate(
          const AuthException('...', code: 'anonymous_provider_disabled'),
        ),
        isA<AnonymousSignInDisabledException>(),
      );
    });

    test('…and is still recognised when only the message says so', () {
      // Older gotrue responses carry no code for this one.
      expect(
        translate(const AuthException('Anonymous sign-ins are disabled')),
        isA<AnonymousSignInDisabledException>(),
      );
    });

    test('any other auth failure stays generic', () {
      expect(
        translate(const AuthException('Invalid refresh token')),
        isA<BookingFailedException>(),
      );
    });
  });

  group('Transport failures', () {
    test('a dead socket is offline, not a bug', () {
      expect(
        translate(const SocketException('failed host lookup')),
        isA<BookingOfflineException>(),
      );
    });

    test('a timeout is offline too', () {
      expect(translate(TimeoutException('slow')), isA<BookingOfflineException>());
    });
  });

  test('anything else is left alone for the caller to rethrow', () {
    // Guessing at an unknown error would bury a real bug behind a polite
    // message. Null is the signal to let it propagate.
    expect(translate(const FormatException('not a backend failure')), isNull);
    expect(translate(StateError('bug')), isNull);
  });
}
