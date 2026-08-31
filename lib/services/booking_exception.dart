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
