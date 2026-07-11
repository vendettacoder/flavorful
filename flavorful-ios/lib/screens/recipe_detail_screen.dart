import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/method_step.dart';
import '../widgets/section_header.dart';
import '../widgets/servings_stepper.dart';
import '../widgets/ingredient_checkbox.dart';

/// Read a recipe, scale servings, check off ingredients, and jump to the
/// original page. Servings and checkoff are per-cook session state — they reset
/// each time the screen opens.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.summary,
  });

  final String recipeId;

  /// Optional summary (from the tapped card) for an instant header while the
  /// full recipe loads.
  final Recipe? summary;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings; // null until seeded from the loaded recipe
  bool? _favOverride; // null = use the recipe's own flag
  final Set<int> _checked = {}; // checked ingredient indices (this session)

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        body: SafeArea(
          bottom: false,
          child: recipeAsync.when(
            loading: _loadingView,
            error: (e, _) => _errorView(),
            data: _dataView,
          ),
        ),
      ),
    );
  }

  bool get _liveIsFavorited {
    final inList = ref
        .watch(recipesProvider)
        .valueOrNull
        ?.where((r) => r.id == widget.recipeId)
        .firstOrNull;
    return inList?.isFavorited ?? widget.summary?.isFavorited ?? false;
  }

  Widget _loadingView() => Column(
        children: [
          _TopBar(
            onBack: () => Navigator.of(context).pop(),
            onDelete: null,
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen),
            ),
          ),
        ],
      );

  Widget _errorView() => Column(
        children: [
          _TopBar(
            onBack: () => Navigator.of(context).pop(),
            onDelete: null,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.edge),
                child: Text(
                  'Could not load this recipe.',
                  style: AppText.body().copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _dataView(Recipe recipe) {
    final servings = _servings ?? recipe.servings;
    // Prefer: (1) local toggle override, (2) live recipesProvider (always
    // fresh after setFavorite/refresh), (3) fetched recipe as fallback.
    final isFavorited = _favOverride ?? _liveIsFavorited;
    final factor = recipe.servings == 0 ? 1.0 : servings / recipe.servings;

    return Column(
      children: [
        _TopBar(
          onBack: () => Navigator.of(context).pop(),
          onDelete: () => _confirmDelete(recipe),
        ),
        Expanded(
          child: SingleChildScrollView(
            // Bottom inset for the home indicator now lives here, so whichever
            // section is last (notes or nutrition) clears it.
            padding: const EdgeInsets.only(bottom: AppSpacing.homeIndicator),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleBlock(
                  recipe,
                  isFavorited: isFavorited,
                  onFavorite: () => _toggleFavorite(recipe, isFavorited),
                ),
                _statsRow(recipe, servings),
                _ingredients(recipe, factor),
                _method(recipe),
                if (recipe.notesFromPage.isNotEmpty) _notes(recipe),
                if (recipe.nutrition.isNotEmpty) _nutrition(recipe),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleBlock(
    Recipe recipe, {
    required bool isFavorited,
    required VoidCallback onFavorite,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 24, AppSpacing.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.hostname.toUpperCase(), style: AppText.sourceEyebrow()),
          const SizedBox(height: 10),
          // Title + a fixed favorite button to its right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(recipe.title, style: AppText.recipeTitle()),
              ),
              const SizedBox(width: 12),
              _FavoriteButton(isFavorited: isFavorited, onTap: onFavorite),
            ],
          ),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(recipe.description, style: AppText.body()
                .copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          // Subtle source link (replaces the prominent top CTA).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openOriginal(recipe.url),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcons.externalLink(size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'View on ${recipe.hostname}',
                  style: AppText.body().copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(Recipe recipe, int servings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 20, AppSpacing.edge, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (recipe.totalMinutes > 0) ...[
            _stat('TIME',
                Text('${recipe.totalMinutes} min', style: AppText.statValue())),
            const SizedBox(width: 24),
          ],
          _stat(
            'SERVES',
            ServingsStepper(
              value: servings,
              onChanged: (v) => setState(() => _servings = v),
            ),
          ),
          if (recipe.difficulty != null) ...[
            const SizedBox(width: 24),
            _stat('DIFFICULTY',
                Text(recipe.difficulty!, style: AppText.statValue())),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.statLabel()),
        const SizedBox(height: 2),
        value,
      ],
    );
  }

  Widget _ingredients(Recipe recipe, double factor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 32, AppSpacing.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Ingredients',
            meta: '${recipe.ingredients.length} · serves '
                '${_servings ?? recipe.servings}',
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < recipe.ingredients.length; i++)
            _IngredientRow(
              ingredient: recipe.ingredients[i],
              factor: factor,
              checked: _checked.contains(i),
              isLast: i == recipe.ingredients.length - 1,
              onToggle: (v) => setState(() {
                if (v) {
                  _checked.add(i);
                } else {
                  _checked.remove(i);
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _method(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 24, AppSpacing.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Method',
            meta: '${recipe.method.length} steps',
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < recipe.method.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            MethodStep(
              number: (i + 1).toString().padLeft(2, '0'),
              body: recipe.method[i],
            ),
          ],
        ],
      ),
    );
  }

  Widget _notes(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 24, AppSpacing.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Notes'),
          const SizedBox(height: 16),
          for (var i = 0; i < recipe.notesFromPage.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _NoteRow(note: recipe.notesFromPage[i]),
          ],
        ],
      ),
    );
  }

  Widget _nutrition(Recipe recipe) {
    final entries = recipe.nutrition.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 24, AppSpacing.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Nutrition'),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.dividerSoft),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entries[i].key, style: AppText.ingredient()),
                  Text(entries[i].value,
                      style: AppText.ingredient().copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(Recipe recipe, bool current) async {
    final next = !current;
    // Optimistic update for instant star feedback.
    setState(() => _favOverride = next);
    ref.read(recipesProvider.notifier).setFavorite(recipe.id, next);
    try {
      await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
      // Re-fetch so the library re-orders (favorites first) immediately.
      ref.read(recipesProvider.notifier).refresh();
    } catch (_) {
      // Roll back on failure.
      if (mounted) setState(() => _favOverride = current);
      ref.read(recipesProvider.notifier).setFavorite(recipe.id, current);
    }
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('“${recipe.title}” will be removed from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentOrange),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id);
    ref.read(recipesProvider.notifier).removeLocally(recipe.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openOriginal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onDelete,
  });

  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Match content edge (20) so the delete icon lines up vertically with the
      // favorite star in the title block below.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.edge, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dividerSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcons.chevronBack(size: 18, color: AppColors.accentOrange),
                const SizedBox(width: 6),
                Text(
                  'Library',
                  style: AppText.body().copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentOrange,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bare favorite star shown beside the recipe title — same 24px footprint as
/// the top-bar delete icon so the two line up vertically.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorited, required this.onTap});
  final bool isFavorited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(child: AppIcons.star(size: 24, filled: isFavorited)),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.factor,
    required this.checked,
    required this.isLast,
    required this.onToggle,
  });

  final Ingredient ingredient;
  final double factor;
  final bool checked;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppText.ingredient().copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
    );

    // Structured (mock) ingredients have a bold quantity + name; freeform
    // (backend) ones have an empty quantity, so render just the text.
    // Quantity + name read strong (primary, w600); the side-note recedes
    // (lighter weight + tertiary color) so it's clearly secondary.
    final qty = ingredient.scaledQuantityLabel(factor);
    final text = Text.rich(
      TextSpan(
        children: [
          if (qty.isNotEmpty)
            TextSpan(
              text: qty,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          TextSpan(
            text: qty.isNotEmpty ? ' ${ingredient.name}' : ingredient.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (ingredient.sideNote != null)
            TextSpan(
              text: ' — ${ingredient.sideNote}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
        ],
      ),
      style: baseStyle,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggle(!checked), // tapping anywhere on the row toggles
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.dividerSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: IngredientCheckbox(checked: checked, onChanged: onToggle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: checked ? Opacity(opacity: 0.4, child: text) : text,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});
  final NoteFromPage note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: SizedBox(
            width: 16,
            child: Text('→', style: AppText.notesArrow()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (note.boldLeadIn != null)
                  TextSpan(
                    text: '${note.boldLeadIn} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                TextSpan(text: note.body),
              ],
            ),
            style: AppText.notesItem(),
          ),
        ),
      ],
    );
  }
}
