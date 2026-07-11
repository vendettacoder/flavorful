import '../models/recipe.dart';

/// Contract for recipe storage. The UI depends only on this interface, so the
/// in-memory mock and the live HTTP client are fully interchangeable.
abstract class RecipeRepository {
  /// All saved recipes, newest first. Backs the Library screen.
  Future<List<Recipe>> getAllRecipes();

  /// Full recipe by id (ingredients, method, notes). Backs the Detail screen.
  Future<Recipe> getRecipe(String id);

  /// Scrape and save a recipe from a blog [url]. Long-running — powers the
  /// Library "saving" state. Throws [RecipeException] on failure.
  Future<Recipe> extractRecipe(String url);

  /// Search recipes by [query]. Returns all recipes when [query] is empty.
  /// Until the backend implements full-text search, the result set is identical
  /// to [getAllRecipes]; the client additionally filters locally.
  Future<List<Recipe>> searchRecipes(String query);

  /// Delete a recipe by id (persists to the backend via DELETE).
  Future<void> deleteRecipe(String id);

  /// Toggle favorite; returns the new state. (No backend endpoint — local only.)
  Future<bool> toggleFavorite(String id);

  /// Permanently delete the signed-in user's account and all their server-side
  /// data. Backed by DELETE /delete-account. Throws [RecipeException] on
  /// failure so the account is left intact. (App Store Guideline 5.1.1(v).)
  Future<void> deleteAccount();
}

/// User-facing failure from a repository call.
class RecipeException implements Exception {
  const RecipeException(this.message);
  final String message;

  @override
  String toString() => 'RecipeException: $message';
}
