import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles FCM token management and local notification display.
///
/// Flow:
///   1. Call [init] once at app start (before runApp).
///   2. After a user logs in, call [saveTokenForUser] with their Firestore UID.
///   3. The caregiver dashboard calls [showSosNotification] when it detects
///      a new SOS alert from Firestore — no server needed for the demo.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _channelId = 'caresync_alerts';
  static const _channelName = 'CareSync Alerts';
  static const _channelDesc = 'SOS and health alerts from elderly patients';

  // ── Initialise ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _initLocalNotifications();
    await _requestPermission();
    _listenToForegroundMessages();
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the high-importance Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    debugPrint(
        'NotificationService: permission = ${settings.authorizationStatus}');
  }

  /// Listen to FCM messages while the app is in the foreground.
  /// (Background/terminated messages are handled by FCM automatically
  /// once a server sends them — infrastructure is already wired.)
  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        show(
          title: notification.title ?? 'CareSync Alert',
          body: notification.body ?? '',
          id: message.hashCode,
        );
      }
    });
  }

  // ── Token Management ───────────────────────────────────────────────────────

  /// Save the device FCM token to Firestore under the user's profile.
  /// Call this right after a successful caregiver login / elderly setup.
  /// [collection] is either 'caregivers' or 'elderly'.
  Future<void> saveTokenForUser(String uid, {String collection = 'caregivers'}) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _firestore.collection(collection).doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('NotificationService: FCM token saved for $uid');

      // Refresh token when it rotates
      _messaging.onTokenRefresh.listen((newToken) async {
        await _firestore.collection(collection).doc(uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('NotificationService: failed to save token — $e');
    }
  }

  // ── Show Local Notifications ───────────────────────────────────────────────

  /// Show a local notification immediately (use for Firestore-triggered alerts).
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Convenience: fire an SOS notification for a named patient.
  Future<void> showSosNotification(String patientName) => show(
        id: 911,
        title: '🚨 SOS Alert — $patientName',
        body: '$patientName has triggered an emergency alert. Please respond immediately.',
      );

  /// Convenience: fire a missed check-in reminder.
  Future<void> showMissedCheckinNotification(String patientName) => show(
        id: 100,
        title: 'Missed Check-in — $patientName',
        body: '$patientName has not completed today\'s check-in. Please follow up.',
      );
}
