import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

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
        '📱 NotificationService: FCM permission = ${settings.authorizationStatus}');
    
    // For Android 13+, also request notification permission
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidSettings = await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint('📱 Android notification permission: $androidSettings');
    }
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
    try {
      debugPrint('🔔 Attempting to show notification: "$title" | "$body" (ID: $id)');
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
      debugPrint('✅ Notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
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

  // ── Medication Notifications ───────────────────────────────────────────────

  /// Schedule recurring medication notifications for each time.
  /// 
  /// Parameters:
  /// - [medicationId]: Unique identifier for the medication (used as notification ID base)
  /// - [medicationName]: Name of the medication
  /// - [dosage]: Dosage information
  /// - [times]: List of times to remind (e.g., ["08:00", "20:00"])
  /// - [frequency]: Frequency type ("Daily", "Every Other Day", "Weekly")
  Future<void> scheduleMedicationNotifications({
    required String medicationId,
    required String medicationName,
    required String dosage,
    required List<String> times,
    required String frequency,
  }) async {
    try {
      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i]; // "08:00" format
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;

        // Create a unique notification ID combining medication ID and time index
        final notificationId = int.parse(medicationId.replaceAll(RegExp(r'[^0-9]'), '')) * 100 + i;

        // Schedule based on frequency
        await _scheduleMedicationByFrequency(
          notificationId: notificationId,
          medicationName: medicationName,
          dosage: dosage,
          hour: hour,
          minute: minute,
          frequency: frequency,
        );
      }
      debugPrint('✅ Medication notifications scheduled for $medicationName');
    } catch (e) {
      debugPrint('❌ Error scheduling medication notifications: $e');
    }
  }

  /// Internal method to schedule notifications based on frequency
  Future<void> _scheduleMedicationByFrequency({
    required int notificationId,
    required String medicationName,
    required String dosage,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        autoCancel: true,
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Convert DateTime to TZDateTime for scheduling
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      debugPrint('🕐 Current time: ${now.toString()}');
      debugPrint('⏰ Initial scheduled time: ${scheduledDate.toString()}');

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        debugPrint('⏭️ Time passed, moved to tomorrow: ${scheduledDate.toString()}');
      }

      // Convert to TZDateTime using local timezone
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const title = '💊 Medication Reminder';
      final body = 'Time for your $medicationName! Dosage: $dosage. Tap to mark as taken.';

      debugPrint('📅 Scheduling $frequency notification for $medicationName');
      debugPrint('   ID: $notificationId');
      debugPrint('   Time: ${tzScheduledDate.toString()}');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');

      switch (frequency) {
        case 'Daily':
          await _local.zonedSchedule(
            notificationId,
            title,
            body,
            tzScheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('✅ Daily notification scheduled: ID=$notificationId');
          break;

        case 'Every Other Day':
          await _local.zonedSchedule(
            notificationId,
            title,
            body,
            tzScheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          // Schedule again for 2 days later
          final nextDate = tzScheduledDate.add(const Duration(days: 2));
          await _local.zonedSchedule(
            notificationId + 10000,
            title,
            body,
            nextDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('✅ Every Other Day notifications scheduled');
          break;

        case 'Weekly':
          // Schedule for same time next week
          final nextWeek = tzScheduledDate.add(const Duration(days: 7));
          await _local.zonedSchedule(
            notificationId,
            title,
            body,
            nextWeek,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('✅ Weekly notification scheduled');
          break;

        default:
          // Default to daily
          await _local.zonedSchedule(
            notificationId,
            title,
            body,
            tzScheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('✅ Default (daily) notification scheduled');
      }
    } catch (e) {
      debugPrint('❌ Error in _scheduleMedicationByFrequency: $e');
    }
  }

  /// Cancel medication notifications for a medication
  Future<void> cancelMedicationNotifications(String medicationId) async {
    try {
      // Calculate possible notification IDs (based on medicationId * 100)
      final baseId = int.tryParse(medicationId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      for (int i = 0; i < 10; i++) {
        await _local.cancel(baseId * 100 + i);
        await _local.cancel(baseId * 100 + i + 10000);
      }
      debugPrint('✅ Medication notifications cancelled for $medicationId');
    } catch (e) {
      debugPrint('❌ Error cancelling medication notifications: $e');
    }
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _local.cancelAll();
      debugPrint('✅ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// Test notification — shows immediately to verify system works
  Future<void> sendTestNotification() async {
    await show(
      id: 999,
      title: '🧪 Test Notification',
      body: 'If you see this, the notification system is working!',
    );
  }
}
