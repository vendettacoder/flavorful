import 'dart:async';

/// An authenticated session. [token] is the credential sent on every backend
/// request via the custom `auth-header: Bearer <token>` header.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.email,
    required this.userInitial,
    this.firstName = '',
    this.avatarUrl,
    this.provider,
  });

  final String token;
  final String email;

  /// Single uppercase letter shown in the avatar circle.
  final String userInitial;

  /// User's first name (from the OAuth profile), empty if unknown.
  final String firstName;

  /// Profile picture URL from the OAuth provider (Google), or null when the
  /// provider gives none (e.g. Sign in with Apple) — UI falls back to the
  /// initial.
  final String? avatarUrl;

  /// Sign-in provider id ('google', 'apple', 'email'), or null if unknown.
  final String? provider;
}

/// Contract for authentication. The live implementation performs Google SSO via
/// Supabase (see SupabaseAuthRepository); the mock returns a canned session so
/// the app runs without a backend.
abstract class AuthRepository {
  /// Session restored from a previous launch, or null if signed out.
  Future<AuthSession?> currentSession();

  /// Emits whenever the session changes (sign-in completes, sign-out, refresh).
  Stream<AuthSession?> authStateChanges();

  /// Start the Google sign-in flow. The resulting session arrives via
  /// [authStateChanges] (OAuth bounces through the browser), not as a return
  /// value.
  Future<void> signInWithGoogle();

  /// Start the Sign in with Apple flow. Required by App Store Review Guideline
  /// 4.8 because the app also offers a third-party login (Google). The session
  /// arrives via [authStateChanges], same as Google.
  Future<void> signInWithApple();

  Future<void> signOut();
}

/// In-memory auth for offline/mock mode and tests.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  @override
  Future<AuthSession?> currentSession() async => _session;

  @override
  Stream<AuthSession?> authStateChanges() => _controller.stream;

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _session = const AuthSession(
      token: 'mock-session-token',
      email: 'maya@example.com',
      userInitial: 'M',
      firstName: 'Maya',
    );
    _controller.add(_session);
  }

  @override
  Future<void> signInWithApple() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _session = const AuthSession(
      token: 'mock-session-token',
      email: 'maya@example.com',
      userInitial: 'M',
      firstName: 'Maya',
    );
    _controller.add(_session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(null);
  }
}
