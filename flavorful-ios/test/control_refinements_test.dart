// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:flavorful/models/recipe.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/routing.dart';
import 'package:flavorful/theme/tokens.dart';
import 'package:flavorful/widgets/app_action.dart';
import 'package:flavorful/widgets/save_island.dart';
import 'package:flavorful/widgets/url_paste_field.dart';

import 'responsive_app_test.dart' show mountApp;
import 'test_support.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('favorite does not reduce title width at $width', (
      tester,
    ) async {
      final recipes = TestRecipeRepository();
      recipes.data = [
        Recipe.fromBackendRow({
          'recipe_id': 'long-title',
          'public_url': 'https://example.com/recipe',
          'recipe_metadata': {
            'recipe_name': 'A long recipe title that needs the available space',
            'description': 'Recipe description.',
          },
        }),
      ];
      final container = await mountApp(
        tester,
        Size(width, 900),
        recipes: recipes,
      );
      container.read(appRouterProvider).go('/recipes/long-title');
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('recipe-title'));
      final favorite = find.byWidgetPredicate(
        (w) => w is AppAction && w.label == 'Add favorite',
      );
      expect(
        tester.getRect(favorite).bottom,
        lessThan(tester.getRect(title).top),
      );
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(
        paragraph.constraints.maxWidth,
        closeTo((width < 1100 ? width : 1100) - 40, 0.1),
      );
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is AppAction && w.label == 'Remove favorite',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(1440, 900), const Size(800, 280)]) {
    testWidgets('profile panel has margins at ${size.width} x ${size.height}', (
      tester,
    ) async {
      await mountApp(tester, size);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppAction && w.label == 'Open profile',
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('profile-panel'));
      final rect = tester.getRect(panel);
      expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
      expect(rect.top, greaterThanOrEqualTo(24));
      final decoration =
          tester.widget<Container>(panel).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(24));
      await tester.ensureVisible(find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      final confirmation = tester.getRect(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Material && widget.type == MaterialType.card,
              ),
            )
            .first,
      );
      expect(confirmation.top, greaterThanOrEqualTo(24));
      expect(confirmation.bottom, lessThanOrEqualTo(size.height - 24));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final legacy in [false, true]) {
    testWidgets('URL keeps the app font while saving (legacy=$legacy)', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      const url = 'https://example.com/a-recipe';
      Widget form(AddStatus status) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
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
      await tester.pumpWidget(form(AddStatus.idle));
      await tester.enterText(find.byType(TextField), url);
      final editing = tester.widget<TextField>(find.byType(TextField)).style!;
      await tester.pumpWidget(form(AddStatus.saving));
      final saving = tester.widget<Text>(find.text(url)).style!;
      expect(editing.fontFamily, AppFonts.sans);
      expect(saving.fontFamily, editing.fontFamily);
      expect(saving.fontSize, editing.fontSize);
      expect(saving.fontWeight, editing.fontWeight);
      expect(saving.height, editing.height);
      expect(tester.takeException(), isNull);
    });
  }
}
