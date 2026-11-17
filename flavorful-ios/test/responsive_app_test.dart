// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/main.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/routing.dart';
import 'package:flavorful/widgets/app_action.dart';
import 'package:flavorful/widgets/ingredient_checkbox.dart';
import 'package:flavorful/widgets/recipe_card.dart';
import 'package:flavorful/widgets/servings_stepper.dart';

import 'test_support.dart';

Future<ProviderContainer> mountApp(
  WidgetTester tester,
  Size size, {
  bool signedIn = true,
  TestRecipeRepository? recipes,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = TestAuthRepository(signedIn ? testSession() : null);
  addTearDown(auth.changes.close);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      recipeRepositoryProvider.overrideWithValue(
        recipes ?? TestRecipeRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
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
  for (final size in [
    const Size(320, 568),
    const Size(800, 700),
    const Size(1440, 900),
    const Size(320, 280),
  ]) {
    testWidgets('cookbook and detail fit ${size.width} x ${size.height}', (
      tester,
    ) async {
      final container = await mountApp(tester, size);
      expect(tester.takeException(), isNull);
      if (size.height > 500) {
        final cards = find.byType(RecipeCard);
        final first = tester.getRect(cards.at(0));
        if (size.width >= 700) {
          final second = tester.getRect(cards.at(1));
          expect(first.top, second.top);
          expect(second.left, greaterThan(first.right));
        } else {
          expect(first.width, size.width - 40);
        }
        if (size.width >= 1100) {
          expect(tester.getRect(cards.at(2)).top, first.top);
          expect(first.width, lessThan(400));
        }
      }
      container.read(appRouterProvider).go('/recipes/r-lentil-soup');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Best Lentil Soup'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short sign-in window scrolls to both providers', (tester) async {
    await mountApp(tester, const Size(320, 280), signedIn: false);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Cookbook'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search matches title, domain, description and clears locally', (
    tester,
  ) async {
    await mountApp(tester, const Size(1000, 900));
    final search = find.widgetWithText(TextField, 'Search recipes');
    for (final query in ['Lentil', 'cookieandkate.com', 'all winter']) {
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      expect(find.text('Best Lentil Soup'), findsOneWidget);
      expect(find.byType(RecipeCard), findsOneWidget);
    }
    await tester.enterText(search, 'nothing-matches');
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppAction && w.label == 'Clear search',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsNWidgets(4));
  });

  testWidgets('detail scales quantities and checks ingredients', (
    tester,
  ) async {
    final container = await mountApp(tester, const Size(1200, 900));
    container.read(appRouterProvider).go('/recipes/r-lentil-soup');
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('+'));
      await tester.pump();
    }
    expect(
      tester.widget<ServingsStepper>(find.byType(ServingsStepper)).value,
      8,
    );
    expect(find.textContaining('½ cup', findRichText: true), findsOneWidget);
    final ingredient = find
        .byWidgetPredicate((w) => w is AppAction && w.checked == false)
        .first;
    await tester.tap(ingredient);
    await tester.pump();
    expect(
      tester
          .widget<IngredientCheckbox>(find.byType(IngredientCheckbox).first)
          .checked,
      isTrue,
    );
    final action = tester.widget<AppAction>(ingredient);
    expect(action.onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite ordering changes without opening the recipe', (
    tester,
  ) async {
    await mountApp(tester, const Size(1200, 1000));
    final soup = find.ancestor(
      of: find.text('Best Lentil Soup'),
      matching: find.byType(RecipeCard),
    );
    final favorite = find.descendant(
      of: soup,
      matching: find.byWidgetPredicate(
        (w) => w is AppAction && w.label == 'Add favorite',
      ),
    );
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<RecipeCard>(find.byType(RecipeCard))
        .toList();
    expect(cards.take(2).every((card) => card.recipe.isFavorited), isTrue);
    expect(find.text('Cookbook'), findsOneWidget);
  });

  testWidgets('custom controls support keyboard Enter and Space', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAction(onTap: () => count++, child: const Text('Action')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(count, 2);
  });

  testWidgets('unknown servings hides stepper and long content wraps', (
    tester,
  ) async {
    final repo = TestRecipeRepository();
    repo.data = [
      Recipe.fromBackendRow({
        'recipe_id': 'long',
        'public_url': 'https://${'long' * 30}.example.com/recipe',
        'recipe_metadata': {
          'recipe_name': 'A very long recipe name ' * 12,
          'description': 'A long description. ' * 30,
          'ingredients': [
            '1 cup of flour (sifted)',
            {'quantity': 2, 'name': 'eggs'},
          ],
          'method': ['Mix slowly. ' * 40],
          'nutrition_information': {
            'A long nutrition label ' * 8: 'A long value ' * 10,
          },
        },
      }),
    ];
    final container = await mountApp(
      tester,
      const Size(320, 500),
      recipes: repo,
    );
    expect(tester.takeException(), isNull);
    container.read(appRouterProvider).go('/recipes/long');
    await tester.pumpAndSettle();
    expect(find.byType(ServingsStepper), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nutrition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
