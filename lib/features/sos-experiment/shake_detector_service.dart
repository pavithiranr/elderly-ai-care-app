// lib/services/shake_detector_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects vigorous shake gestures using the user accelerometer.
/// A "shake" is registered when the vector magnitude exceeds [threshold]
/// and happens [requiredShakeCount] times within [windowDuration].
class ShakeDetectorService {
  final double threshold;
  final int requiredShakeCount;
  final Duration windowDuration;
  final VoidCallback onShakeDetected;

  ShakeDetectorService({
    this.threshold = 30.0,
    this.requiredShakeCount = 3,
    this.windowDuration = const Duration(milliseconds: 500),
    required this.onShakeDetected,
  });

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final List<DateTime> _shakeTimes = [];
  bool _isSosActive = false; // Guard: don't re-trigger during countdown

  void startListening() {
    _subscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~50ms sampling
    ).listen(_onAccelerometerEvent);
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Called externally when SOS overlay appears, to suppress re-triggers.
  void setSosActive(bool active) => _isSosActive = active;

  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    if (_isSosActive) return;

    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > threshold) {
      final now = DateTime.now();
      _shakeTimes.add(now);

      // Remove shake records outside the detection window
      _shakeTimes.removeWhere(
        (t) => now.difference(t) > windowDuration,
      );

      if (_shakeTimes.length >= requiredShakeCount) {
        _shakeTimes.clear();
        onShakeDetected();
      }
    }
  }

  void dispose() {
    stopListening();
  }
}
