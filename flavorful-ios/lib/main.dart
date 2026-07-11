import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'providers/providers.dart';
import 'screens/library_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase for live auth; skipped in mock/offline mode.
  if (!AppConfig.useMockData) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: FlavorfulApp()));
}

class FlavorfulApp extends StatelessWidget {
  const FlavorfulApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        brightness: Brightness.light,
      ),
      fontFamily: AppFonts.sans,
    );

    return MaterialApp(
      title: 'Flavorful',
      debugShowCheckedModeBanner: false,
      // Dark mode is not designed for v1 — force light.
      themeMode: ThemeMode.light,
      theme: theme,
      home: const _AuthGate(),
      // The OS pushes the OAuth callback (e.g. "/?code=...") as a named route.
      // Supabase already handles the session via authStateChanges, so just
      // resolve any such route back to the gate instead of crashing.
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => const _AuthGate()),
      // Cap content width so the phone-designed UI stays a clean centered
      // column on iPad/large screens instead of stretching edge-to-edge.
      // No effect on phones (all narrower than 520pt). The surround uses the
      // app background so the letterbox is seamless.
      builder: (context, child) => ColoredBox(
        color: AppColors.bgPage,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Routes to the sign-in or library screen based on session state.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    return session.when(
      loading: () => const _Splash(),
      error: (_, _) => const SignInScreen(),
      data: (s) => s == null ? const SignInScreen() : const LibraryScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.brandGreen,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.onGreen),
      ),
    );
  }
}
