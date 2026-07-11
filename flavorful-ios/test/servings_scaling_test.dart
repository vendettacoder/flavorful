import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/models/recipe.dart';

void main() {
  group('Ingredient.scaledQuantityLabel', () {
    const oliveOil = Ingredient(
      quantityRaw: '¼ cup',
      quantityValue: 0.25,
      unit: 'cup',
      name: 'olive oil',
    );

    test('doubling 4→8 servings doubles the quantity', () {
      // factor = 8 / 4 = 2
      expect(oliveOil.scaledQuantityLabel(2), '½ cup');
    });

    test('unchanged servings keep the original', () {
      expect(oliveOil.scaledQuantityLabel(1), '¼ cup');
    });

    test('count nouns scale without a unit', () {
      const onion = Ingredient(quantityRaw: '1', quantityValue: 1, name: 'onion');
      expect(onion.scaledQuantityLabel(3), '3');
    });

    test('unscalable ingredients return their raw quantity', () {
      const pinch = Ingredient(quantityRaw: '1 pinch', name: 'salt');
      expect(pinch.scaledQuantityLabel(2), '1 pinch');
    });

    test('halving produces a clean fraction', () {
      const lentils = Ingredient(
        quantityRaw: '1 cup',
        quantityValue: 1,
        unit: 'cup',
        name: 'brown lentils',
      );
      expect(lentils.scaledQuantityLabel(0.5), '½ cup');
    });
  });

  group('hostnameFromUrl', () {
    test('strips scheme, www, and path', () {
      expect(
        hostnameFromUrl('https://www.cookieandkate.com/best-lentil-soup/'),
        'cookieandkate.com',
      );
    });

    test('handles missing scheme', () {
      expect(hostnameFromUrl('smittenkitchen.com/gnocchi'), 'smittenkitchen.com');
    });
  });

  group('Ingredient.fromBackendObject (structured, scalable)', () {
    test('numeric quantity scales with the serving factor', () {
      final ing = Ingredient.fromBackendObject(
          {'quantity': 0.25, 'unit': 'cup', 'name': 'olive oil', 'note': ''});
      expect(ing.scaledQuantityLabel(1), '¼ cup');
      expect(ing.scaledQuantityLabel(2), '½ cup'); // 4 → 8 servings
      expect(ing.scaledQuantityLabel(0.5), '⅛ cup');
      expect(ing.sideNote, isNull);
    });

    test('count noun with no unit scales without a unit', () {
      final ing = Ingredient.fromBackendObject(
          {'quantity': 1, 'unit': '', 'name': 'onion', 'note': 'finely chopped'});
      expect(ing.scaledQuantityLabel(3), '3');
      expect(ing.sideNote, 'finely chopped');
    });

    test('null quantity is not scaled', () {
      final ing = Ingredient.fromBackendObject(
          {'quantity': null, 'unit': '', 'name': 'salt', 'note': 'to taste'});
      expect(ing.scaledQuantityLabel(3), '');
      expect(ing.sideNote, 'to taste');
    });
  });
}
