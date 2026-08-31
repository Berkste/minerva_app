import '../l10n/app_localizations.dart';
import '../services/booking_exception.dart';

/// Turns a [BookingException] into something worth showing a customer.
///
/// One place for the mapping so every screen explains the same failure the
/// same way — and so "someone beat you to it" never reads like a crash.
String messageFor(AppLocalizations l10n, BookingException failure) {
  return switch (failure) {
    SlotTakenException() => l10n.slotJustTaken,
    SlotInThePastException() => l10n.slotInThePast,
    BookingOfflineException() => l10n.connectionProblem,
    BookingNotConfiguredException() => l10n.setupRequiredMessage,
    AnonymousSignInDisabledException() => l10n.anonymousSignInDisabled,
    InvalidAdminCredentialsException() => l10n.adminInvalidCredentials,
    NotAnAdminException() => l10n.adminNotAuthorized,
    BookingFailedException() => l10n.somethingWentWrong,
  };
}
