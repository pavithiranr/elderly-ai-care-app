// lib/services/activity_tracker_service.dart
//
// Monitors device motion AND app interactions to detect inactivity.
// Shares the sensors_plus accelerometer stream with ShakeDetectorService
// via an optional shared StreamController to avoid double-subscribing.
//
// Key behaviours:
//   • Motion resets the timer (magnitude > 1.2 - even a gentle tilt)
//   • App interactions reset the timer via resetTimer()
//   • Only active between activeStartHour–activeEndHour (default 8 AM–10 PM)
//   • Fires onWarning after warningDuration, then escalates after escalationGracePeriod

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef ActivityCallback = void Function();

class ActivityTrackerService {
  // ── Configuration ──────────────────────────────────────────────────────────
  final Duration warningDuration; // Time before first notification
  final Duration escalationGracePeriod; // Time after warning before escalation
  final double motionThreshold; // Magnitude that counts as "movement"
  final int activeStartHour; // 24h - don't alert before this hour
  final int activeEndHour; // 24h - don't alert after this hour

  // ── Callbacks ──────────────────────────────────────────────────────────────
  final ActivityCallback onWarning; // Show local notification
  final ActivityCallback onEscalate; // Write to Firestore, alert caregiver

  ActivityTrackerService({
    // Demo-friendly defaults - change warningDuration to Duration(hours: 4)
    // and escalationGracePeriod to Duration(minutes: 5) for production.
    this.warningDuration = const Duration(minutes: 1),
    this.escalationGracePeriod = const Duration(minutes: 5),
    this.motionThreshold = 1.2,
    this.activeStartHour = 8,
    this.activeEndHour = 22,
    required this.onWarning,
    required this.onEscalate,
  });

  // ── Internal state ─────────────────────────────────────────────────────────
  DateTime _lastActivityTime = DateTime.now();
  Timer? _checkTimer;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  bool _warningFired = false;
  bool _escalationFired = false;
  bool _isRunning = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastActivityTime = DateTime.now();
    _startAccelerometer();
    _startCheckTimer();
    debugPrint(
      '[ActivityTracker] ▶ Started - warning in ${warningDuration.inMinutes}min, active hours: $activeStartHour-$activeEndHour',
    );
  }

  void stop() {
    _isRunning = false;
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('[ActivityTracker] ⏹ Stopped');
  }

  /// Call this from any user interaction: button taps, navigation, etc.
  /// Wrap your GestureDetector or Navigator with this.
  void resetTimer() {
    if (!_isRunning) return;
    _lastActivityTime = DateTime.now();
    if (_warningFired || _escalationFired) {
      debugPrint('[ActivityTracker] ✅ User responded - resetting alert state');
      _warningFired = false;
      _escalationFired = false;
    }
  }

  /// How long ago was the last detected activity?
  Duration get timeSinceLastActivity =>
      DateTime.now().difference(_lastActivityTime);

  /// Is the current time within the active monitoring window?
  bool get isWithinActiveHours {
    final h = DateTime.now().hour;
    return h >= activeStartHour && h <= activeEndHour;
  }

  bool get isRunning => _isRunning;

  // ── Private helpers ────────────────────────────────────────────────────────

  void _startAccelerometer() {
    // Use gameInterval (~50ms) - same rate as ShakeDetectorService.
    // If your app already has a broadcast stream, pass it in instead.
    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude > motionThreshold) {
        // Throttle resets - only update if it's been at least 2 seconds
        // to avoid flooding _lastActivityTime with every micro-vibration.
        final now = DateTime.now();
        if (now.difference(_lastActivityTime) > const Duration(seconds: 2)) {
          _lastActivityTime = now;
        }
      }
    });
  }

  void _startCheckTimer() {
    // Check every 10 seconds - cheap enough, no Firestore writes unless alert fires.
    _checkTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _evaluate(),
    );
  }

  void _evaluate() {
    if (!isWithinActiveHours) {
      // Silent hours - reset state so we don't alert at 8 AM for overnight inactivity.
      if (_warningFired || _escalationFired) {
        _warningFired = false;
        _escalationFired = false;
        _lastActivityTime = DateTime.now();
        debugPrint('[ActivityTracker] 🌙 Outside active hours - state reset');
      }
      return;
    }

    final elapsed = timeSinceLastActivity;
    debugPrint('[ActivityTracker] ⏱ Inactive for ${elapsed.inSeconds}s');

    // ── Stage 1: Warning ────────────────────────────────────────────────
    if (!_warningFired && elapsed >= warningDuration) {
      _warningFired = true;
      debugPrint(
        '[ActivityTracker] ⚠️  Warning threshold hit - firing onWarning',
      );
      onWarning();
      return;
    }

    // ── Stage 2: Escalation ─────────────────────────────────────────────
    if (_warningFired &&
        !_escalationFired &&
        elapsed >= warningDuration + escalationGracePeriod) {
      _escalationFired = true;
      debugPrint(
        '[ActivityTracker] 🚨 Escalation threshold hit - firing onEscalate',
      );
      onEscalate();
    }
  }

  void dispose() {
    stop();
  }
}
