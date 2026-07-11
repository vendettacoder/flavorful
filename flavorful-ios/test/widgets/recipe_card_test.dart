import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/widgets/recipe_card.dart';

Recipe _recipe({bool favorited = false}) => Recipe(
      id: 'r1',
      url: 'https://cookieandkate.com/best-lentil-soup/',
      hostname: 'cookieandkate.com',
      title: 'Best Lentil Soup',
      description: 'Curry powder, lemon, and a creamy blended finish.',
      totalMinutes: 55,
      servings: 4,
      ingredients: const [],
      method: const [],
      notesFromPage: const [],
      isFavorited: favorited,
      savedAt: DateTime(2026, 6, 20),
    );

void main() {
  testWidgets('renders title, hostname, and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RecipeCard(recipe: _recipe()))),
    );
    expect(find.text('Best Lentil Soup'), findsOneWidget);
    expect(find.text('COOKIEANDKATE.COM'), findsOneWidget);
    expect(find.text('55 min'), findsOneWidget);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeCard(recipe: _recipe(), onTap: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.byType(RecipeCard));
    expect(tapped, isTrue);
  });
}
