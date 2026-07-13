import 'package:flavorful/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('servingsKnownFrom', () {
    test('real counts are known', () {
      expect(servingsKnownFrom(4), isTrue);
      expect(servingsKnownFrom('4'), isTrue);
      expect(servingsKnownFrom('4 servings'), isTrue);
      expect(servingsKnownFrom('Serves 6'), isTrue);
    });

    test('missing / empty / non-numeric are unknown', () {
      expect(servingsKnownFrom(null), isFalse);
      expect(servingsKnownFrom(''), isFalse);
      expect(servingsKnownFrom('   '), isFalse);
      expect(servingsKnownFrom('adjust servings'), isFalse);
    });

    test('zero / negative are unknown (would fall back to 1)', () {
      expect(servingsKnownFrom(0), isFalse);
      expect(servingsKnownFrom('0'), isFalse);
    });

    test('pairs with parseServings: unknown values still parse to 1', () {
      expect(parseServings(null), 1);
      expect(servingsKnownFrom(null), isFalse);
      expect(parseServings('4 servings'), 4);
      expect(servingsKnownFrom('4 servings'), isTrue);
    });
  });

  group('Recipe.fromBackendRow servingsKnown', () {
    Map<String, dynamic> row(Object? servings) => {
          'recipe_id': 'r1',
          'public_url': 'https://example.com/x',
          'recipe_metadata': {
            'recipe_name': 'Test',
            'servings': servings,
            'ingredients': const [],
            'method': const [],
          },
        };

    test('known when the page gave a count', () {
      final r = Recipe.fromBackendRow(row('4'));
      expect(r.servings, 4);
      expect(r.servingsKnown, isTrue);
    });

    test('unknown when the page gave none (defaults to 1, hidden in UI)', () {
      final r = Recipe.fromBackendRow(row(null));
      expect(r.servings, 1);
      expect(r.servingsKnown, isFalse);
    });
  });
}
