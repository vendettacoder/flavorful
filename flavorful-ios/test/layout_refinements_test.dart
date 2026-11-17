// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/routing.dart';
import 'package:flavorful/widgets/account_avatar.dart';
import 'package:flavorful/widgets/ingredient_checkbox.dart';
import 'package:flavorful/widgets/recipe_card.dart';
import 'package:flavorful/widgets/save_island.dart';

import 'responsive_app_test.dart' show mountApp;
import 'test_support.dart';

Recipe cardRecipe(
  String id,
  String title,
  String description, {
  bool nutrition = false,
}) => Recipe.fromBackendRow({
  'recipe_id': id,
  'public_url': 'https://example.com/$id',
  'recipe_metadata': {
    'recipe_name': title,
    'description': description,
    if (nutrition) 'nutrition_information': {'Calories': '320 kcal'},
  },
});

void main() {
  testWidgets('desktop sign-in panel has a bottom margin and rounded corners', (
    tester,
  ) async {
    await mountApp(tester, const Size(1440, 1000), signedIn: false);
    final panel = find.byKey(const ValueKey('sign-in-panel'));
    expect(tester.getRect(panel).bottom, lessThanOrEqualTo(976));
    final decoration =
        tester.widget<Container>(panel).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 800.0, 1440.0]) {
    testWidgets('save panel and cookbook share both edges at width $width', (
      tester,
    ) async {
      await mountApp(tester, Size(width, 1100));
      final save = tester.getRect(find.byType(SaveIsland));
      final cards = find.byType(RecipeCard);
      final columns = width >= 1100
          ? 3
          : width >= 700
          ? 2
          : 1;
      expect(save.left, closeTo(tester.getRect(cards.first).left, 0.1));
      expect(
        save.right,
        closeTo(tester.getRect(cards.at(columns - 1)).right, 0.1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('cards reserve equal text space at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipes = [
        cardRecipe('short', 'Soup', 'Short description.'),
        cardRecipe(
          'long',
          'A long title ' * 15,
          'A long description. ' * 50,
          nutrition: true,
        ),
        cardRecipe('empty', 'No description', ''),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final recipe in recipes)
                      SizedBox(width: 280, child: RecipeCard(recipe: recipe)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final cards = find.byType(RecipeCard);
      final height = tester.getSize(cards.first).height;
      for (var i = 1; i < recipes.length; i++) {
        expect(tester.getSize(cards.at(i)).height, closeTo(height, 0.1));
      }
      expect(tester.widget<Text>(find.text(recipes[1].title)).maxLines, 2);
      expect(
        tester.widget<Text>(find.text(recipes[1].description)).maxLines,
        3,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide recipe headings align and nutrition follows both columns', (
    tester,
  ) async {
    final recipes = TestRecipeRepository();
    final container = await mountApp(
      tester,
      const Size(1200, 900),
      recipes: recipes,
    );
    container.read(appRouterProvider).go('/recipes/r-lentil-soup');
    await tester.pumpAndSettle();
    final ingredients = tester.getRect(find.text('Ingredients'));
    final method = tester.getRect(find.text('Method'));
    final notes = tester.getRect(find.text('Notes'));
    final nutrition = tester.getRect(find.text('Nutrition'));
    final recipe = recipes.data.firstWhere((r) => r.id == 'r-lentil-soup');
    final lastNote = tester.getRect(
      find.textContaining(recipe.notesFromPage.last.body, findRichText: true),
    );
    final lastIngredient = tester.getRect(find.byType(IngredientCheckbox).last);
    expect(ingredients.top, closeTo(method.top, 0.1));
    expect(notes.left, closeTo(method.left, 0.1));
    expect(notes.top, greaterThan(method.bottom));
    expect(nutrition.left, closeTo(ingredients.left, 0.1));
    expect(nutrition.top, greaterThan(lastNote.bottom));
    expect(nutrition.top, greaterThan(lastIngredient.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar retains initial when no profile photo is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountAvatar(initial: 'R')),
    );
    expect(find.text('R'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
