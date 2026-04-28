// lib/mixins/inactivity_sos_mixin.dart
//
// Drop-in companion to ShakeSosMixin.
// Both mixins can coexist on the same State class - they use separate
// sensor subscriptions (sensors_plus handles multiple listeners fine).
//
// Usage:
//
//   class _DashboardScreenState extends State<DashboardScreen>
//       with ShakeSosMixin, InactivitySosMixin {
//
//     @override
//     void initState() {
//       super.initState();
//       initShakeSos(context);
//       initInactivityMonitor(userId: authService.currentUserId);
//     }
//
//     @override
//     void dispose() {
//       disposeShakeSos();
//       disposeInactivityMonitor();
//       super.dispose();
//     }
//   }
//
// To reset on user interaction, wrap your Scaffold body in:
//   GestureDetector(
//     onTap: inactivityResetTimer,
//     behavior: HitTestBehavior.translucent,
//     child: yourExistingBody,
//   )

import 'package:flutter/foundation.dart';
import 'activity_tracker_service.dart';
import 'inactivity_notification_service.dart';

mixin InactivitySosMixin {
  ActivityTrackerService? _activityTracker;
  InactivityNotificationService? _notificationService;

  // Expose to dashboard widget for the status indicator
  bool get inactivityMonitorActive => _activityTracker?.isRunning ?? false;
  bool get isWithinActiveHours =>
      _activityTracker?.isWithinActiveHours ?? false;
  Duration get timeSinceLastActivity =>
      _activityTracker?.timeSinceLastActivity ?? Duration.zero;

  Future<void> initInactivityMonitor({required String userId}) async {
    final notificationService = InactivityNotificationService(userId: userId);
    await notificationService.initialize();

    final activityTracker = ActivityTrackerService(
      // ── Durations ──────────────────────────────────────────────────
      // For hackathon demo: 1 minute warning, 2 minute escalation
      // For production:     4 hours warning,  5 minute escalation
      // To switch to production timings, uncomment these lines:
      // warningDuration: const Duration(hours: 4),
      // escalationGracePeriod: const Duration(minutes: 5),
      warningDuration: const Duration(minutes: 1), // Demo mode
      escalationGracePeriod: const Duration(minutes: 2), // Demo mode
      // ── Thresholds ─────────────────────────────────────────────────
      motionThreshold: 1.2, // Very sensitive - any tilt resets the timer
      activeStartHour: 8, // 8 AM
      activeEndHour: 22, // 10 PM
      // ── Stage 1: Local notification ────────────────────────────────
      onWarning: () async {
        await notificationService.showCheckInNotification();
      },

      // ── Stage 2: Firestore + caregiver escalation ──────────────────
      onEscalate: () async {
        await notificationService.escalateToFirestore();
        await notificationService.cancelCheckInNotification();

        // TODO: also trigger your existing sosService calls if desired:
        // sosService.sendLocationToCaregivers();
      },
    );

    activityTracker.start();
    debugPrint(
      '[InactivityMonitor] Initialized for user: $userId, active hours: ${activityTracker.activeStartHour}-${activityTracker.activeEndHour}',
    );

    // Now assign to the instance variables
    _notificationService = notificationService;
    _activityTracker = activityTracker;
  }

  /// Call this from any user tap - reset the inactivity timer.
  void inactivityResetTimer() {
    _activityTracker?.resetTimer();
    _notificationService?.cancelCheckInNotification();
    _notificationService?.resolveAlert();
  }

  void disposeInactivityMonitor() {
    _activityTracker?.stop();
  }
}
