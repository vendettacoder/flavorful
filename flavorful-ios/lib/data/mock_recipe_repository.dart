import '../models/recipe.dart';
import '../util/url_validation.dart';
import 'recipe_repository.dart';
import 'sample_data.dart';

/// In-memory [RecipeRepository] for running without a backend. Holds a mutable
/// list seeded from [buildSampleRecipes] and simulates realistic latency.
class MockRecipeRepository implements RecipeRepository {
  MockRecipeRepository() : _recipes = buildSampleRecipes();

  final List<Recipe> _recipes;
  int _added = 0;

  @override
  Future<List<Recipe>> getAllRecipes() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _sorted(_recipes);
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (query.isEmpty) return _sorted(_recipes);
    final q = query.toLowerCase();
    return _sorted(_recipes.where((r) =>
        r.title.toLowerCase().contains(q) ||
        r.hostname.toLowerCase().contains(q) ||
        r.description.toLowerCase().contains(q)).toList());
  }

  /// Favorites first, then newest-first — mirrors the intended backend order.
  List<Recipe> _sorted(List<Recipe> list) {
    final copy = [...list];
    copy.sort((a, b) {
      if (a.isFavorited != b.isFavorited) return a.isFavorited ? -1 : 1;
      return b.savedAt.compareTo(a.savedAt);
    });
    return List.unmodifiable(copy);
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _recipes.indexWhere((r) => r.id == id);
    if (index == -1) {
      throw const RecipeException('Recipe not found.');
    }
    return _recipes[index];
  }

  @override
  Future<Recipe> extractRecipe(String url) async {
    final trimmed = url.trim();
    if (!isLikelyRecipeUrl(trimmed)) {
      throw const RecipeException(
          "Couldn't read that page. Try a different URL.");
    }
    // Simulate the backend scrape.
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    final recipe = Recipe(
      id: 'r-added-${++_added}',
      url: trimmed,
      hostname: hostnameFromUrl(trimmed),
      title: _titleFromUrl(trimmed),
      description: 'Saved from ${hostnameFromUrl(trimmed)}.',
      totalMinutes: 40,
      servings: 4,
      difficulty: 'Easy',
      isFavorited: false,
      savedAt: DateTime.now(),
      ingredients: const [
        Ingredient(
            quantityRaw: '2 tbsp',
            quantityValue: 2,
            unit: 'tbsp',
            name: 'olive oil'),
        Ingredient(quantityRaw: '1', quantityValue: 1, name: 'onion'),
        Ingredient(
            quantityRaw: '1 tsp', quantityValue: 1, unit: 'tsp', name: 'salt'),
      ],
      method: const [
        'Open the saved page to read the full instructions.',
        'This recipe was scraped from the URL you pasted.',
      ],
      notesFromPage: const [],
    );

    _recipes.insert(0, recipe);
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _recipes.removeWhere((r) => r.id == id);
  }

  @override
  Future<bool> toggleFavorite(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _recipes.indexWhere((r) => r.id == id);
    if (index == -1) throw const RecipeException('Recipe not found.');
    final updated =
        _recipes[index].copyWith(isFavorited: !_recipes[index].isFavorited);
    _recipes[index] = updated;
    return updated.isFavorited;
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _recipes.clear();
  }

  /// Turns the last URL path segment into a Title-Cased name.
  String _titleFromUrl(String url) {
    final withScheme = url.startsWith('http') ? url : 'https://$url';
    final segments = (Uri.tryParse(withScheme)?.pathSegments ?? [])
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return 'New recipe';
    final slug = segments.last
        .replaceAll(RegExp(r'\.(html?|php)$'), '')
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .trim();
    if (slug.isEmpty) return 'New recipe';
    return slug
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
