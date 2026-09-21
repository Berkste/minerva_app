import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/booking_exception.dart';

/// Turns a [BookingException] into something worth showing a customer.
///
/// One place for the mapping so every screen explains the same failure the
/// same way — and so "someone beat you to it" never reads like a crash.
///
/// [localeName] is only needed to spell a date inside one of the messages; it
/// defaults to Turkish, the salon's own language.
String messageFor(
  AppLocalizations l10n,
  BookingException failure, {
  String localeName = 'tr',
}) {
  return switch (failure) {
    SlotTakenException() => l10n.slotJustTaken,
    SlotInThePastException() => l10n.slotInThePast,
    BookingWindowException() => _bookingWindow(l10n, failure, localeName),
    SalonClosedException() => l10n.salonClosedThatDay,
    CancelTooLateException() => l10n.cancelTooLate,
    NameDoesNotMatchException() => l10n.nameDoesNotMatch,
    BookingOfflineException() => l10n.connectionProblem,
    BookingNotConfiguredException() => l10n.setupRequiredMessage,
    AnonymousSignInDisabledException() => l10n.anonymousSignInDisabled,
    InvalidAdminCredentialsException() => l10n.adminInvalidCredentials,
    NotAnAdminException() => l10n.adminNotAuthorized,
    BookingFailedException() => l10n.somethingWentWrong,
  };
}

/// "You can book once every three weeks" is true but unhelpful on its own —
/// the useful half is *when*. The database names the clashing date when it
/// can, so say it; fall back to the plain sentence when it could not.
String _bookingWindow(
  AppLocalizations l10n,
  BookingWindowException failure,
  String localeName,
) {
  final next = failure.nextAvailable;
  if (next == null) return l10n.bookingWindow;

  return l10n.bookingWindowUntil(
    DateFormat(l10n.dateShortPattern, localeName).format(next),
  );
}
