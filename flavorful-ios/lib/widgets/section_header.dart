import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// A section header — green title with an optional mono meta on the right,
/// underlined by a 2px green rule. Used for Ingredients, Method, and Notes.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.meta});

  final String title;

  /// Optional right-aligned meta, e.g. "14 · serves 4" or "8 steps".
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.brandGreen, width: 2),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(title, style: AppText.sectionHeader()),
          if (meta != null) Text(meta!, style: AppText.metaMono()),
        ],
      ),
    );
  }
}
