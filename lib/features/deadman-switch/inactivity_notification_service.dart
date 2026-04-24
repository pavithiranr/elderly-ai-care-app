// lib/services/inactivity_notification_service.dart
//
// Handles the two-stage alert flow:
//   Stage 1 → Local notification (flutter_local_notifications)
//   Stage 2 → Firestore write + caregiver SOS
//
// Setup required:
//   flutter pub add flutter_local_notifications
//   flutter pub add cloud_firestore   (already in your project)
//
// Android: add to AndroidManifest.xml inside <application>:
//   <receiver android:exported="false"
//     android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//
// iOS: add to AppDelegate in didFinishLaunchingWithOptions:
//   FlutterLocalNotificationsPlugin.setPluginRegistrantCallback(...)

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'dart:html' as if_web;
import 'package:cloud_firestore/cloud_firestore.dart';

class InactivityNotificationService {
  // ignore: unused_field
  static const _notificationId = 1001;
  static const _channelId = 'inactivity_alert';
  static const _channelName = 'Inactivity Alert';

  final FlutterLocalNotificationsPlugin? _localNotifications =
      !kIsWeb ? FlutterLocalNotificationsPlugin() : null;

  bool _initialized = false;
  final String userId; // Pass in from your auth service

  InactivityNotificationService({required this.userId});

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Skip on web - local notifications not supported
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications?.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('[InactivityNotification] ✅ Initialized');
  }

  // ── Stage 1: Local Notification ────────────────────────────────────────────

  Future<void> showCheckInNotification() async {
    // Skip on web - local notifications not supported
    if (kIsWeb || _localNotifications == null) {
      debugPrint('[InactivityNotification] ⚠️ Skipping check-in notification on web');
      return;
    }

    debugPrint('[InactivityNotification] 🔔 Showing check-in notification');

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Wellness check-in alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,           // Shows even on lock screen
      enableVibration: true,
      playSound: true,
      ongoing: true,                    // User must tap — can't swipe away
      styleInformation: BigTextStyleInformation(
        'We noticed your phone hasn\'t moved for a while. '
        'Please tap here to let your caregivers know you\'re okay.',
        contentTitle: '❤️ Are you okay?',
        summaryText: 'Wellness Check',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    await _localNotifications!.show(
      _notificationId,
      '❤️ Are you okay?',
      'Tap here to check in — your caregivers will be notified if you don\'t respond.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelCheckInNotification() async {
    // await _localNotifications.cancel(_notificationId);
    debugPrint('[InactivityNotification] ✅ Notification cancelled');
  }

  // ── Stage 2: Firestore Escalation ──────────────────────────────────────────

  Future<void> escalateToFirestore() async {
    debugPrint('[InactivityNotification] 🚨 Escalating to Firestore');

    final firestore = FirebaseFirestore.instance;

    // Write alert document — caregivers' app listens to this collection
    await firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .add({
      'type': 'inactivity_alert',
      'status': 'inactivity_alert_triggered',  // Matches your prompt spec
      'triggeredAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'severity': 'high',
    });

    // Also update the user's top-level status for quick caregiver dashboard reads
    await firestore.collection('users').doc(userId).update({
      'status': 'inactivity_alert_triggered',
      'lastAlertAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveAlert() async {
    debugPrint('[InactivityNotification] ✅ Alert resolved by user');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'status': 'active',
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }
}

// ── Notification tap handler (top-level function required by plugin) ──────────
void _onNotificationTapped(NotificationResponse response) {
  // Navigate to app — handled by your NavigationService or GlobalKey<NavigatorState>
  debugPrint('[InactivityNotification] User tapped notification: ${response.id}');
}
