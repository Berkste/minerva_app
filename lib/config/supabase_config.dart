/// Supabase connection details, supplied at build time.
///
/// These are read with `String.fromEnvironment`, so they are passed on the
/// command line rather than committed:
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJhbG...
/// ```
///
/// The anon key is a publishable key — it is safe in a shipped app *because*
/// row level security decides what it can reach. The service-role key is not,
/// and must never appear in this project.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabase renamed this key: the dashboard used to call it the "anon" key
  /// and now calls it the "publishable" key. Both names are accepted so the
  /// build command matches whichever label the dashboard is showing.
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get publishableKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// False when the app was built without credentials; the UI shows a setup
  /// screen instead of failing at the first query.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
