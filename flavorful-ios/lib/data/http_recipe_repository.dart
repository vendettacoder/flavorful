import 'package:dio/dio.dart';

import '../models/recipe.dart';
import 'recipe_repository.dart';

/// Live [RecipeRepository] backed by the FastAPI backend.
///
/// Endpoint map:
///   GET  /get-all-recipes          → sorted list (favorites first, newest-first)
///   GET  /search-recipes?q=        → ilike search on recipe_name
///   GET  /get-recipe/{url:path}    → scrape + insert; returns a plain status string
///   POST /favorite-recipe/{id}     → toggles is_favorited, returns {is_favorited}
///   DELETE /delete-recipe/{id}     → hard delete
///
/// Auth: `auth-header: Bearer <supabase_access_token>` on every request.
class HttpRecipeRepository implements RecipeRepository {
  HttpRecipeRepository({
    required String baseUrl,
    required this.getToken,
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['auth-header'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final String? Function() getToken;

  // Locally-hidden deleted ids so cards disappear before the next refetch.
  final Set<String> _deletedIds = {};

  @override
  Future<List<Recipe>> getAllRecipes() async {
    try {
      final res = await _dio.get<dynamic>('/get-all-recipes');
      return _parse(res.data);
    } on DioException catch (e) {
      throw RecipeException(_friendlyError(e, 'Could not load your recipes.'));
    }
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final res = await _dio.get<dynamic>(
        '/search-recipes',
        queryParameters: query.isNotEmpty ? {'q': query} : null,
      );
      return _parse(res.data);
    } on DioException catch (_) {
      return getAllRecipes();
    }
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    final all = await getAllRecipes();
    final index = all.indexWhere((r) => r.id == id);
    if (index == -1) throw const RecipeException('Recipe not found.');
    return all[index];
  }

  @override
  Future<Recipe> extractRecipe(String url) async {
    final trimmed = url.trim();
    final String body;
    try {
      final encoded = Uri.encodeComponent(trimmed);
      final res = await _dio.get<dynamic>('/get-recipe/$encoded');
      body = res.data?.toString() ?? '';
    } on DioException catch (e) {
      throw RecipeException(
        _friendlyError(e, "Couldn't read that page. Try a different URL."),
      );
    }

    final saved = body.contains('Successfully inserted') ||
        body.contains('already has a recipe');
    if (!saved) {
      throw const RecipeException(
          "Couldn't read that page. Try a different URL.");
    }

    final all = await getAllRecipes();
    final index = all.indexWhere((r) => r.url == trimmed);
    if (index != -1) return all[index];
    if (all.isNotEmpty) return all.first;
    throw const RecipeException('Saved, but could not load the new recipe.');
  }

  @override
  Future<void> deleteRecipe(String id) async {
    try {
      await _dio.delete<dynamic>('/delete-recipe/$id');
      _deletedIds.add(id);
    } on DioException catch (e) {
      throw RecipeException(_friendlyError(e, 'Could not delete this recipe.'));
    }
  }

  @override
  Future<bool> toggleFavorite(String id) async {
    try {
      final res = await _dio.post<dynamic>('/favorite-recipe/$id');
      return res.data['is_favorited'] as bool;
    } on DioException catch (e) {
      throw RecipeException(_friendlyError(e, 'Could not update favorite.'));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<dynamic>('/delete-account');
    } on DioException catch (e) {
      throw RecipeException(
        _friendlyError(e, 'Could not delete your account. Please try again.'),
      );
    }
  }

  List<Recipe> _parse(dynamic data) {
    final rows = (data as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((r) => Recipe.fromBackendRow(r.cast<String, dynamic>()))
        .where((r) => !_deletedIds.contains(r.id))
        .toList();
  }

  String _friendlyError(DioException e, String fallback) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Please sign in again.';
    if (code == 429) {
      return 'Too many requests right now — wait a minute and try again.';
    }
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is String && data.isNotEmpty) return data;
    return fallback;
  }
}
