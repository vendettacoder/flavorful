import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_card.dart';
import '../widgets/save_island.dart';
import '../widgets/wordmark.dart';
import 'recipe_detail_screen.dart';

/// Browse saved recipes and add new ones by pasting a URL.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Drives the collapse of the "New recipe" section as the list scrolls.
  // 0 = fully expanded (at top), 1 = fully collapsed. Re-expands gradually on
  // scroll-up. Kept in a ValueNotifier so only the section rebuilds per frame,
  // not the whole screen.
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);
  static const double _collapseDistance = 110; // px of scroll to fully collapse

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _collapse.value =
        (_scrollController.offset / _collapseDistance).clamp(0.0, 1.0);
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collapse.dispose();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(addRecipeProvider.notifier).submit(value);
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final current = recipe.isFavorited;
    final next = !current;
    // Optimistic update + backend call + refresh (same as detail screen).
    ref.read(recipesProvider.notifier).setFavorite(recipe.id, next);
    try {
      await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
      ref.read(recipesProvider.notifier).refresh();
    } catch (_) {
      ref.read(recipesProvider.notifier).setFavorite(recipe.id, current);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear the field once a save completes successfully.
    ref.listen<AddRecipeState>(addRecipeProvider, (prev, next) {
      // Clear the field once a save finishes — success OR failure.
      if (prev?.status == AddStatus.saving &&
          (next.status == AddStatus.idle || next.status == AddStatus.error)) {
        _urlController.clear();
      }
      // Green confirmation when a recipe saves (saving → idle = success).
      if (prev?.status == AddStatus.saving && next.status == AddStatus.idle) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Recipe added to cookbook!'),
              backgroundColor: AppColors.brandGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    // Always use the loaded library list and filter client-side for instant
    // results. The searchRecipesProvider (backend ilike) is available for
    // explicit/batch search but not suitable for per-keystroke filtering.
    final recipesAsync = ref.watch(recipesProvider);
    final addState = ref.watch(addRecipeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final initial = session?.userInitial ?? '?';
    final avatarUrl = session?.avatarUrl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(
                initial: initial,
                avatarUrl: avatarUrl,
                onAvatarTap: () => ProfileSheet.show(context),
              ),
              // ── Save island (collapses as the list scrolls down) ──
              ValueListenableBuilder<double>(
                valueListenable: _collapse,
                builder: (context, collapse, child) {
                  final factor = 1 - collapse; // 1 expanded → 0 collapsed
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: factor,
                      child: Opacity(opacity: factor, child: child),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.edge, 24, AppSpacing.edge, 0),
                  child: SaveIsland(
                    controller: _urlController,
                    status: addState.status,
                    pastedUrl: addState.pastedUrl,
                    errorMessage: addState.errorMessage,
                    onSubmitted: _submit,
                    onRetry: () =>
                        _submit(addState.pastedUrl ?? _urlController.text),
                    onSave: () => _submit(_urlController.text),
                  ),
                ),
              ),
              // ── Cookbook header: title + count, no eyebrow ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.edge, 32, AppSpacing.edge, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cookbook',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppText.tracking(-0.025, 22),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _cookbookCount(recipesAsync.valueOrNull?.length ?? 0),
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: AppText.tracking(-0.005, 13),
                        color: AppColors.sageMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Search pill ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.edge, 14, AppSpacing.edge, 0),
                child: _SearchPill(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                // Render off the loaded value (same source as the count above),
                // so once recipes exist the cards stay visible through any
                // background reload/refetch (e.g. a token refresh). Showing the
                // spinner only when there is genuinely no data yet prevents the
                // "count says 4 but the list is a spinner" mismatch.
                child: Builder(
                  builder: (context) {
                    final recipes = recipesAsync.valueOrNull;
                    if (recipes != null) {
                      return _RecipeList(
                        recipes: recipes,
                        searchQuery: _searchQuery,
                        scrollController: _scrollController,
                        onRefresh: () =>
                            ref.read(recipesProvider.notifier).refresh(),
                        onTap: _openDetail,
                        onToggleFavorite: _toggleFavorite,
                      );
                    }
                    if (recipesAsync.hasError) {
                      return _ListMessage(
                        'Could not load your recipes.\nPull down to retry.',
                        onRefresh: () =>
                            ref.read(recipesProvider.notifier).refresh(),
                        controller: _scrollController,
                      );
                    }
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandGreen,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RecipeDetailScreen(recipeId: recipe.id, summary: recipe),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.initial,
    required this.onAvatarTap,
    this.avatarUrl,
  });
  final String initial;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.edge, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Wordmark(size: WordmarkSize.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: AccountAvatar(
              initial: initial,
              avatarUrl: avatarUrl,
              size: 32,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Cookbook subtitle count, e.g. "42 recipes".
String _cookbookCount(int count) => count == 0
    ? 'No recipes yet'
    : count == 1
        ? '1 recipe'
        : '$count recipes';

/// White search field with a sage border — visually rhymes with the Save
/// input inside the island (same 12px radius, same 52px height, both white).
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandGreen),
      ),
      child: Row(
        children: [
          AppIcons.search(size: 16, color: AppColors.brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                letterSpacing: AppText.tracking(-0.005, 14),
                color: AppColors.textPrimary,
              ),
              cursorColor: AppColors.brandGreen,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search recipes',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14,
                  letterSpacing: AppText.tracking(-0.005, 14),
                  color: AppColors.brandGreen,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Programmatic clear doesn't fire onChanged — reset manually.
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.sageMuted),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.recipes,
    required this.onRefresh,
    required this.onTap,
    required this.onToggleFavorite,
    required this.scrollController,
    this.searchQuery = '',
  });

  final List<Recipe> recipes;
  final String searchQuery;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Recipe) onTap;
  final void Function(Recipe) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final filtered = searchQuery.isEmpty
        ? recipes
        : recipes
            .where((r) =>
                r.title.toLowerCase().contains(searchQuery) ||
                r.hostname.toLowerCase().contains(searchQuery) ||
                r.description.toLowerCase().contains(searchQuery))
            .toList();

    if (recipes.isEmpty) {
      return _ListMessage(
        'Paste a link above to add your first recipe.',
        onRefresh: onRefresh,
        controller: scrollController,
      );
    }
    if (filtered.isEmpty) {
      return _ListMessage('No recipes match "$searchQuery".',
          onRefresh: onRefresh, controller: scrollController);
    }
    return RefreshIndicator(
      color: AppColors.brandGreen,
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.edge, 12, AppSpacing.edge, AppSpacing.homeIndicator),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final recipe = filtered[i];
          return _SlideInOnAppear(
            key: ValueKey(recipe.id),
            child: RecipeCard(
              recipe: recipe,
              onTap: () => onTap(recipe),
              onToggleFavorite: () => onToggleFavorite(recipe),
            ),
          );
        },
      ),
    );
  }
}

/// Scrollable message (empty state / error) that still supports pull-to-refresh.
class _ListMessage extends StatelessWidget {
  const _ListMessage(this.text, {required this.onRefresh, this.controller});
  final String text;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.brandGreen,
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.edge, 48, AppSpacing.edge, 0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.body().copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-shot fade + slide-up when a card first appears (200ms easeOut). Keyed by
/// recipe id, so existing cards don't re-animate when a new one is prepended.
class _SlideInOnAppear extends StatefulWidget {
  const _SlideInOnAppear({super.key, required this.child});
  final Widget child;

  @override
  State<_SlideInOnAppear> createState() => _SlideInOnAppearState();
}

class _SlideInOnAppearState extends State<_SlideInOnAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
