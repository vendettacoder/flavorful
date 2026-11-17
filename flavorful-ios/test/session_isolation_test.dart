import 'dart:async';

import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  test(
    'different user with same email clears old recipes and pending save state',
    () async {
      final auth = TestAuthRepository(testSession());
      final repo = TestRecipeRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recipeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.changes.close);
      await container.read(authControllerProvider.future);
      final sub = container.listen(recipesProvider, (_, _) {});
      final addSub = container.listen(addRecipeProvider, (_, _) {});
      addTearDown(sub.close);
      addTearDown(addSub.close);
      expect(await container.read(recipesProvider.notifier).loaded, isNotEmpty);
      await container.read(addRecipeProvider.notifier).submit('bad URL');
      expect(container.read(addRecipeProvider).hasError, isTrue);
      repo.pending = Completer<List<Recipe>>();
      auth.emit(testSession(id: 'user-b'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(recipesProvider).valueOrNull, isNull);
      expect(container.read(addRecipeProvider).status, AddStatus.idle);
      repo.pending!.complete([]);
      expect(await container.read(recipesProvider.notifier).loaded, isEmpty);
    },
  );

  test('detail reloads for a different user with the same email', () async {
    final auth = TestAuthRepository(testSession());
    final repo = TestRecipeRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recipeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.changes.close);
    await container.read(authControllerProvider.future);
    final detail = recipeDetailProvider('r-lentil-soup');
    final sub = container.listen(detail, (_, _) {});
    addTearDown(sub.close);
    await container.read(detail.future);
    repo.pendingDetail = Completer<Recipe>();
    auth.emit(testSession(id: 'user-b'));
    await Future<void>.delayed(Duration.zero);
    final state = container.read(detail);
    expect(
      state.when(
        skipLoadingOnReload: false,
        data: (_) => 'old data',
        error: (_, _) => 'error',
        loading: () => 'loading',
      ),
      'loading',
    );
    repo.pendingDetail!.completeError(StateError('No recipe for this user'));
    await expectLater(container.read(detail.future), throwsStateError);
  });

  test('an old refresh cannot overwrite the new user data', () async {
    final auth = TestAuthRepository(testSession());
    final repo = TestRecipeRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recipeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.changes.close);
    await container.read(authControllerProvider.future);
    final sub = container.listen(recipesProvider, (_, _) {});
    addTearDown(sub.close);
    final old = await container.read(recipesProvider.notifier).loaded;
    final pending = Completer<List<Recipe>>();
    repo.pending = pending;
    final refresh = container.read(recipesProvider.notifier).refresh();
    repo.pending = null;
    repo.data = [];
    auth.emit(testSession(id: 'user-b'));
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(recipesProvider.notifier).loaded, isEmpty);
    pending.complete(old);
    await refresh;
    expect(container.read(recipesProvider).valueOrNull, isEmpty);
  });
}
