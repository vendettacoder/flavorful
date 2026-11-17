import 'package:flutter/foundation.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import '../routing.dart';
import '../widgets/app_action.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../util/launch.dart';
import '../widgets/app_icons.dart';
import '../widgets/wordmark.dart';

/// First-run / signed-out screen. Green hero panel over a beige sign-in sheet
/// with Google on web and Apple plus Google on native.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isSigningIn = _busy || ref.watch(authControllerProvider).isLoading;
    final width = MediaQuery.sizeOf(context).width;
    final insetPanel = kIsWeb || width >= 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar over green
      child: Scaffold(
        backgroundColor: AppColors.brandGreen,
        body: SafeArea(
          child: Padding(
            padding: insetPanel
                ? EdgeInsets.all(width < 600 ? 16 : 24)
                : EdgeInsets.zero,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  60,
                                  28,
                                  36,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Wordmark(
                                      size: WordmarkSize.lg,
                                      onDark: true,
                                    ),
                                    const SizedBox(height: 60),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Just the recipe.',
                                          style: AppText.hero(),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Every time.',
                                          style: AppText.hero(
                                            color: AppColors.accentOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Build your personal cookbook from recipes on the '
                                      'internet.',
                                      style: AppText.heroParagraph(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _SignInSheet(
                              inset: insetPanel,
                              isSigningIn: isSigningIn,
                              onGoogleSignIn: () => _runSignIn(
                                context,
                                () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle(),
                              ),
                              onAppleSignIn: () => _runSignIn(
                                context,
                                () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithApple(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Runs a sign-in action, surfacing failures as a snackbar instead of failing
  /// silently. User-initiated cancellation (backing out of the Apple sheet) is
  /// ignored.
  Future<void> _runSignIn(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final destination = signInDestination(
      GoRouterState.of(context).uri.queryParameters['from'],
    );
    try {
      if (kIsWeb && !AppConfig.useMockData) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(signInDestinationKey, destination);
      }
      await action();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Apple sign-in didn't complete. Please try again."),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Sign-in didn't complete. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SignInSheet extends StatelessWidget {
  const _SignInSheet({
    required this.inset,
    required this.isSigningIn,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
  });

  final bool inset;
  final bool isSigningIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('sign-in-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgBeige,
        borderRadius: inset
            ? BorderRadius.circular(AppRadii.sheet)
            : const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get started', style: AppText.signInTitle()),
          const SizedBox(height: 28),
          // Sign in with Apple first — App Store Review Guideline 4.8 requires
          // it to be offered at least as prominently as other social logins.
          if (!kIsWeb) ...[
            _AppleButton(isLoading: isSigningIn, onTap: onAppleSignIn),
            const SizedBox(height: 14),
          ],
          _GoogleButton(isLoading: isSigningIn, onTap: onGoogleSignIn),
          const SizedBox(height: 18),
          const _ConsentFooter(),
        ],
      ),
    );
  }
}

/// Pre-account-creation consent line with a tappable Privacy Policy link.
/// Apple expects the policy to be reachable before sign-up, not only after.
class _ConsentFooter extends StatelessWidget {
  const _ConsentFooter();

  @override
  Widget build(BuildContext context) {
    final base = AppText.cardDescription().copyWith(fontSize: 12, height: 1.4);
    return Column(
      children: [
        Text(
          'By continuing you agree to our Privacy Policy. '
          'Recipe pages you save are sent to an AI service '
          '(OpenRouter) to read the recipe details.',
          style: base,
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => openExternalUrl(AppConfig.privacyPolicyUrl),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppAction(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apple, size: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Continue with Apple',
                      style: AppText.body().copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppAction(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandGreen,
          borderRadius: BorderRadius.circular(AppRadii.button),
          boxShadow: AppShadows.googleButton,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.onGreen),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.googleG(size: 18),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Continue with Google',
                      style: AppText.body().copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onGreen,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
