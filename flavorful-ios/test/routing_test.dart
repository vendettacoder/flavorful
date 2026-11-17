import 'package:flavorful/main.dart';
import 'package:flavorful/providers/providers.dart';
import 'package:flavorful/routing.dart';
import 'package:flavorful/screens/library_screen.dart';
import 'package:flavorful/screens/recipe_detail_screen.dart';
import 'package:flavorful/screens/sign_in_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester,
    TestAuthRepository auth,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recipeRepositoryProvider.overrideWithValue(TestRecipeRepository()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.changes.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FlavorfulApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('protected direct URL returns to detail after sign-in', (
    tester,
  ) async {
    final auth = TestAuthRepository();
    final container = await mount(tester, auth);
    final router = container.read(appRouterProvider);
    router.go('/recipes/r-lentil-soup');
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(
      find.text('Continue with Apple'),
      kIsWeb ? findsNothing : findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/recipes/r-lentil-soup',
    );
    auth.emit(testSession());
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/recipes/r-lentil-soup',
    );
    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(RecipeDetailScreen), findsNothing);
  });

  testWidgets(
    'SDK callback success removes query and restores safe destination',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        signInDestinationKey: '/recipes/r-lentil-soup',
      });
      final auth = TestAuthRepository();
      final container = await mount(tester, auth);
      final router = container.read(appRouterProvider);
      router.go('/auth/callback?code=test-code');
      await tester.pumpAndSettle();
      expect(auth.callback?.queryParameters['code'], 'test-code');
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/recipes/r-lentil-soup',
      );
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
    },
  );

  testWidgets('callback failure has a sign-in recovery action', (tester) async {
    final auth = TestAuthRepository()..failCallback = true;
    final container = await mount(tester, auth);
    container.read(appRouterProvider).go('/auth/callback?error=access_denied');
    await tester.pumpAndSettle();
    expect(
      find.text('Sign-in did not complete. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to sign-in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('unknown routes show not-found and return to cookbook', (
    tester,
  ) async {
    final container = await mount(tester, TestAuthRepository(testSession()));
    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();
    expect(find.text('Page not found.'), findsOneWidget);
    await tester.tap(find.text('Back to cookbook'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  if (!kIsWeb) {
    for (final callback in [
      'flavorful://login-callback?code=native-test',
      '/login-callback?code=native-test',
      '/?code=native-test',
    ]) {
      testWidgets('native callback keeps SDK-owned sign-in: $callback', (
        tester,
      ) async {
        final auth = TestAuthRepository();
        final container = await mount(tester, auth);
        final router = container.read(appRouterProvider);
        router.go(callback);
        await tester.pumpAndSettle();
        auth.emit(testSession());
        await tester.pumpAndSettle();
        expect(find.byType(LibraryScreen), findsOneWidget);
        expect(auth.callback, isNull);
        expect(router.routeInformationProvider.value.uri.path, '/');
      });
    }
  }

  test('sign-in destination rejects outside URLs and callback loops', () {
    for (final path in [
      'https://example.com',
      '//example.com',
      '/auth/callback',
      '/sign-in',
    ]) {
      expect(signInDestination(path), '/');
    }
    expect(signInDestination('/recipes/123?secret=discard'), '/recipes/123');
  });
}
