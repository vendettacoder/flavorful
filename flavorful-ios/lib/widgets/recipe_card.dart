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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                SourceEyebrow(recipe.hostname),
                Padding(
                  // Always reserve space for the star so title doesn't jump.
                  padding: const EdgeInsets.only(top: 8, right: 24),
                  child: Text(recipe.title, style: AppText.cardTitle()),
                ),
                if (recipe.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      recipe.description,
                      style: AppText.cardDescription(),
                    ),
                  ),
                if (recipe.totalMinutes > 0 || recipe.calories != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        if (recipe.totalMinutes > 0)
                          Text('${recipe.totalMinutes} min',
                              style: AppText.metaMono()),
                        if (recipe.totalMinutes > 0 && recipe.calories != null)
                          const SizedBox(width: 12),
                        if (recipe.calories != null) ...[
                          const Icon(Icons.local_fire_department_outlined,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(recipe.calories!, style: AppText.metaMono()),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Stop tap propagating to the card's onTap.
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
