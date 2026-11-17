import 'package:flutter/foundation.dart';
// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'routing.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  if (!AppConfig.useMockData) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // The web callback route owns its exchange. Native links stay automatic.
        detectSessionInUri: !kIsWeb,
      ),
    );
  }
  runApp(const ProviderScope(child: FlavorfulApp()));
}

class FlavorfulApp extends ConsumerWidget {
  const FlavorfulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.useMockData ? 'Flavorful — Offline demo' : 'Flavorful',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgPage,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandGreen,
          brightness: Brightness.light,
        ),
        fontFamily: AppFonts.sans,
      ),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => Column(
        children: [
          if (AppConfig.useMockData)
            Material(
              color: AppColors.surfaceParchment,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Offline demo · Sample data only',
                      textAlign: TextAlign.center,
                      style: AppText.metaMono(),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: child!),
        ],
      ),
    );
  }
}
