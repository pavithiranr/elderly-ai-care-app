import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/router.dart';
import 'firebase_options.dart';
import 'shared/services/notification_service.dart';

/// Must be a top-level function — called by FCM when the app is in the
/// background or terminated. Runs in an isolate, so only minimal work here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The notification is shown automatically by FCM when the app is terminated.
  // When the app is in the background we just let the system tray handle it.
  debugPrint('FCM background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background message handler BEFORE Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Load environment variables from .env file (optional)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Note: .env file not found, continuing without it');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    // Continue anyway - some features may not work but app should still display
  }

  try {
    // Initialize Theme Provider (loads persisted settings)
    await ThemeProvider.instance.init();
    debugPrint('✅ ThemeProvider initialized');
  } catch (e) {
    debugPrint('❌ ThemeProvider initialization error: $e');
  }

  try {
    // Initialize notifications (requests permission + sets up FCM listener)
    await NotificationService.instance.init();
    debugPrint('✅ NotificationService initialized');
  } catch (e) {
    debugPrint('❌ NotificationService initialization error: $e');
  }

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
                textScaler: TextScaler.linear(ThemeProvider.instance.textScaling),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
