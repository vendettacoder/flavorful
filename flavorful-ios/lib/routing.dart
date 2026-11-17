// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/providers.dart';
import 'screens/library_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme/tokens.dart';

const signInDestinationKey = 'flavorful.sign_in_destination';

/// Only local app paths can be sign-in destinations.
String signInDestination(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '/';
  if (uri.path == '/' || RegExp(r'^/recipes/[^/]+$').hasMatch(uri.path)) {
    return uri.path;
  }
  return '/';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      // This screen owns the SDK exchange, including errors and URL cleanup.
      if (path == '/auth/callback') return null;
      if (auth.isLoading) return null;
      final protected = path == '/' || path.startsWith('/recipes/');
      if (auth.valueOrNull == null && protected) {
        return Uri(
          path: '/sign-in',
          queryParameters: {'from': signInDestination(state.uri.toString())},
        ).toString();
      }
      if (auth.valueOrNull != null && path == '/sign-in') {
        return signInDestination(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SessionPage()),
      GoRoute(
        path: '/recipes/:id',
        builder: (_, state) =>
            _SessionPage(recipeId: state.pathParameters['id']),
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/auth/callback',
        builder: (_, state) => _AuthCallback(uri: state.uri),
      ),
      // Keep the existing native custom-scheme callback valid.
      GoRoute(path: '/login-callback', redirect: (_, _) => '/'),
    ],
    errorBuilder: (_, _) => const _RouteMessage(message: 'Page not found.'),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _SessionPage extends ConsumerWidget {
  const _SessionPage({this.recipeId});
  final String? recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // A different account gets new search, servings, and checkoff state.
    return recipeId == null
        ? LibraryScreen(key: ValueKey(user.userId))
        : RecipeDetailScreen(
            key: ValueKey('${user.userId}:$recipeId'),
            recipeId: recipeId!,
          );
  }
}

class _AuthCallback extends ConsumerStatefulWidget {
  const _AuthCallback({required this.uri});
  final Uri uri;
  @override
  ConsumerState<_AuthCallback> createState() => _AuthCallbackState();
}

class _AuthCallbackState extends ConsumerState<_AuthCallback> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _complete();
  }

  Future<void> _complete() async {
    try {
      await ref.read(authRepositoryProvider).completeWebSignIn(widget.uri);
      // Ensure redirect sees the exchanged session even if the stream is late.
      ref.invalidate(authControllerProvider);
      final session = await ref.read(authControllerProvider.future);
      if (session == null) throw StateError('No session');
      final prefs = await SharedPreferences.getInstance();
      final destination = signInDestination(
        prefs.getString(signInDestinationKey),
      );
      await prefs.remove(signInDestinationKey);
      if (mounted) {
        // Replace browser history too; Back must not exchange a consumed code.
        Router.neglect(context, () => context.go(destination));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const _RouteMessage(
          message: 'Sign-in did not complete. Please try again.',
          destination: '/sign-in',
          label: 'Back to sign-in',
        )
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({
    required this.message,
    this.destination = '/',
    this.label = 'Back to cookbook',
  });
  final String message;
  final String destination;
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppText.body(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(destination),
              child: Text(label),
            ),
          ],
        ),
      ),
    ),
  );
}
