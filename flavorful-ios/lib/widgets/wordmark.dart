import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'app_icons.dart';

enum WordmarkSize { md, lg }

/// The "flavorful" wordmark: the brand tomato mark followed by the name.
///
/// [WordmarkSize.lg] (22pt) is used on the sign-in hero; [WordmarkSize.md]
/// (18pt) on the Library top bar. [onDark] flips the text to warm off-white for
/// the green hero panel.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = WordmarkSize.lg, this.onDark = false});

  final WordmarkSize size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final isLg = size == WordmarkSize.lg;
    final fontSize = isLg ? 22.0 : 18.0;
    // The tomato reads as a glyph beside the text, so size it to the cap height.
    final mark = isLg ? 24.0 : 20.0;
    final gap = isLg ? 8.0 : 7.0;
    final tracking = AppText.tracking(isLg ? -0.03 : -0.025, fontSize);
    final textColor = onDark ? AppColors.onGreen : AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcons.tomatoMark(size: mark),
        SizedBox(width: gap),
        Text(
          'flavorful',
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: tracking,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
