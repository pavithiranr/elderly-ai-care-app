import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/user_session_service.dart';

/// SOS Emergency Screen.
/// Full-screen design with a pulsing button and a confirmation dialog
/// before any alert is sent. Design rules: ≥22px font, ≥64px buttons, MD3.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _alertSent = false;
  bool _isSending = false;

  Future<void> _confirmAndSend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ConfirmDialog(),
    );
    if (confirmed == true && mounted) {
      _sendAlert();
    }
  }

  Future<void> _sendAlert() async {
    if (mounted) setState(() => _isSending = true);
    
    try {
      final patientId = await UserSessionService.instance.getSavedUserId();
      if (patientId != null) {
        final timestamp = Timestamp.now();

        // Get elderly document first (needed for caregiver ID and name)
        final elderlyDoc = await FirebaseFirestore.instance
            .collection('elderly')
            .doc(patientId)
            .get();

        final caregiverId = elderlyDoc.data()?['caregiverId'] as String?;
        final elderlyName = elderlyDoc.data()?['name'] as String? ?? 'Your patient';

        // Run both writes in parallel (they don't depend on each other)
        final futures = <Future<void>>[
          // Write to elderly's own SOS subcollection (for SOS count queries)
          FirebaseFirestore.instance
              .collection('elderly')
              .doc(patientId)
              .collection('sos_alerts')
              .add({'timestamp': timestamp, 'resolved': false})
              .then((_) {}),
        ];

        // Write to caregiver's alerts collection if caregiver exists
        if (caregiverId != null) {
          futures.add(
            FirebaseFirestore.instance
                .collection('caregiver_alerts')
                .doc(caregiverId)
                .collection('alerts')
                .add({
              'severity': 'critical',
              'type': 'SOS Emergency Alert',
              'body': '$elderlyName has triggered an SOS emergency alert and needs immediate assistance.',
              'timestamp': timestamp,
              'isUnread': true,
              'elderlyId': patientId,
            }).then((_) {}),
          );
        }

        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('SOS write error: $e');
    }
    if (mounted) {
      setState(() {
        _isSending = false;
        _alertSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent accidental back-swipe after alert is sent
      canPop: !_alertSent,
      child: Scaffold(
        backgroundColor:
            _alertSent ? const Color(0xFFFEF2F2) : AppTheme.backgroundGray,
        appBar: AppBar(
          leading: _alertSent
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                  onPressed: () => context.pop(),
                ),
          title: Text(
            'Emergency SOS',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          toolbarHeight: 64,
        ),
        body: _alertSent
            ? _SentView(onBack: () => context.pop())
            : _isSending
                ? _SendingView()
                : _ReadyView(onConfirm: _confirmAndSend),
      ),
    );
  }
}

// ── Confirmation Dialog ───────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppTheme.accentRed,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Send Emergency Alert?',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              'Your caregivers and family will be\ncontacted immediately.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textMid,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Send button
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: const Text('Yes — Send Alert'),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  side: const BorderSide(color: AppTheme.divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text("No — I'm Fine"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ready View ────────────────────────────────────────────────────────────────

class _ReadyView extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ReadyView({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Instruction text
            Text(
              'Need Help?',
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Press the button below to alert\nyour caregivers immediately.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textMid,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 2),

            // Pulsing SOS button — fills most of the screen width
            _PulsingSOSButton(onTap: onConfirm),

            const Spacer(flex: 2),

            // Cancel link — still a full-height tappable area for safety
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMid,
                  side: const BorderSide(color: AppTheme.divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text("I'm Fine — Go Back"),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing SOS Button ────────────────────────────────────────────────────────

class _PulsingSOSButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsingSOSButton({required this.onTap});

  @override
  State<_PulsingSOSButton> createState() => _PulsingSOSButtonState();
}

class _PulsingSOSButtonState extends State<_PulsingSOSButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _ringOpacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);

    // Button itself breathes slightly
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Outer ring fades out as it expands
    _ringOpacityAnim = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Button diameter = 72% of screen width, capped for large screens
    final size = (MediaQuery.of(context).size.width * 0.72).clamp(200.0, 280.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: size + 60,
          height: size + 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Transform.scale(
                scale: 1.0 + (_controller.value * 0.28),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentRed
                        .withValues(alpha: _ringOpacityAnim.value),
                  ),
                ),
              ),

              // Inner pulse ring (offset phase)
              Transform.scale(
                scale: 1.0 + ((((_controller.value + 0.5) % 1.0)) * 0.28),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentRed.withValues(
                      alpha: Tween<double>(begin: 0.5, end: 0.0).evaluate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
                        ),
                      ) *
                          (1 -
                              ((_controller.value + 0.5) % 1.0) /
                                  (_controller.value + 0.5) %
                                  1.0)
                              .clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),

              // Main button
              Transform.scale(
                scale: _scaleAnim.value,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentRed,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentRed.withValues(alpha: 0.45),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emergency_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SOS',
                          style: GoogleFonts.inter(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'Tap to Alert',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sent View ─────────────────────────────────────────────────────────────────

class _SentView extends StatelessWidget {
  final VoidCallback onBack;
  const _SentView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: AppTheme.accentRed,
                size: 64,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Alert Sent!',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentRed,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Your caregivers have been\nnotified. Help is on the way.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textMid,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              'Stay calm. Stay where you are.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.accentRed,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: const Text('Go Back Home'),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Sending View ──────────────────────────────────────────────────────────────

class _SendingView extends StatelessWidget {
  const _SendingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Loading spinner
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentRed),
            ),
            const SizedBox(height: 32),

            Text(
              'Alerting Caregivers...',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            Text(
              'Sending your emergency alert\nto your caregivers now.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textMid,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
