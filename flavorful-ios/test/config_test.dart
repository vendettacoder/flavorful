import 'package:flavorful/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API override works in development and production', () {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      expect(AppConfig.apiBaseUrl, override);
    } else if (AppConfig.isProd) {
      expect(AppConfig.apiBaseUrl, 'https://flavorful.fly.dev');
    } else {
      expect(
        AppConfig.apiBaseUrl,
        kIsWeb ? 'http://127.0.0.1:8001' : 'http://localhost:8000',
      );
    }
  });

  test('mock mode requires the explicit build flag', () {
    expect(AppConfig.useMockData, const bool.fromEnvironment('FLAVORFUL_MOCK'));
  });

  test('native callback stays unchanged; web callback uses current origin', () {
    expect(
      AppConfig.authRedirectUrl,
      kIsWeb
          ? '${Uri.base.origin}/auth/callback'
          : 'flavorful://login-callback',
    );
  });
}
