import 'package:flutter/foundation.dart';

import 'app_action.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/recipe_repository.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../util/launch.dart';
import 'account_avatar.dart';

/// Bottom sheet shown when the Library avatar is tapped: the signed-in
/// identity plus a Log out action.
class ProfileSheet {
  ProfileSheet._();

  static Future<void> show(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = kIsWeb || width >= 700;
    final margin = inset ? (width < 600 ? 16.0 : 24.0) : 0.0;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: 520 + margin * 2),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          margin,
          margin,
          margin,
          margin + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ProfileSheetBody(inset: inset),
      ),
    );
  }
}

class _ProfileSheetBody extends ConsumerWidget {
  const _ProfileSheetBody({required this.inset});

  final bool inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final email = session?.email ?? '';
    final initial = session?.userInitial ?? '?';
    final avatarUrl = session?.avatarUrl;

    return Container(
      key: const ValueKey('profile-panel'),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: inset
            ? BorderRadius.circular(AppRadii.sheet)
            : const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grabber.
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    AccountAvatar(initial: initial, avatarUrl: avatarUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body().copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            _providerLabel(session?.provider),
                            style: AppText.cardDescription(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _LogOutButton(
                  onTap: () async {
                    final controller = ref.read(
                      authControllerProvider.notifier,
                    );
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Log out?'),
                        content: const Text(
                          'Your saved recipes will stay in your account.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Log out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    try {
                      await controller.signOut();
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Could not log out. Please try again.'),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 6),
                _DeleteAccountButton(
                  onTap: () => _confirmAndDeleteAccount(context, ref),
                ),
                const SizedBox(height: 4),
                const _PrivacyLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirm, then permanently delete the account (App Store Guideline
  /// 5.1.1(v)). Captures the messenger before the sheet closes so a failure is
  /// still surfaced. On success, the cleared session routes back to sign-in.
  Future<void> _confirmAndDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Capture before any await so we don't touch BuildContext across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(authControllerProvider.notifier);
    final recipes = ref.read(recipesProvider.notifier);
    final repository = ref.read(recipeRepositoryProvider);
    final userId = ref.read(sessionUserIdProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all saved recipes. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (ref.read(sessionUserIdProvider) != userId) return;
    navigator.pop(); // close the sheet
    try {
      await controller.deleteAccount(repository);
    } catch (e) {
      await recipes.refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is RecipeException
                ? e.message
                : 'Could not delete your account. Please try again.',
          ),
        ),
      );
    }
  }
}

/// Friendly "Signed in with X" label from the provider id.
String _providerLabel(String? provider) {
  switch (provider) {
    case 'apple':
      return 'Signed in with Apple';
    case 'google':
      return 'Signed in with Google';
    case 'email':
      return 'Signed in with email';
    default:
      return 'Signed in';
  }
}

/// Privacy Policy link. App Store Review Guideline 5.1.1 wants the policy
/// reachable from inside the app, not just the store listing.
class _PrivacyLink extends StatelessWidget {
  const _PrivacyLink();

  @override
  Widget build(BuildContext context) {
    return AppAction(
      onTap: () => openExternalUrl(AppConfig.privacyPolicyUrl),
      child: Container(
        height: 36,
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          'Privacy Policy',
          style: AppText.cardDescription().copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// Low-emphasis destructive action — a plain red text button so it's clearly
/// available (Apple requires it be easy to find) without competing visually
/// with Log out.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppAction(
      onTap: onTap,
      child: Container(
        height: 44,
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          'Delete account',
          style: AppText.body().copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.danger,
          ),
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppAction(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadii.button),
          boxShadow: AppShadows.dangerButton,
        ),
        child: Text(
          'Log out',
          style: AppText.body().copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.onGreen,
          ),
        ),
      ),
    );
  }
}
