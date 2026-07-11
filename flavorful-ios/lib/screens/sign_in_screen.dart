import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../util/launch.dart';
import '../widgets/app_icons.dart';
import '../widgets/wordmark.dart';

/// First-run / signed-out screen. Green hero panel over a beige sign-in sheet
/// with a single Continue-with-Google button.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSigningIn = ref.watch(authControllerProvider).isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar over green
      child: Scaffold(
        backgroundColor: AppColors.brandGreen,
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 80, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wordmark(size: WordmarkSize.lg, onDark: true),
                    const SizedBox(height: 60),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Just the recipe.', style: AppText.hero()),
                        const SizedBox(height: 4),
                        Text('Every time.',
                            style: AppText.hero(color: AppColors.accentOrange)),
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
    );
  }

  /// Runs a sign-in action, surfacing failures as a snackbar instead of failing
  /// silently. User-initiated cancellation (backing out of the Apple sheet) is
  /// ignored.
  Future<void> _runSignIn(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
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
    }
  }
}

class _SignInSheet extends StatelessWidget {
  const _SignInSheet({
    required this.isSigningIn,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
  });

  final bool isSigningIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bgBeige,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
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
          _AppleButton(isLoading: isSigningIn, onTap: onAppleSignIn),
          const SizedBox(height: 14),
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
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Privacy Policy',
            style: base.copyWith(
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => openExternalUrl(AppConfig.privacyPolicyUrl),
          ),
          const TextSpan(
            text: '. Recipe pages you save are sent to an AI service '
                '(OpenRouter) to extract the recipe details.',
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                  Text(
                    'Continue with Apple',
                    style: AppText.body().copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                  Text(
                    'Continue with Google',
                    style: AppText.body().copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onGreen,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
