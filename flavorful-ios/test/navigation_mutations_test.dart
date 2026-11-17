import 'dart:async';

import 'package:flavorful/data/recipe_repository.dart';
import 'package:flavorful/main.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/routing.dart';
import 'package:flavorful/widgets/app_action.dart';
import 'package:flavorful/widgets/ingredient_checkbox.dart';
import 'package:flavorful/widgets/servings_stepper.dart';
// Keep tests compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

const recipeId = 'r-lentil-soup';

class DelayedRecipeRepository extends TestRecipeRepository {
  DelayedRecipeRepository() {
    data = data.where((recipe) => recipe.id == recipeId).toList();
  }

  Completer<bool>? favorite;
  Completer<void>? deletion;
  bool failDetail = false;
  int detailCalls = 0;

  @override
  Future<bool> toggleFavorite(String id) async {
    final confirmed = await favorite!.future;
    data = [
      for (final recipe in data)
        if (recipe.id == id)
          recipe.copyWith(isFavorited: confirmed)
        else
          recipe,
    ];
    return confirmed;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await deletion!.future;
    data = data.where((recipe) => recipe.id != id).toList();
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    detailCalls++;
    if (failDetail) throw const RecipeException('Expired token');
    return super.getRecipe(id);
  }
}

Finder action(String label) => find.byWidgetPredicate(
  (widget) => widget is AppAction && widget.label == label,
);

Future<ProviderContainer> mount(
  WidgetTester tester,
  TestAuthRepository auth,
  DelayedRecipeRepository repository, {
  DelayedRecipeRepository? otherUser,
  String? initialRoute,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      recipeRepositoryProvider.overrideWith((ref) {
        final userId = ref.watch(sessionUserIdProvider);
        return userId == 'user-b' ? otherUser! : repository;
      }),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.changes.close);
  if (initialRoute != null) {
    container.read(appRouterProvider).go(initialRoute);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FlavorfulApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final fromDetail in [false, true]) {
    testWidgets(
      'favorite failure rolls back after leaving detail=$fromDetail',
      (tester) async {
        final repository = DelayedRecipeRepository()
          ..favorite = Completer<bool>();
        final container = await mount(
          tester,
          TestAuthRepository(testSession()),
          repository,
        );
        final router = container.read(appRouterProvider);
        if (fromDetail) {
          router.go('/recipes/$recipeId');
          await tester.pumpAndSettle();
        }
        await tester.tap(action('Add favorite'));
        await tester.pumpAndSettle();
        expect(
          container.read(recipesProvider).value!.single.isFavorited,
          isTrue,
        );
        router.go(fromDetail ? '/' : '/recipes/$recipeId');
        await tester.pumpAndSettle();
        repository.favorite!.completeError(
          const RecipeException('Favorite failed'),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(recipesProvider).value!.single.isFavorited,
          isFalse,
        );
        expect(action('Add favorite'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('delete completion updates cookbook after leaving detail', (
    tester,
  ) async {
    final repository = DelayedRecipeRepository()..deletion = Completer<void>();
    final container = await mount(
      tester,
      TestAuthRepository(testSession()),
      repository,
    );
    final router = container.read(appRouterProvider);
    router.go('/recipes/$recipeId');
    await tester.pumpAndSettle();
    expect(
      container.read(recipeDetailProvider(recipeId)).valueOrNull,
      isNotNull,
    );
    await tester.tap(action('Delete recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    final staleRecipes = List<Recipe>.of(repository.data);
    final staleResult = Completer<List<Recipe>>();
    repository.pending = staleResult;
    final oldRefresh = container.read(recipesProvider.notifier).refresh();
    repository.deletion!.complete();
    await tester.pumpAndSettle();
    staleResult.complete(staleRecipes);
    await oldRefresh;
    repository.pending = null;
    await tester.pumpAndSettle();
    expect(container.read(recipesProvider).value, isEmpty);
    router.go('/recipes/$recipeId');
    await tester.pumpAndSettle();
    expect(find.text('Could not load this recipe.'), findsOneWidget);
    expect(find.text('Best Lentil Soup'), findsNothing);
    expect(repository.detailCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail uses confirmed favorite and accepts later list updates', (
    tester,
  ) async {
    final repository = DelayedRecipeRepository()..favorite = Completer<bool>();
    final container = await mount(
      tester,
      TestAuthRepository(testSession()),
      repository,
    );
    container.read(appRouterProvider).go('/recipes/$recipeId');
    await tester.pumpAndSettle();
    await tester.tap(action('Add favorite'));
    await tester.pumpAndSettle();
    expect(action('Remove favorite'), findsOneWidget);
    // The server can disagree with the optimistic value after another client's change.
    repository.favorite!.complete(false);
    await tester.pumpAndSettle();
    expect(action('Add favorite'), findsOneWidget);
    repository.data = [repository.data.single.copyWith(isFavorited: true)];
    await container.read(recipesProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(action('Remove favorite'), findsOneWidget);
  });

  for (final delete in [false, true]) {
    testWidgets(
      'late mutation cannot change another account (delete=$delete)',
      (tester) async {
        final first = DelayedRecipeRepository()
          ..favorite = Completer<bool>()
          ..deletion = Completer<void>();
        final second = DelayedRecipeRepository();
        second.data = [second.data.single.copyWith(isFavorited: true)];
        final auth = TestAuthRepository(testSession());
        final container = await mount(tester, auth, first, otherUser: second);
        final notifier = container.read(recipesProvider.notifier);
        final pending = delete
            ? notifier.deleteRecipe(recipeId)
            : notifier.toggleFavorite(first.data.single);
        auth.emit(testSession(id: 'user-b', token: 'token-b'));
        await tester.pumpAndSettle();
        if (delete) {
          first.deletion!.complete();
        } else {
          first.favorite!.completeError(
            const RecipeException('Old request failed'),
          );
        }
        await pending;
        await tester.pumpAndSettle();
        final current = container.read(recipesProvider).value!;
        expect(current, hasLength(1));
        expect(current.single.isFavorited, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final delete in [false, true]) {
    testWidgets(
      'direct detail mutation does not strand the initial list (delete=$delete)',
      (tester) async {
        final repository = DelayedRecipeRepository()
          ..favorite = Completer<bool>()
          ..deletion = Completer<void>();
        final oldRecipes = List<Recipe>.of(repository.data);
        final firstLoad = Completer<List<Recipe>>();
        repository.pending = firstLoad;
        final container = await mount(
          tester,
          TestAuthRepository(testSession()),
          repository,
          initialRoute: '/recipes/$recipeId',
        );
        expect(find.text('Best Lentil Soup'), findsOneWidget);
        expect(container.read(recipesProvider).isLoading, isTrue);
        if (delete) {
          await tester.tap(action('Delete recipe'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        } else {
          await tester.tap(action('Add favorite'));
        }
        await tester.pumpAndSettle();
        container.read(appRouterProvider).go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        if (delete) {
          repository.pending = null;
          repository.deletion!.complete();
          await tester.pumpAndSettle();
          expect(container.read(recipesProvider).value, isEmpty);
        } else {
          repository.favorite!.completeError(
            const RecipeException('Favorite failed'),
          );
          await tester.pump();
        }
        firstLoad.complete(oldRecipes);
        await tester.pumpAndSettle();
        final recipes = container.read(recipesProvider);
        expect(recipes.isLoading, isFalse);
        if (delete) {
          expect(recipes.value, isEmpty);
        } else {
          expect(recipes.value!.single.isFavorited, isFalse);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('token refresh keeps servings and ingredient checkoff', (
    tester,
  ) async {
    final repository = DelayedRecipeRepository();
    final auth = TestAuthRepository(testSession());
    final container = await mount(tester, auth, repository);
    container.read(appRouterProvider).go('/recipes/$recipeId');
    await tester.pumpAndSettle();
    await tester.tap(action('Increase servings'));
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is AppAction &&
                widget.checked != null &&
                widget.label == null,
          )
          .first,
    );
    await tester.pumpAndSettle();
    auth.emit(testSession(token: 'refreshed-token'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ServingsStepper>(find.byType(ServingsStepper)).value,
      5,
    );
    expect(
      tester
          .widget<IngredientCheckbox>(find.byType(IngredientCheckbox).first)
          .checked,
      isTrue,
    );
    expect(repository.detailCalls, 2);
  });

  testWidgets('token refresh retries a failed recipe detail request', (
    tester,
  ) async {
    final repository = DelayedRecipeRepository()..failDetail = true;
    final auth = TestAuthRepository(testSession());
    final container = await mount(tester, auth, repository);
    container.read(appRouterProvider).go('/recipes/$recipeId');
    await tester.pumpAndSettle();
    expect(find.text('Could not load this recipe.'), findsOneWidget);
    repository.failDetail = false;
    auth.emit(testSession(token: 'refreshed-token'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this recipe.'), findsNothing);
    expect(find.text('Best Lentil Soup'), findsOneWidget);
    expect(repository.detailCalls, 2);
  });
}
