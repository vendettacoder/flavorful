// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recipe.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_card.dart';
import '../widgets/save_island.dart';
import '../widgets/wordmark.dart';
import '../widgets/app_action.dart';

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

  final ScrollController _scrollController = ScrollController();
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    try {
      await ref.read(recipesProvider.notifier).toggleFavorite(recipe);
    } catch (_) {
      // The shared notifier restores the favorite, even after navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear the field once a save completes successfully.
    ref.listen<AddRecipeState>(addRecipeProvider, (prev, next) {
      if (prev?.status == AddStatus.saving && next.status == AddStatus.idle) {
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

    final recipes = recipesAsync.valueOrNull;
    final filtered =
        (recipes ?? <Recipe>[])
            .where(
              (r) =>
                  _searchQuery.isEmpty ||
                  r.title.toLowerCase().contains(_searchQuery) ||
                  r.hostname.toLowerCase().contains(_searchQuery) ||
                  r.description.toLowerCase().contains(_searchQuery),
            )
            .toList()
          ..sort((a, b) {
            if (a.isFavorited != b.isFavorited) return a.isFavorited ? -1 : 1;
            return b.savedAt.compareTo(a.savedAt);
          });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                children: [
                  _TopBar(
                    initial: initial,
                    avatarUrl: avatarUrl,
                    onAvatarTap: () => ProfileSheet.show(context),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1100
                            ? 3
                            : constraints.maxWidth >= 700
                            ? 2
                            : 1;
                        return RefreshIndicator(
                          color: AppColors.brandGreen,
                          onRefresh: () =>
                              ref.read(recipesProvider.notifier).refresh(),
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.edge,
                                    24,
                                    AppSpacing.edge,
                                    0,
                                  ),
                                  child: SaveIsland(
                                    controller: _urlController,
                                    status: addState.status,
                                    pastedUrl: addState.pastedUrl,
                                    errorMessage: addState.errorMessage,
                                    onSubmitted: _submit,
                                    onRetry: () => _submit(
                                      addState.pastedUrl ?? _urlController.text,
                                    ),
                                    onSave: () => _submit(_urlController.text),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.edge,
                                    28,
                                    AppSpacing.edge,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Cookbook',
                                          style: TextStyle(
                                            fontFamily: AppFonts.sans,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            letterSpacing: AppText.tracking(
                                              -0.025,
                                              22,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _cookbookCount(recipes?.length ?? 0),
                                        style: AppText.cardDescription(),
                                      ),
                                      IconButton(
                                        tooltip: 'Refresh recipes',
                                        onPressed: () => ref
                                            .read(recipesProvider.notifier)
                                            .refresh(),
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                          color: AppColors.brandGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.edge,
                                    10,
                                    AppSpacing.edge,
                                    16,
                                  ),
                                  child: _SearchPill(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ),
                              if (recipes == null && !recipesAsync.hasError)
                                const SliverToBoxAdapter(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (recipes == null || filtered.isEmpty)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.edge,
                                    ),
                                    child: Text(
                                      recipes == null
                                          ? 'Could not load your recipes. Use Refresh to retry.'
                                          : recipes.isEmpty
                                          ? 'Paste a link above to add your first recipe.'
                                          : 'No recipes match "$_searchQuery".',
                                      style: AppText.body(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.edge,
                                  ),
                                  sliver: SliverList.builder(
                                    itemCount: (filtered.length / columns)
                                        .ceil(),
                                    itemBuilder: (context, row) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (
                                            var col = 0;
                                            col < columns;
                                            col++
                                          ) ...[
                                            if (col > 0)
                                              const SizedBox(width: 18),
                                            Expanded(
                                              child:
                                                  row * columns + col <
                                                      filtered.length
                                                  ? _card(
                                                      filtered[row * columns +
                                                          col],
                                                    )
                                                  : const SizedBox(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: AppSpacing.homeIndicator,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Recipe recipe) => _SlideInOnAppear(
    key: ValueKey(recipe.id),
    child: RecipeCard(
      recipe: recipe,
      onTap: () => context.go('/recipes/${Uri.encodeComponent(recipe.id)}'),
      onToggleFavorite: () => _toggleFavorite(recipe),
    ),
  );
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.edge,
        vertical: 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Wordmark(size: WordmarkSize.md),
          AppAction(
            label: 'Open profile',
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
                fontSize: AppText.inputFontSize,
                letterSpacing: AppText.tracking(-0.005, AppText.inputFontSize),
                color: AppColors.textPrimary,
              ),
              cursorColor: AppColors.brandGreen,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search recipes',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: AppText.inputFontSize,
                  letterSpacing: AppText.tracking(
                    -0.005,
                    AppText.inputFontSize,
                  ),
                  color: AppColors.brandGreen,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : AppAction(
                    label: 'Clear search',
                    // Programmatic clear doesn't fire onChanged — reset manually.
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.sageMuted,
                      ),
                    ),
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

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

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
