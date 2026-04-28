// lib/widgets/shake_sos_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen emergency overlay shown after shake detection.
/// Counts down [countdownSeconds] seconds before triggering SOS.
/// The user can cancel with the large "I AM OKAY" button.
class ShakeSosOverlay extends StatefulWidget {
  final int countdownSeconds;
  final VoidCallback onConfirm; // Called when timer hits zero
  final VoidCallback onCancel; // Called when user taps CANCEL

  const ShakeSosOverlay({
    super.key,
    this.countdownSeconds = 5,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ShakeSosOverlay> createState() => _ShakeSosOverlayState();
}

class _ShakeSosOverlayState extends State<ShakeSosOverlay>
    with TickerProviderStateMixin {
  late int _remaining;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;

    // Pulse animation for the SOS circle
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ring expansion animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _ringAnimation = Tween<double>(
      begin: 0.5,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _ringController, curve: Curves.easeOut));

    // Haptic feedback loop every second
    _startCountdown();
  }

  void _startCountdown() {
    // Initial haptic
    HapticFeedback.heavyImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      HapticFeedback.mediumImpact();
      if (_remaining <= 1) {
        timer.cancel();
        widget.onConfirm();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFCC0000),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ── Header ──────────────────────────────────────────────
              Column(
                children: const [
                  Text(
                    '⚠️  EMERGENCY DETECTED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Shake detected - SOS will be sent in:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),

              // ── Pulsing Countdown Circle ─────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Expanding ring
                  AnimatedBuilder(
                    animation: _ringAnimation,
                    builder:
                        (_, __) => Container(
                          width: 200 * _ringAnimation.value,
                          height: 200 * _ringAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: 1.0 - _ringAnimation.value * 0.7,
                              ),
                              width: 3,
                            ),
                          ),
                        ),
                  ),
                  // Main pulsing circle
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder:
                        (_, __) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_remaining',
                                  style: const TextStyle(
                                    color: Color(0xFFCC0000),
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                                const Text(
                                  'seconds',
                                  style: TextStyle(
                                    color: Color(0xFFCC0000),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ],
              ),

              // ── What will happen ────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    _ActionRow(icon: '📞', text: 'Call emergency contacts'),
                    SizedBox(height: 8),
                    _ActionRow(
                      icon: '📍',
                      text: 'Send your location to caregivers',
                    ),
                    SizedBox(height: 8),
                    _ActionRow(icon: '🚨', text: 'Activate emergency alert'),
                  ],
                ),
              ),

              // ── CANCEL Button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _countdownTimer?.cancel();
                      widget.onCancel();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFCC0000),
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      '✅  I AM OKAY - CANCEL',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String icon;
  final String text;
  const _ActionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
