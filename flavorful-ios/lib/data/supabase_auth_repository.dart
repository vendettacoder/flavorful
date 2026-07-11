import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'auth_repository.dart';

/// Live authentication via Supabase Google OAuth. The resulting access token is
/// what the backend expects in `auth-header: Bearer <token>`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository() {
    // Restore the provider tapped in a previous launch before any session is
    // mapped, so a cold-start restore doesn't have to guess.
    _restore = _restoreProvider();
  }

  SupabaseClient get _client => Supabase.instance.client;

  static const _providerKey = 'flavorful.last_provider';

  /// The provider the user tapped. Google + Apple linked to one email become a
  /// single Supabase user, so server-side metadata can't tell the two apart —
  /// the button press is the reliable signal. Persisted across launches so a
  /// restored session (cold start) keeps the correct provider instead of
  /// guessing from server hints (which mislabels linked accounts).
  String? _lastProvider;

  /// Completes once the persisted provider has been read at startup.
  Future<void>? _restore;

  Future<void> _restoreProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastProvider ??= prefs.getString(_providerKey);
    } catch (_) {
      // Best-effort; fall back to server hints if storage is unavailable.
    }
  }

  Future<void> _persistProvider(String? provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (provider == null) {
        await prefs.remove(_providerKey);
      } else {
        await prefs.setString(_providerKey, provider);
      }
    } catch (_) {
      // Non-fatal — the in-memory value still drives the current session.
    }
  }

  AuthSession? _map(Session? session) {
    if (session == null) return null;
    final email = session.user.email ?? '';
    final provider = _provider(session.user);
    // The Google `picture` persists in metadata even after linking Apple, so
    // only show it when the active provider is Google. Apple gives no photo →
    // the avatar falls back to the initial.
    final avatarUrl =
        provider == 'google' ? _avatarUrl(session.user.userMetadata) : null;
    return AuthSession(
      token: session.accessToken,
      email: email,
      userInitial: email.isNotEmpty ? email[0].toUpperCase() : '?',
      firstName: _firstName(session.user.userMetadata, email),
      avatarUrl: avatarUrl,
      provider: provider,
    );
  }

  /// The provider for this session: the button the user tapped, else (cold
  /// start) a best-effort server hint — the most recently used identity, then
  /// `appMetadata['provider']`.
  String? _provider(User user) {
    if (_lastProvider != null) return _lastProvider;
    String? best;
    String? bestAt;
    for (final id in user.identities ?? const []) {
      final at = id.lastSignInAt; // ISO8601 string, sorts lexicographically
      if (best == null || (at != null && (bestAt == null || at.compareTo(bestAt) > 0))) {
        best = id.provider;
        bestAt = at;
      }
    }
    return best ?? user.appMetadata['provider'] as String?;
  }

  /// Pulls a first name from the Google OAuth profile metadata, falling back to
  /// the full name's first token. Empty if nothing usable (UI shows "Welcome").
  String _firstName(Map<String, dynamic>? meta, String email) {
    String pick(dynamic v) => v is String ? v.trim() : '';
    final given = pick(meta?['given_name']).isNotEmpty
        ? pick(meta?['given_name'])
        : pick(meta?['first_name']);
    if (given.isNotEmpty) return given;
    final full = pick(meta?['full_name']).isNotEmpty
        ? pick(meta?['full_name'])
        : pick(meta?['name']);
    if (full.isNotEmpty) return full.split(RegExp(r'\s+')).first;
    return '';
  }

  /// Profile picture URL from the OAuth profile metadata. Google uses
  /// `picture`; some providers use `avatar_url`. Null if neither is present.
  String? _avatarUrl(Map<String, dynamic>? meta) {
    String pick(dynamic v) => v is String ? v.trim() : '';
    final url = pick(meta?['picture']).isNotEmpty
        ? pick(meta?['picture'])
        : pick(meta?['avatar_url']);
    return url.isNotEmpty ? url : null;
  }

  @override
  Future<AuthSession?> currentSession() async {
    await _restore; // ensure the persisted provider is loaded first
    return _map(_client.auth.currentSession);
  }

  @override
  Stream<AuthSession?> authStateChanges() =>
      _client.auth.onAuthStateChange.map((data) => _map(data.session));

  @override
  Future<void> signInWithGoogle() async {
    _lastProvider = 'google';
    await _persistProvider('google');
    // Opens the system browser; the session returns via the deep link
    // configured in AppConfig.authRedirectUrl and surfaces on authStateChanges.
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signInWithApple() async {
    _lastProvider = 'apple';
    await _persistProvider('apple');
    // Native Sign in with Apple: request the Apple ID credential with a hashed
    // nonce, then exchange the returned identity token with Supabase. The raw
    // nonce is sent to Supabase so it can verify the token's `nonce` claim.
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Apple sign-in failed: no identity token returned.',
      );
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  @override
  Future<void> signOut() async {
    _lastProvider = null;
    await _persistProvider(null);
    await _client.auth.signOut();
  }

  /// Cryptographically-random nonce for the Apple sign-in request.
  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
