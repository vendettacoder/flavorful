import 'package:flutter/foundation.dart';

/// Public build settings. Live services remain the default.
class AppConfig {
  AppConfig._();

  static const bool useMockData = bool.fromEnvironment('FLAVORFUL_MOCK');
  static const String _env = String.fromEnvironment(
    'FLAVORFUL_ENV',
    defaultValue: 'dev',
  );
  static bool get isProd => _env == 'prod';
  static const String _apiOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    if (isProd) return 'https://flavorful.fly.dev';
    return kIsWeb ? 'http://127.0.0.1:8001' : 'http://localhost:8000';
  }

  // Public client key, not a server or admin key.
  static const String supabaseUrl = 'https://olqukyolwuzsncoreute.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_73FSCqqnVSSZaDqmBG-zmA_eD2R1A60';

  static String get authRedirectUrl => kIsWeb
      ? '${Uri.base.origin}/auth/callback'
      : 'flavorful://login-callback';

  static const String privacyPolicyUrl =
      'https://vendettacoder.github.io/flavorful-privacy/';
  static const String supportEmail = 'rohancoolkarni93@gmail.com';
}
