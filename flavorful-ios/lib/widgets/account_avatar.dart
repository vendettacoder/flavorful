import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Circular account avatar. Shows the signed-in user's profile picture when
/// available (Google), falling back to a gradient circle with their initial
/// (e.g. Sign in with Apple, which provides no photo, or while the image loads
/// or fails).
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.initial,
    this.avatarUrl,
    this.size = 44,
    this.fontSize = 16,
  });

  final String initial;
  final String? avatarUrl;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentOrange, AppColors.accentOrangeDark],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.surface,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final url = avatarUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
