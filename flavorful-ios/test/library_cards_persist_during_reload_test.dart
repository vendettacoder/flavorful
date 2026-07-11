import 'dart:async';

import 'package:flavorful/data/auth_repository.dart';
import 'package:flavorful/data/recipe_repository.dart';
import 'package:flavorful/data/sample_data.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/screens/library_screen.dart';
import 'package:flavorful/widgets/recipe_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth repo whose session stream we drive by hand.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._initial);
  final AuthSession? _initial;
  final _controller = StreamController<AuthSession?>.broadcast();

  void emit(AuthSession? s) => _controller.add(s);

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

/// Recipe repo whose fetches complete only when we say so — no timers, so the
/// in-reload frame is fully observable and nothing outlives the test.
class _ControlledRecipeRepository implements RecipeRepository {
  _ControlledRecipeRepository(this._data);
  final List<Recipe> _data;
  final List<Completer<List<Recipe>>> _pending = [];

  void completeAll() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete(_data);
    }
    _pending.clear();
  }

  @override
  Future<List<Recipe>> getAllRecipes() {
    final c = Completer<List<Recipe>>();
    _pending.add(c);
    return c.future;
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async => _data;
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

AuthSession _session(String email) =>
    AuthSession(token: 't-$email', email: email, userInitial: 'X');

void main() {
  testWidgets(
      'recipe cards stay visible during a background reload '
      '(no "count says N but list is a spinner" mismatch)', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _FakeAuthRepository(_session('a@example.com'));
    final repo = _ControlledRecipeRepository(buildSampleRecipes());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recipeRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );

    // Baseline: resolve the first fetch → four cards.
    await tester.pump(); // let build() kick off getAllRecipes
    repo.completeAll();
    await tester.pump();
    expect(find.byType(RecipeCard), findsNWidgets(4));

    // Trigger a reload while data already exists (mirrors a token refresh /
    // auth-state change re-running the provider). Leave the fetch un-resolved.
    auth.emit(_session('b@example.com'));
    await tester.pump();

    // The reported bug: the count still reads four, but the list dropped to a
    // spinner. The cards must stay put through the reload.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RecipeCard), findsNWidgets(4));

    // Resolve the reload so nothing is left pending.
    repo.completeAll();
    await tester.pump();
    expect(find.byType(RecipeCard), findsNWidgets(4));
  });
}
