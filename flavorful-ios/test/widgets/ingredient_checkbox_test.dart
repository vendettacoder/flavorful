import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/widgets/ingredient_checkbox.dart';

void main() {
  testWidgets('tapping an unchecked box reports true', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientCheckbox(checked: false, onChanged: (v) => changed = v),
        ),
      ),
    );
    await tester.tap(find.byType(IngredientCheckbox));
    expect(changed, true);
  });

  testWidgets('checked box shows the ✓ glyph and reports false on tap',
      (tester) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientCheckbox(checked: true, onChanged: (v) => changed = v),
        ),
      ),
    );
    expect(find.text('✓'), findsOneWidget);
    await tester.tap(find.byType(IngredientCheckbox));
    expect(changed, false);
  });
}
