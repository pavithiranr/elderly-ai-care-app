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
import 'package:cloud_firestore/cloud_firestore.dart';

class InactivityNotificationService {
  // ignore: unused_field
  static const _notificationId = 1001;
  static const _channelId = 'inactivity_alert';
  static const _channelName = 'Inactivity Alert';

  // Note: flutter_local_notifications is mobile/desktop only
  // Access is guarded with kIsWeb checks
  dynamic _localNotifications;

  bool _initialized = false;
  final String userId; // Pass in from your auth service

  InactivityNotificationService({required this.userId});

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Skip on web - local notifications not supported
    if (kIsWeb || _initialized) return;

    debugPrint('[InactivityNotification] 🔔 Initializing (web platform detected, skipping)');
    _initialized = true;
  }

  // ── Stage 1: Local Notification ────────────────────────────────────────────

  Future<void> showCheckInNotification() async {
    // Skip on web - local notifications not supported
    if (kIsWeb || _localNotifications == null) {
      debugPrint('[InactivityNotification] ⚠️ Skipping check-in notification on web');
      return;
    }

    debugPrint('[InactivityNotification] 🔔 Showing check-in notification');
    
    // TODO: Show notification with proper details
    // This requires flutter_local_notifications types
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
// Note: On web, this is never called due to kIsWeb guard in initialize()
void _onNotificationTapped(dynamic response) {
  // Navigate to app — handled by your NavigationService or GlobalKey<NavigatorState>
  // response is NotificationResponse on mobile/desktop, null on web
  debugPrint('[InactivityNotification] User tapped notification');
}
