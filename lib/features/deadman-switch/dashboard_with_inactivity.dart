// lib/screens/dashboard_screen.dart  (INTEGRATION EXAMPLE)
//
// Shows how ShakeSosMixin + InactivitySosMixin coexist cleanly.
// Only the marked lines need adding to your existing dashboard.

import 'package:flutter/material.dart';
// import '../mixins/shake_sos_mixin.dart';
// import '../mixins/inactivity_sos_mixin.dart';
// import '../widgets/safety_status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    // ① Add both mixins ─────────────────────────────────────────────────────
    // with ShakeSosMixin, InactivitySosMixin {
{
  @override
  void initState() {
    super.initState();

    // ② Start both monitors ─────────────────────────────────────────────────
    // initShakeSos(context);
    // initInactivityMonitor(userId: 'YOUR_USER_ID_FROM_AUTH');
  }

  @override
  void dispose() {
    // ③ Dispose both ────────────────────────────────────────────────────────
    // disposeShakeSos();
    // disposeInactivityMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Care Dashboard'),
        actions: [
          // ④ Status indicator in the AppBar ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              // Real version uses mixin getters:
              // SafetyStatusIndicator(
              //   isActive: inactivityMonitorActive,
              //   isWithinActiveHours: isWithinActiveHours,
              //   timeSinceLastActivity: timeSinceLastActivity,
              // ),
              child: SafetyStatusIndicatorDemo(), // Remove this in real app
            ),
          ),
        ],
      ),

      // ⑤ Wrap body in GestureDetector to reset timer on any tap ──────────
      body: GestureDetector(
        // onTap: inactivityResetTimer,   // ← uncomment this
        behavior: HitTestBehavior.translucent,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.health_and_safety, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            '360° Safety Active',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Shake → Instant SOS\n'
            '• Stillness → Passive wellness check',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// Placeholder for the demo — remove in real app
class SafetyStatusIndicatorDemo extends StatelessWidget {
  const SafetyStatusIndicatorDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          SizedBox(width: 6),
          Text(
            'Monitoring Safety...',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF22C55E),
      ),
    );
  }
}
