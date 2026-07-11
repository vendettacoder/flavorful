/// App-wide configuration knobs.
///
/// [useMockData] swaps the entire data + auth layer between an in-memory mock
/// (offline, sample data) and the live backend (Supabase auth + FastAPI). See
/// `lib/providers/providers.dart`.
class AppConfig {
  AppConfig._();

  /// When true, the app serves sample data from `MockRecipeRepository` and
  /// `MockAuthRepository`. When false, it uses Supabase auth + the FastAPI
  /// backend at [apiBaseUrl].
  static const bool useMockData = false;

  /// Build-time environment switch. Defaults to `dev`; release builds must pass
  /// `--dart-define=FLAVORFUL_ENV=prod` (and ship over HTTPS).
  static const String _env =
      String.fromEnvironment('FLAVORFUL_ENV', defaultValue: 'dev');

  /// True for App Store / production builds.
  static bool get isProd => _env == 'prod';

  /// Dev backend. On the iOS simulator, `localhost` reaches the host machine,
  /// so the locally-running server is at port 8000.
  static const String _devApiBaseUrl = 'http://localhost:8000';

  /// Production backend. MUST be a public HTTPS host before App Store
  /// submission — `localhost` is unreachable on a reviewer's real device
  /// (App Store Review Guideline 2.1). The default can be overridden at build
  /// time with `--dart-define=API_BASE_URL=https://…`.
  static const String _prodApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://flavorful.fly.dev',
  );

  /// Base URL of the recipe backend, chosen by [isProd].
  static String get apiBaseUrl => isProd ? _prodApiBaseUrl : _devApiBaseUrl;

  /// Supabase project (client-safe publishable key — same values the web
  /// frontend uses in index.html).
  static const String supabaseUrl = 'https://olqukyolwuzsncoreute.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_73FSCqqnVSSZaDqmBG-zmA_eD2R1A60';

  /// OAuth redirect deep link. Must be registered as a CFBundleURLScheme in
  /// ios/Runner/Info.plist AND added to the Supabase Auth redirect allowlist.
  static const String authRedirectUrl = 'flavorful://login-callback';

  /// Public privacy policy. Required by App Store Review Guideline 5.1.1 — the
  /// same URL must also be entered in App Store Connect. Hosted on GitHub Pages
  /// from the flavorful-privacy repo (source: PRIVACY_POLICY.md).
  static const String privacyPolicyUrl =
      'https://vendettacoder.github.io/flavorful-privacy/';

  /// Support contact shown in-app and used as the App Store support URL/email.
  static const String supportEmail = 'rohancoolkarni93@gmail.com';
}
