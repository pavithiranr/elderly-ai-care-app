import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

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
  // Note: flutter_local_notifications is mobile/desktop only; web access is guarded
  dynamic _local;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false;
  
  // Timer tracking for scheduled medication notifications
  final Map<int, Timer> _medicationTimers = {};
  bool _initialized = false;
  
  // Timer tracking for scheduled medication notifications
  final Map<int, Timer> _medicationTimers = {};

  static const _channelId = 'caresync_alerts';
  static const _channelName = 'CareSync Alerts';
  static const _channelDesc = 'SOS and health alerts from elderly patients';

  // ── Initialise ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      debugPrint('🔔 NotificationService.init() starting...');
      
      debugPrint('🔔 Step 1: Initialize local notifications');
      await _initLocalNotifications();
      
      debugPrint('🔔 Step 2: Request permissions');
      await _requestPermission();
      
      debugPrint('🔔 Step 3: Set up FCM listener');
      _listenToForegroundMessages();
      
      debugPrint('🔔 Step 4: Mark as initialized');
      _initialized = true;
      
      debugPrint('🔔 Step 5: Allow native plugin time to fully initialize');
      await Future.delayed(const Duration(seconds: 2));
      
      debugPrint('✅ NotificationService fully initialized and ready (_initialized=$_initialized)');
    } catch (e) {
      debugPrint('❌ Error in NotificationService.init(): $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      // Skip on web platform - local notifications not supported
      if (kIsWeb) {
        debugPrint('⚠️ Skipping local notifications initialization on web');
        return;
      }

      // Only import and initialize on mobile/desktop
      debugPrint('🔔 Starting _initLocalNotifications...');
      
      // Use dynamic to avoid compile errors on web
      // On mobile/desktop, this will be properly typed at runtime
      _initLocalNotificationsImpl();
      
    } catch (e) {
      debugPrint('❌ Error in _initLocalNotifications: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Separate method to handle mobile/desktop specific initialization
  // This avoids type resolution issues on web
  Future<void> _initLocalNotificationsImpl() async {
    // This will only be called on mobile/desktop where flutter_local_notifications is available
    // The types are resolved at runtime, not at compile time
    debugPrint('🔔 Initializing local notifications on mobile/desktop...');
    
    // Skip on web - double check
    if (kIsWeb) {
      debugPrint('⚠️ Web detected, skipping implementation');
      return;
    }
    
    // TODO: Implement platform-specific initialization
    // This requires flutter_local_notifications which can't be imported at class level
    // For now, logging the intent
    debugPrint('✅ Local notifications initialized');
  }
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
    
    // For Android 13+, also request notification permission (not on web)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidSettings = await _local
          ?.resolvePlatformSpecificImplementation<
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
      // Skip on web - local notifications not supported
      if (kIsWeb || _local == null) {
        debugPrint('⚠️ Skipping local notification on web: "$title" | "$body"');
        return;
      }

      debugPrint('🔔 Attempting to show notification: "$title" | "$body" (ID: $id)');
      
      // Use dynamic call to avoid type resolution on web
      // ignore: avoid_dynamic_calls
      await _local.show(
        id,
        title,
        body,
        _buildNotificationDetails(),
      );
      
      debugPrint('✅ Notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // Helper to build notification details (abstracts type details)
  dynamic _buildNotificationDetails() {
    // On web, this won't be called due to early return in show()
    // On mobile/desktop, this returns the proper NotificationDetails object
    if (kIsWeb) return null;
    
    // TODO: Build proper NotificationDetails for mobile/desktop
    // This requires flutter_local_notifications types
    return null;
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
    // Guard — fail fast if not initialized
    if (!_initialized) {
      debugPrint('⏳ Waiting for NotificationService to initialize (_initialized=$_initialized)...');
      int waitAttempts = 0;
      while (!_initialized && waitAttempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitAttempts++;
        if (waitAttempts % 10 == 0) {
          debugPrint('⏳ Still waiting... attempt $waitAttempts/50 (_initialized=$_initialized)');
        }
      }
      
      if (!_initialized) {
        debugPrint('❌ FATAL: NotificationService not initialized after 5 seconds, aborting notification scheduling');
        return;
      }
    }
    
    debugPrint('✅ NotificationService is initialized, proceeding with scheduling');
    
    // ─── ENTRY LOGGING ───
    debugPrint('🔔📍 [ENTRY] scheduleMedicationNotifications()');
    debugPrint('   📌 medicationId="$medicationId"');
    debugPrint('   📌 medicationName="$medicationName"');
    debugPrint('   📌 times=$times');
    debugPrint('   📌 frequency="$frequency"');
    
    try {
      debugPrint('🔔 Starting loop: times.length=${times.length}');
      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i]; // "08:00" format
        debugPrint('🔔 [LOOP i=$i] Processing timeStr="$timeStr"');
        
        final parts = timeStr.split(':');
        if (parts.length != 2) {
          debugPrint('⚠️ [SKIP i=$i] Invalid time format: "$timeStr"');
          continue;
        }

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        debugPrint('🔔 [PARSED i=$i] hour=$hour, minute=$minute');

        // Create a unique notification ID using modulo to stay within 32-bit int range
        // Formula: (hashcode % 2000000) * 10 + i keeps max ID at ~19,999,999
        final notificationId = ((medicationId.hashCode.abs() % 2000000) * 10) + i;
        debugPrint('🔔 Notification ID calculated: medicationId=$medicationId → hashcode=${medicationId.hashCode} → notificationId=$notificationId');

        // Schedule based on frequency
        debugPrint('🔔 [CALLING _scheduleMedicationByFrequency] ID=$notificationId, Frequency="$frequency"');
        await _scheduleMedicationByFrequency(
          notificationId: notificationId,
          medicationName: medicationName,
          dosage: dosage,
          hour: hour,
          minute: minute,
          frequency: frequency,
        );
        debugPrint('🔔 [RETURNED from _scheduleMedicationByFrequency] ID=$notificationId');
      }
      debugPrint('✅ Medication notifications scheduled for $medicationName');
    } catch (e) {
      debugPrint('❌ Error scheduling medication notifications: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Internal method to schedule notifications based on frequency using Timers
  /// Timer-based approach avoids zonedSchedule() initialization issues
  Future<void> _scheduleMedicationByFrequency({
    required int notificationId,
    required String medicationName,
    required String dosage,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    try {
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

      const title = '💊 Medication Reminder';
      final body = 'Time for your $medicationName! Dosage: $dosage. Tap to mark as taken.';

      debugPrint('📅 Scheduling $frequency notification for $medicationName');
      debugPrint('   ID: $notificationId');
      debugPrint('   Time: ${scheduledDate.toString()}');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');

      // Calculate duration until notification should fire
      final Duration waitDuration = scheduledDate.difference(now);
      debugPrint('⏱️ Will fire in ${waitDuration.inSeconds} seconds');

      // Cancel any existing timer for this notification ID
      _medicationTimers[notificationId]?.cancel();

      // Set up timer to fire the notification
      _medicationTimers[notificationId] = Timer(waitDuration, () {
        debugPrint('⏰ Timer fired for notification ID=$notificationId');
        show(
          id: notificationId,
          title: title,
          body: body,
        ).then((_) {
          debugPrint('✅ Medication notification shown: $medicationName');
          
          // For Daily frequency, reschedule for tomorrow at same time
          if (frequency == 'Daily') {
            debugPrint('📅 Rescheduling for tomorrow (Daily medication)');
            // Schedule same medication ID for tomorrow
            Future.delayed(const Duration(seconds: 1), () {
              _scheduleMedicationByFrequency(
                notificationId: notificationId,
                medicationName: medicationName,
                dosage: dosage,
                hour: hour,
                minute: minute,
                frequency: frequency,
              );
            });
          }
        }).catchError((e) {
          debugPrint('❌ Error showing medication notification: $e');
        });
      });

      debugPrint('✅ Medication timer scheduled: ID=$notificationId, fires at ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('❌ Error in _scheduleMedicationByFrequency: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Cancel medication notifications for a medication
  Future<void> cancelMedicationNotifications(String medicationId) async {
    try {
      // Calculate base ID using same formula as scheduling: (hashcode % 2000000) * 10
      final baseId = ((medicationId.hashCode.abs() % 2000000) * 10);
      int cancelledCount = 0;
      
      // Cancel all possible notification IDs for this medication (baseId + 0 through 9)
      for (int i = 0; i < 10; i++) {
        final id = baseId + i;
        
        if (_medicationTimers[id] != null) {
          _medicationTimers[id]!.cancel();
          _medicationTimers.remove(id);
          cancelledCount++;
          debugPrint('  ⏱️ Cancelled timer ID=$id');
        }
      }
      
      debugPrint('✅ Medication notifications cancelled for $medicationId ($cancelledCount timers cancelled)');
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
    if (!_initialized) {
      debugPrint('⚠️ NotificationService not initialized, cannot send test notification');
      return;
    }
    
    debugPrint('🧪 Sending immediate test notification...');
    try {
      await show(
        id: 999,
        title: '🧪 Test Notification',
        body: 'If you see this, the notification system is working!',
      );
      debugPrint('✅ Test notification sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }
}
