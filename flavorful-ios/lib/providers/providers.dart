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

/// Recipe backend. Chosen by [AppConfig.useMockData]; held for the app's
/// lifetime so mock state (added/deleted/favorited recipes) persists.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  if (AppConfig.useMockData) {
    return MockRecipeRepository();
  }
  return HttpRecipeRepository(
    baseUrl: AppConfig.apiBaseUrl,
    getToken: () => ref.read(authControllerProvider).valueOrNull?.token,
  );
});

/// Current session. `null` data means signed out.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    // OAuth completes out-of-band (browser round-trip), so the session arrives
    // on the stream rather than as a return value — listen and push to state.
    final sub = repo.authStateChanges().listen((session) {
      state = AsyncData(session);
    });
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
  /// surface it and leave the account intact.
  Future<void> deleteAccount() async {
    await ref.read(recipeRepositoryProvider).deleteAccount();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

/// The user's saved recipes, newest first. Backs the Library list.
final recipesProvider =
    AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(RecipesNotifier.new);

class RecipesNotifier extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() {
    // Rebuild (refetch) whenever the signed-in user changes, so switching
    // accounts never shows the previous user's recipes. Keyed on email so a
    // token refresh for the same user doesn't reset the list to a spinner.
    ref.watch(authControllerProvider.select((s) => s.valueOrNull?.email));

    // The first load can race ahead of a usable access token: on a restored
    // session the persisted token is often stale, and Supabase delivers a
    // fresh one moments later via a `tokenRefreshed`/`signedIn` event for the
    // SAME user. Without this the email-keyed watch above would ignore that
    // event and the list would stay empty until a manual pull-to-refresh.
    // Re-fetch (without a spinner flash) whenever the token actually changes.
    ref.listen(
      authControllerProvider.select((s) => s.valueOrNull?.token),
      (previous, next) {
        if (next != null && next.isNotEmpty && next != previous) {
          refresh();
        }
      },
    );

    return ref.read(recipeRepositoryProvider).getAllRecipes();
  }

  /// Re-fetch from the repository (pull-to-refresh).
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(recipeRepositoryProvider).getAllRecipes(),
    );
  }

  void removeLocally(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != id).toList());
  }

  void setFavorite(String id, bool isFavorited) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        if (r.id == id) r.copyWith(isFavorited: isFavorited) else r,
    ]);
  }
}

/// Full recipe detail by id.
final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, id) async {
  return ref.watch(recipeRepositoryProvider).getRecipe(id);
});

/// Search results for a given query. Calls the backend /search-recipes
/// endpoint (ilike on recipe_name). The UI also filters client-side for
/// instant feel while the request is in-flight.
final searchRecipesProvider =
    FutureProvider.family<List<Recipe>, String>((ref, query) async {
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

final addRecipeProvider =
    NotifierProvider<AddRecipeNotifier, AddRecipeState>(AddRecipeNotifier.new);

class AddRecipeNotifier extends Notifier<AddRecipeState> {
  @override
  AddRecipeState build() => const AddRecipeState();

  /// Scrape + save [url]. Drives the saving spinner, refreshes the list on
  /// success, and surfaces a retryable error on failure. Keeps the URL in the
  /// field either way so the user can retry.
  Future<void> submit(String url) async {
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
      // Backend returns only a status string; re-fetch the authoritative list.
      await ref.read(recipesProvider.notifier).refresh();
      state = const AddRecipeState();
    } on RecipeException catch (e) {
      state = AddRecipeState(
        status: AddStatus.error,
        pastedUrl: trimmed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = AddRecipeState(
        status: AddStatus.error,
        pastedUrl: trimmed,
        errorMessage: "Couldn't read that page. Try a different URL.",
      );
    }
  }

  void reset() => state = const AddRecipeState();
}
