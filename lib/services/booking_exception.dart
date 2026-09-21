/// Failures the booking flow knows how to explain to the customer.
///
/// Anything not in this list is a genuine bug or outage and is surfaced as a
/// generic error, rather than being guessed at.
sealed class BookingException implements Exception {
  const BookingException();
}

/// Somebody else's booking reached the database first.
///
/// Raised when the insert violates `appointments_one_confirmed_per_slot`
/// (SQLSTATE 23505). This is the expected, healthy outcome of two people
/// confirming the same slot at the same moment — one of them has to lose, and
/// the loser gets sent back to pick another time.
class SlotTakenException extends BookingException {
  const SlotTakenException();
}

/// The slot has already started, according to the server clock.
class SlotInThePastException extends BookingException {
  const SlotInThePastException();
}

/// The customer already has an appointment within three weeks of this one.
///
/// The salon takes each customer roughly once every 21 days. Enforced by the
/// database (`MN002`), because a rule only kept in the app is not a rule.
///
/// [nextAvailable] is the earliest day that would be accepted, when the
/// database was able to say.
class BookingWindowException extends BookingException {
  const BookingWindowException({this.existingDate, this.nextAvailable});

  /// The appointment that stands in the way.
  final DateTime? existingDate;

  /// The first day that would be free of it.
  final DateTime? nextAvailable;
}

/// The salon is shut that day — a Sunday, or a declared holiday.
class SalonClosedException extends BookingException {
  const SalonClosedException();
}

/// Too late to call it off.
///
/// A customer may cancel until an hour before the appointment starts. After
/// that the slot is theirs, and only the salon can release it.
class CancelTooLateException extends BookingException {
  const CancelTooLateException();
}

/// The name given does not match the one held against that phone number.
///
/// Raised when somebody claims a customer record. It is the only thing
/// standing between a phone number and the record behind it, so the app must
/// not soften it into a generic failure — but it must also not confirm that a
/// record exists.
class NameDoesNotMatchException extends BookingException {
  const NameDoesNotMatchException();
}

/// No usable connection to Supabase.
class BookingOfflineException extends BookingException {
  const BookingOfflineException();
}

/// The app was built without Supabase credentials.
class BookingNotConfiguredException extends BookingException {
  const BookingNotConfiguredException();
}

/// The Supabase project has anonymous sign-ins switched off.
///
/// A setup mistake rather than a runtime failure, and a common one — the
/// setting is off by default. Kept separate so the app can say exactly which
/// switch to flip instead of showing a generic error.
class AnonymousSignInDisabledException extends BookingException {
  const AnonymousSignInDisabledException();
}

/// Admin sign-in was rejected: wrong email or password.
///
/// Kept distinct from a generic failure so the login screen can say "check
/// your credentials" rather than "something went wrong".
class InvalidAdminCredentialsException extends BookingException {
  const InvalidAdminCredentialsException();
}

/// The sign-in succeeded, but the account is not a staff member.
///
/// Authenticating is not the same as being authorized: a valid Supabase user
/// who is not in the `admins` table is signed straight back out and refused.
class NotAnAdminException extends BookingException {
  const NotAnAdminException();
}

/// Anything else: an outage, a schema mismatch, a bug.
class BookingFailedException extends BookingException {
  const BookingFailedException(this.detail);

  final String detail;

  @override
  String toString() => 'BookingFailedException: $detail';
}
