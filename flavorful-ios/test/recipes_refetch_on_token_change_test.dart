import 'dart:async';

import 'package:flavorful/data/auth_repository.dart';
import 'package:flavorful/data/recipe_repository.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth repo whose stream we drive by hand, so the test controls exactly when
/// the session (and its token) changes.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._initial);

  final AuthSession? _initial;
  final _controller = StreamController<AuthSession?>.broadcast();

  void emit(AuthSession? session) => _controller.add(session);

  @override
  Future<AuthSession?> currentSession() async => _initial;

  @override
  Stream<AuthSession?> authStateChanges() => _controller.stream;

  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {}
}

/// Recipe repo that only counts how many times the list was fetched.
class _CountingRecipeRepository implements RecipeRepository {
  int getAllCount = 0;

  @override
  Future<List<Recipe>> getAllRecipes() async {
    getAllCount++;
    return const <Recipe>[];
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async => const [];
  @override
  Future<Recipe> getRecipe(String id) => throw UnimplementedError();
  @override
  Future<Recipe> extractRecipe(String url) => throw UnimplementedError();
  @override
  Future<void> deleteRecipe(String id) async {}
  @override
  Future<bool> toggleFavorite(String id) async => false;
  @override
  Future<void> deleteAccount() async {}
}

AuthSession _session(String token) => AuthSession(
      token: token,
      email: 'cook@example.com', // SAME email across token changes
      userInitial: 'C',
    );

void main() {
  test(
      'recipes refetch when the token changes for the same user '
      '(stale-token-on-launch self-heals)', () async {
    final auth = _FakeAuthRepository(_session('stale-token'));
    final recipes = _CountingRecipeRepository();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recipeRepositoryProvider.overrideWithValue(recipes),
      ],
    );
    addTearDown(container.dispose);

    // Mirror reality: the session (with email) is already settled before the
    // Library screen mounts and the list first loads.
    await container.read(authControllerProvider.future);

    // Keep the list provider alive for the whole test (mirrors LibraryScreen),
    // mounted only AFTER the session is settled — as the real screen is.
    final sub = container.listen(recipesProvider, (_, _) {});
    addTearDown(sub.close);

    // First load: fetched once with the (stale) launch token.
    await container.read(recipesProvider.future);
    expect(recipes.getAllCount, 1);

    // Supabase delivers a fresh token for the SAME user moments later.
    auth.emit(_session('fresh-token'));
    // Let the auth state propagate and any refetch run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Must have refetched with the fresh token — otherwise the list stays
    // stuck on the stale-token result until a manual pull-to-refresh.
    expect(recipes.getAllCount, 2);
  });
}
