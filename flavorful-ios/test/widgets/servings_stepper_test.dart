import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/widgets/servings_stepper.dart';

void main() {
  Future<void> pumpStepper(
    WidgetTester tester, {
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServingsStepper(value: value, onChanged: onChanged),
        ),
      ),
    );
  }

  testWidgets('shows the current value', (tester) async {
    await pumpStepper(tester, value: 4, onChanged: (_) {});
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('increment reports value + 1', (tester) async {
    int? changed;
    await pumpStepper(tester, value: 4, onChanged: (v) => changed = v);
    await tester.tap(find.text('+'));
    expect(changed, 5);
  });

  testWidgets('decrement reports value - 1', (tester) async {
    int? changed;
    await pumpStepper(tester, value: 4, onChanged: (v) => changed = v);
    await tester.tap(find.text('−'));
    expect(changed, 3);
  });

  testWidgets('decrement is disabled at the minimum', (tester) async {
    int? changed;
    await pumpStepper(tester, value: 1, onChanged: (v) => changed = v);
    await tester.tap(find.text('−'));
    expect(changed, isNull);
  });
}
