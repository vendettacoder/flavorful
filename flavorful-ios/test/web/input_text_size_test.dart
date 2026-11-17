import 'package:flutter/foundation.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/widgets/save_island.dart';
import 'package:flavorful/widgets/url_paste_field.dart';

import '../responsive_app_test.dart' show mountApp;

void main() {
  for (final width in [320.0, 402.0, 1440.0]) {
    testWidgets('web inputs use 16-pixel text at width $width', (tester) async {
      await mountApp(tester, Size(width, 900));
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.style!.fontSize, 16);
        expect(field.decoration!.hintStyle!.fontSize, 16);
      }
      final url = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.keyboardType == TextInputType.url,
      );
      await tester.enterText(url, 'https://example.com/recipe');
      await tester.enterText(
        find.widgetWithText(TextField, 'Search recipes'),
        'Lentil',
      );
      await tester.pumpAndSettle();
      expect(find.text('Best Lentil Soup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: !kIsWeb);
  }

  for (final legacy in [false, true]) {
    testWidgets('web URL size stays stable in every state (legacy=$legacy)', (
      tester,
    ) async {
      const url = 'https://example.com/recipe';
      final controller = TextEditingController(text: url);
      addTearDown(controller.dispose);
      Widget form(AddStatus status) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: legacy
                ? UrlPasteField(
                    controller: controller,
                    status: status,
                    pastedUrl: url,
                    onSubmitted: (_) {},
                    onRetry: () {},
                  )
                : SaveIsland(
                    controller: controller,
                    status: status,
                    pastedUrl: url,
                    onSubmitted: (_) {},
                    onRetry: () {},
                    onSave: () {},
                  ),
          ),
        ),
      );
      for (final status in [AddStatus.idle, AddStatus.error]) {
        await tester.pumpWidget(form(status));
        final input = tester.widget<TextField>(find.byType(TextField));
        expect(input.style!.fontSize, 16);
        expect(input.decoration!.hintStyle!.fontSize, 16);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(form(AddStatus.saving));
      expect(tester.widget<Text>(find.text(url)).style!.fontSize, 16);
      expect(tester.takeException(), isNull);
    }, skip: !kIsWeb);
  }
}
