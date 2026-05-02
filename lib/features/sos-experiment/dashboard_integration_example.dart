// lib/screens/dashboard_screen.dart  (EXAMPLE - adapt to your existing file)
//
// Minimal changes needed to your existing DashboardScreen:
//   1. Add `with ShakeSosMixin` to the State class
//   2. Call initShakeSos(context) in initState
//   3. Call disposeShakeSos() in dispose
//   (No UI changes required - the overlay handles itself)

import 'package:flutter/material.dart';
// import '../mixins/shake_sos_mixin.dart';

// ─── BEFORE (your existing class header) ───
// class _DashboardScreenState extends State<DashboardScreen> {

// ─── AFTER (add the mixin) ──────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
// with ShakeSosMixin {   // ← uncomment this line
{
  @override
  void initState() {
    super.initState();
    // initShakeSos(context);  // ← uncomment this line
  }

  @override
  void dispose() {
    // disposeShakeSos();       // ← uncomment this line
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Your existing dashboard build method - NO CHANGES NEEDED HERE
    return Scaffold(
      appBar: AppBar(title: const Text('Care Dashboard')),
      body: const Center(
        child: Text(
          'Shake the phone to test SOS!\n\n'
          '(ShakeSosMixin is active)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
