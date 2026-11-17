import 'app_action.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';
import 'source_eyebrow.dart';

/// A library card: source eyebrow, title, description, and time.
/// A star is always visible top-right — filled when favorited, outline when not.
/// Tapping the star toggles favorite without opening the recipe.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onToggleFavorite,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppText.cardTitle();
    final descriptionStyle = AppText.cardDescription();
    final metaStyle = AppText.metaMono();
    final textScaler = MediaQuery.textScalerOf(context);
    double textHeight(TextStyle style, int lines) =>
        textScaler.scale(style.fontSize!) * (style.height ?? 1.4) * lines;

    return AppAction(
      label: 'Open ${recipe.title}',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSageCard,
          border: Border.all(color: AppColors.bgSageCardBorder),
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.sageCard,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: SourceEyebrow(recipe.hostname),
                ),
                Padding(
                  // Always reserve space for the star so title doesn't jump.
                  padding: const EdgeInsets.only(top: 8, right: 24),
                  child: SizedBox(
                    height: textHeight(titleStyle, 2),
                    child: Text(
                      recipe.title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Reserve the same space even when a description is absent.
                // The detail page still shows the full title and description.
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    height: textHeight(descriptionStyle, 3),
                    child: Text(
                      recipe.description,
                      style: descriptionStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: textHeight(metaStyle, 1).clamp(18, double.infinity),
                    child: Row(
                      children: [
                        if (recipe.totalMinutes > 0)
                          Flexible(
                            child: Text(
                              '${recipe.totalMinutes} min',
                              style: metaStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (recipe.totalMinutes > 0 && recipe.calories != null)
                          const SizedBox(width: 12),
                        if (recipe.calories != null) ...[
                          const Icon(
                            Icons.local_fire_department_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              recipe.calories!,
                              style: metaStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AppAction(
                // Stop tap propagating to the card's onTap.
                label: recipe.isFavorited ? 'Remove favorite' : 'Add favorite',
                onTap: onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AppIcons.star(size: 16, filled: recipe.isFavorited),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
