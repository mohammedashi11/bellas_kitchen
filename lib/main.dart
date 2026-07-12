import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router_provider.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the FlutterFire-generated options. Guarded so a
  // failure here (misconfiguration, unsupported platform) never blocks launch:
  // repositories fall back gracefully (mock menu, degraded auth) so the app
  // still runs.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase.initializeApp succeeded.');
  } catch (e, stack) {
    debugPrint('Firebase.initializeApp failed: $e');
    debugPrintStack(stackTrace: stack);
  }

  runApp(
    const ProviderScope(
      child: BellasKitchenApp(),
    ),
  );
}

class BellasKitchenApp extends ConsumerWidget {
  const BellasKitchenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: "Bella's Kitchen",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
