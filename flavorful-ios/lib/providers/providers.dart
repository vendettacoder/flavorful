import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/auth_repository.dart';
import '../data/http_recipe_repository.dart';
import '../data/mock_recipe_repository.dart';
import '../data/recipe_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../models/recipe.dart';
import '../util/url_validation.dart';

/// Auth backend — Supabase (Google OAuth) when live, mock when offline.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConfig.useMockData
      ? MockAuthRepository()
      : SupabaseAuthRepository();
});

/// Recipe backend for the current user. Token refresh keeps the same instance.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  if (AppConfig.useMockData) {
    return MockRecipeRepository();
  }
  return HttpRecipeRepository(
    baseUrl: AppConfig.apiBaseUrl,
    getToken: () {
      final session = ref.read(authControllerProvider).valueOrNull;
      return session?.userId == userId ? session?.token : null;
    },
  );
});

/// Only identity changes reset user data. Token refresh keeps the same UI.
final sessionUserIdProvider = Provider<String?>(
  (ref) => ref.watch(
    authControllerProvider.select((value) => value.valueOrNull?.userId),
  ),
);

/// Current session. `null` data means signed out.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    // OAuth completes out-of-band (browser round-trip), so the session arrives
    // on the stream rather than as a return value — listen and push to state.
    final sub = repo.authStateChanges().listen(
      (session) {
        state = AsyncData(session);
      },
      onError: (Object error, StackTrace stack) {
        // A failed callback must not become an unhandled stream error.
        if (state.valueOrNull == null) state = AsyncError(error, stack);
      },
    );
    ref.onDispose(sub.cancel);
    return repo.currentSession();
  }

  Future<void> signInWithGoogle() async {
    await ref.read(authRepositoryProvider).signInWithGoogle();
  }

  Future<void> signInWithApple() async {
    await ref.read(authRepositoryProvider).signInWithApple();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  /// Permanently delete the account: wipe the user's server-side recipes and
  /// the Supabase auth user (backend), then sign out locally. Required by App
  /// Store Review Guideline 5.1.1(v). Throws on backend failure so the UI can
  /// show it and keep the session. Recipes may already have been deleted.
  Future<void> deleteAccount(RecipeRepository repository) async {
    final userId = state.valueOrNull?.userId;
    await repository.deleteAccount();
    if (state.valueOrNull?.userId != userId) return;
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

/// The user's saved recipes, newest first. Backs the Library list.
final recipesProvider =
    NotifierProvider<RecipesNotifier, AsyncValue<List<Recipe>>>(
      RecipesNotifier.new,
    );

class RecipesNotifier extends Notifier<AsyncValue<List<Recipe>>> {
  int _request = 0;
  int _generation = 0;
  Future<List<Recipe>> _loaded = Future.value(const []);
  Future<List<Recipe>> get loaded => _loaded;

  @override
  AsyncValue<List<Recipe>> build() {
    final userId = ref.watch(sessionUserIdProvider);
    final repository = ref.watch(recipeRepositoryProvider);
    final request = ++_request;
    _generation++;
    ref.onDispose(() {
      _request++;
      _generation++;
    });
    ref.listen(authControllerProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (after != null &&
          after.userId == before?.userId &&
          after.token != before?.token) {
        refresh();
      }
    });
    // Notifier returns a new loading value on identity changes. It must not
    // use AsyncNotifier's automatic retention of the previous user's data.
    _loaded = userId == null
        ? Future.value(const [])
        : repository.getAllRecipes();
    _apply(_loaded, request, userId);
    return const AsyncLoading();
  }

  Future<void> _apply(
    Future<List<Recipe>> result,
    int request,
    String? userId,
  ) async {
    final value = await AsyncValue.guard(() => result);
    if (request != _request || userId != ref.read(sessionUserIdProvider)) {
      return;
    }
    state = value.hasError && state.hasValue
        ? value.copyWithPrevious(state)
        : value;
  }

  /// Keep existing cards during same-user background refreshes.
  Future<void> refresh() async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;
    _loaded = ref.read(recipeRepositoryProvider).getAllRecipes();
    await _apply(_loaded, ++_request, userId);
  }

  bool _belongsToUser(int generation, String? userId) =>
      generation == _generation && userId == ref.read(sessionUserIdProvider);

  /// Finish shared updates even if the screen that started the action closes.
  Future<bool?> toggleFavorite(Recipe recipe) async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return null;
    final generation = _generation;
    final repository = ref.read(recipeRepositoryProvider);
    setFavorite(recipe.id, !recipe.isFavorited);
    try {
      final confirmed = await repository.toggleFavorite(recipe.id);
      if (!_belongsToUser(generation, userId)) return null;
      setFavorite(recipe.id, confirmed);
      await refresh();
      return _belongsToUser(generation, userId) ? confirmed : null;
    } catch (_) {
      if (!_belongsToUser(generation, userId)) return null;
      setFavorite(recipe.id, recipe.isFavorited);
      rethrow;
    }
  }

  Future<bool> deleteRecipe(String id) async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return false;
    final generation = _generation;
    final repository = ref.read(recipeRepositoryProvider);
    await repository.deleteRecipe(id);
    if (!_belongsToUser(generation, userId)) return false;
    removeLocally(id);
    ref.invalidate(recipeDetailProvider(id));
    return true;
  }

  void removeLocally(String id) {
    _request++;
    final current = state.valueOrNull;
    if (current == null) {
      // Replace the cancelled initial load with a post-delete list request.
      refresh();
      return;
    }
    state = AsyncData(current.where((r) => r.id != id).toList());
  }

  void setFavorite(String id, bool isFavorited) {
    final current = state.valueOrNull;
    // Keep an initial list request alive until there is data to update.
    if (current == null) return;
    _request++;
    state = AsyncData([
      for (final r in current)
        if (r.id == id) r.copyWith(isFavorited: isFavorited) else r,
    ]);
  }
}

/// Full recipe detail by id.
final recipeDetailProvider = FutureProvider.family<Recipe, String>((
  ref,
  id,
) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) throw const RecipeException('Please sign in again.');
  ref.watch(authControllerProvider.select((value) => value.valueOrNull?.token));
  return ref.watch(recipeRepositoryProvider).getRecipe(id);
});

/// Optional server search. The cookbook uses local title/domain/description
/// filtering and does not call this provider for each keystroke.
final searchRecipesProvider = FutureProvider.family<List<Recipe>, String>((
  ref,
  query,
) async {
  if (ref.watch(sessionUserIdProvider) == null) return const [];
  return ref.watch(recipeRepositoryProvider).searchRecipes(query);
});

// ── Add-recipe (the Library "saving" flow) ───────────────────

enum AddStatus { idle, saving, error }

class AddRecipeState {
  const AddRecipeState({
    this.status = AddStatus.idle,
    this.pastedUrl,
    this.errorMessage,
  });

  final AddStatus status;
  final String? pastedUrl;
  final String? errorMessage;

  bool get isSaving => status == AddStatus.saving;
  bool get hasError => status == AddStatus.error;
}

final addRecipeProvider = NotifierProvider<AddRecipeNotifier, AddRecipeState>(
  AddRecipeNotifier.new,
);

class AddRecipeNotifier extends Notifier<AddRecipeState> {
  int _operation = 0;

  @override
  AddRecipeState build() {
    ref.watch(sessionUserIdProvider);
    _operation++;
    ref.onDispose(() => _operation++);
    return const AddRecipeState();
  }

  /// Scrape + save [url]. Drives the saving spinner, refreshes the list on
  /// success, and surfaces a retryable error on failure. Keeps the URL in the
  /// field either way so the user can retry.
  Future<void> submit(String url) async {
    if (state.isSaving || ref.read(sessionUserIdProvider) == null) return;
    final operation = ++_operation;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Validate locally before spending a (rate-limited, costly) backend call.
    if (!isLikelyRecipeUrl(trimmed)) {
      state = AddRecipeState(
        status: AddStatus.error,
        pastedUrl: trimmed,
        errorMessage: 'Enter a valid recipe link (https://…)',
      );
      return;
    }
    final normalized = normalizeUrl(trimmed);
    state = AddRecipeState(status: AddStatus.saving, pastedUrl: normalized);
    try {
      await ref.read(recipeRepositoryProvider).extractRecipe(normalized);
      if (operation != _operation) return;
      // Backend returns only a status string; re-fetch the authoritative list.
      await ref.read(recipesProvider.notifier).refresh();
      if (operation != _operation) return;
      state = const AddRecipeState();
    } on RecipeException catch (e) {
      if (operation != _operation) return;
      state = AddRecipeState(
        status: AddStatus.error,
        pastedUrl: trimmed,
        errorMessage: e.message,
      );
    } catch (_) {
      if (operation != _operation) return;
      state = AddRecipeState(
        status: AddStatus.error,
        pastedUrl: trimmed,
        errorMessage: "Couldn't read that page. Try a different URL.",
      );
    }
  }

  void reset() => state = const AddRecipeState();
}
