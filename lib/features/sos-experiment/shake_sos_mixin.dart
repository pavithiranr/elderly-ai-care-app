// lib/mixins/shake_sos_mixin.dart
//
// Usage — add to any StatefulWidget screen (e.g. DashboardScreen):
//
//   class _DashboardScreenState extends State<DashboardScreen>
//       with ShakeSosMixin {
//
//     @override
//     void initState() {
//       super.initState();
//       initShakeSos(context);   // ← add this line
//     }
//
//     @override
//     void dispose() {
//       disposeShakeSos();       // ← add this line
//       super.dispose();
//     }
//   }
//

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shake_detector_service.dart';
import 'shake_sos_overlay.dart';

mixin ShakeSosMixin<T extends StatefulWidget> on State<T> {
  // ignore: unused_field
  late ShakeDetectorService _shakeService;
  bool _sosOverlayVisible = false;

  void initShakeSos(BuildContext ctx) {
    _shakeService = ShakeDetectorService(
      threshold: 30.0,
      requiredShakeCount: 3,
      windowDuration: const Duration(milliseconds: 500),
      onShakeDetected: () => _showSosOverlay(ctx),
    )..startListening();
  }

  void _showSosOverlay(BuildContext ctx) {
    if (_sosOverlayVisible) return; // Guard against double-trigger
    _sosOverlayVisible = true;
    _shakeService.setSosActive(true);

    Navigator.of(ctx, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => ShakeSosOverlay(
          countdownSeconds: 5,
          onConfirm: () {
            Navigator.of(ctx, rootNavigator: true).pop();
            _onSosConfirmed(ctx);
          },
          onCancel: () {
            Navigator.of(ctx, rootNavigator: true).pop();
            _onSosCancelled();
          },
        ),
      ),
    ).then((_) {
      // Cleanup when overlay closes for any reason
      _sosOverlayVisible = false;
      _shakeService.setSosActive(false);
    });
  }

  void _onSosConfirmed(BuildContext ctx) {
    // Navigate to SOS screen to trigger emergency flow
    debugPrint('[ShakeSOS] ✅ SOS CONFIRMED — navigating to SOS screen');
    
    // Use GoRouter if available, otherwise use Navigator
    try {
      ctx.push('/elderly/sos');
    } catch (e) {
      debugPrint('[ShakeSOS] Error navigating: $e');
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('🚨 SOS Triggered — Contacting caregivers...'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _onSosCancelled() {
    debugPrint('[ShakeSOS] ✅ Cancelled by user — all clear');
  }

  void disposeShakeSos() {
    _shakeService.dispose();
  }
}
