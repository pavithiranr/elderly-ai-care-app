import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file (optional)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Note: .env file not found, continuing without it');
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Theme Provider (loads persisted settings)
  await ThemeProvider.instance.init();

  runApp(const CareSyncApp());
}

class CareSyncApp extends StatelessWidget {
  const CareSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder listens to ThemeProvider changes
    // When theme settings change, the entire MaterialApp rebuilds with new theme
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        debugPrint('🔄 Rebuilding MaterialApp with new theme...');
        
        return MaterialApp.router(
          title: 'CareSync AI',
          debugShowCheckedModeBanner: false,
          // Get theme from provider - this changes based on settings
          theme: ThemeProvider.instance.currentTheme,
          routerConfig: appRouter,
          builder: (context, child) {
            // Wrap with MediaQuery to apply text scaling system-wide
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: ThemeProvider.instance.textScaling,
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
