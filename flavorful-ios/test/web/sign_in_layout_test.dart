import 'package:flutter/foundation.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/widgets/wordmark.dart';

import '../responsive_app_test.dart' show mountApp;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 700),
    const Size(1440, 900),
    const Size(320, 280),
  ]) {
    testWidgets('web sign-in edges align and panel stays compact at $size', (
      tester,
    ) async {
      await mountApp(tester, size, signedIn: false);
      final panel = tester.getRect(find.byKey(const ValueKey('sign-in-panel')));
      for (final heading in [
        find.byType(Wordmark),
        find.text('Just the recipe.'),
        find.text('Every time.'),
        find.text('Build your personal cookbook from recipes on the internet.'),
      ]) {
        expect(tester.getRect(heading).left, closeTo(panel.left, 0.1));
        expect(tester.getRect(heading).right, lessThanOrEqualTo(panel.right));
      }
      final privacy = tester.getRect(
        find.widgetWithText(TextButton, 'Privacy Policy'),
      );
      expect(panel.bottom - privacy.bottom, closeTo(24, 0.1));
      expect(find.text('Continue with Apple'), findsNothing);
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, skip: !kIsWeb);
  }
}
