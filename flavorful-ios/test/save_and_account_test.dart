import 'dart:async';

import 'package:flavorful/data/recipe_repository.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

class _SaveRepository extends TestRecipeRepository {
  bool fail = true;
  int calls = 0;
  Completer<Recipe>? pendingSave;
  @override
  Future<Recipe> extractRecipe(String url) async {
    calls++;
    if (pendingSave != null) return pendingSave!.future;
    if (fail) throw const RecipeException('Could not read this page.');
    return data.first;
  }

  @override
  Future<void> deleteAccount() async {
    if (fail) {
      throw const RecipeException('Recipes deleted, but account not deleted.');
    }
  }
}

void main() {
  late TestAuthRepository auth;
  late _SaveRepository repository;
  late ProviderContainer container;
  setUp(() async {
    auth = TestAuthRepository(testSession());
    repository = _SaveRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recipeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await container.read(authControllerProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await auth.changes.close();
  });

  test(
    'save validates before requests, keeps failed URL, and supports retry',
    () async {
      final notifier = container.read(addRecipeProvider.notifier);
      await notifier.submit('bad URL');
      expect(repository.calls, 0);
      await notifier.submit('https://example.com/recipe');
      expect(container.read(addRecipeProvider).status, AddStatus.error);
      expect(
        container.read(addRecipeProvider).pastedUrl,
        'https://example.com/recipe',
      );
      repository.fail = false;
      await notifier.submit(container.read(addRecipeProvider).pastedUrl!);
      expect(container.read(addRecipeProvider).status, AddStatus.idle);
      expect(repository.calls, 2);
    },
  );

  test(
    'save progress blocks duplicates and old-user completion is ignored',
    () async {
      final sub = container.listen(addRecipeProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(addRecipeProvider.notifier);
      repository.pendingSave = Completer<Recipe>();
      final save = notifier.submit('https://example.com/recipe');
      expect(container.read(addRecipeProvider).status, AddStatus.saving);
      await notifier.submit('https://example.com/recipe');
      expect(repository.calls, 1);
      auth.emit(testSession(id: 'user-b'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(addRecipeProvider).status, AddStatus.idle);
      repository.pendingSave!.complete(repository.data.first);
      await save;
      expect(container.read(addRecipeProvider).status, AddStatus.idle);
    },
  );

  test(
    'partial account deletion keeps session; confirmed deletion signs out',
    () async {
      final controller = container.read(authControllerProvider.notifier);
      await expectLater(
        controller.deleteAccount(repository),
        throwsA(isA<RecipeException>()),
      );
      expect(
        container.read(authControllerProvider).valueOrNull?.userId,
        'user-a',
      );
      repository.fail = false;
      await controller.deleteAccount(repository);
      expect(container.read(authControllerProvider).valueOrNull, isNull);
    },
  );
}
