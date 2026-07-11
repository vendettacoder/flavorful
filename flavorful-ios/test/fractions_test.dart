import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/util/fractions.dart';

void main() {
  group('formatQuantity', () {
    test('whole numbers render without a fraction', () {
      expect(formatQuantity(1), '1');
      expect(formatQuantity(2), '2');
      expect(formatQuantity(12), '12');
    });

    test('common fractions map to glyphs', () {
      expect(formatQuantity(0.5), '½');
      expect(formatQuantity(0.25), '¼');
      expect(formatQuantity(0.75), '¾');
      expect(formatQuantity(0.125), '⅛');
    });

    test('thirds snap to glyphs', () {
      expect(formatQuantity(1 / 3), '⅓');
      expect(formatQuantity(2 / 3), '⅔');
    });

    test('mixed numbers combine whole + fraction', () {
      expect(formatQuantity(1.25), '1¼');
      expect(formatQuantity(1.5), '1½');
      expect(formatQuantity(2.75), '2¾');
    });

    test('non-positive values render empty', () {
      expect(formatQuantity(0), '');
      expect(formatQuantity(-1), '');
    });

    test('values near a whole number round to it', () {
      expect(formatQuantity(1.99), '2');
      expect(formatQuantity(3.005), '3');
    });

    test('values with no clean fraction fall back to a tidy decimal', () {
      expect(formatQuantity(0.2), '0.2');
    });
  });
}
