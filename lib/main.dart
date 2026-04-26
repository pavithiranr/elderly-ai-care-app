import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/router.dart';
import 'firebase_options.dart';
import 'shared/services/notification_service.dart';

/// Top-level FCM background handler — runs in its own isolate.
/// FCM automatically shows the system-tray notification from the payload;
/// we only need to init Firebase so Admin SDK / Firestore is available if needed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message received: ${message.messageId}');
}

/// Navigate to the caregiver alerts screen when a notification is tapped.
void _handleNotificationTap(RemoteMessage message) {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  // All alerts (SOS, inactivity, etc.) send the caregiver to the alerts screen
  context.push(AppConstants.routeCaregiverAlerts);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be registered BEFORE Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

  // App was fully terminated and user tapped the notification to open it
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleNotificationTap(initialMessage),
    );
  }

  // App was in background and user tapped the notification
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

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
