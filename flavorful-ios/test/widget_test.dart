import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/data/auth_repository.dart';
import 'package:flavorful/data/mock_recipe_repository.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/screens/library_screen.dart';
import 'package:flavorful/widgets/recipe_card.dart';

void main() {
  testWidgets('Library loads sample recipes from the mock repository',
      (tester) async {
    // Tall phone-shaped surface so the lazy ListView builds all four cards.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        // Force mock repos so the test stays offline (live mode needs Supabase).
        overrides: [
          recipeRepositoryProvider
              .overrideWith((ref) => MockRecipeRepository()),
          authRepositoryProvider.overrideWith((ref) => MockAuthRepository()),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );

    // Initial frame shows the loading state, then the mock resolves.
    await tester.pumpAndSettle();

    expect(find.text('Save a recipe'), findsOneWidget);
    expect(find.text('Cookbook'), findsOneWidget);
    expect(find.text('4 recipes'), findsOneWidget);

    // The four sample cards are present.
    expect(find.byType(RecipeCard), findsNWidgets(4));
    expect(find.text('Best Lentil Soup'), findsOneWidget);
  });
}
