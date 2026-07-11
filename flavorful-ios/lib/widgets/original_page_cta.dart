import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'app_icons.dart';

/// Full-width orange "View on `hostname`" button for the detail screen. Opens
/// the original recipe page.
class OriginalPageCta extends StatelessWidget {
  const OriginalPageCta({super.key, required this.hostname, this.onTap});

  final String hostname;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentOrange,
          borderRadius: BorderRadius.circular(AppRadii.button),
          boxShadow: AppShadows.originalPageCta,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcons.externalLink(size: 14, color: AppColors.surface),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'View on $hostname',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
