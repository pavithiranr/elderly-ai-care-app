import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/patient_service.dart';
import '../../../shared/services/user_session_service.dart';

/// Elderly Home Screen.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
class ElderlyHomeScreen extends StatelessWidget {
  const ElderlyHomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _today => DateFormat('EEEE, MMMM d').format(DateTime.now());

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: Text(
                'Settings',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeElderlySettings);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.accentRed),
              title: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentRed,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await UserSessionService.instance.clearSession();
                if (context.mounted) {
                  context.go(AppConstants.routeOnboarding);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              FutureBuilder<PatientProfile?>(
                future: UserSessionService.instance.getSavedUserId().then(
                      (userId) => userId != null
                          ? PatientService.instance.getPatientById(userId)
                          : null,
                    ),
                builder: (context, snapshot) {
                  final patientName = snapshot.data?.name ?? 'Friend';
                  return _Header(
                    greeting: _greeting,
                    date: _today,
                    name: patientName,
                    onProfileTap: () => _showProfileMenu(context),
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Check-in banner ───────────────────────────────────────
              _CheckinBanner(
                onTap: () => context.push(AppConstants.routeElderlyCheckin),
              ),
              const SizedBox(height: 28),

              // ── Section label ─────────────────────────────────────────
              Text(
                'What do you need?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),

              // ── Quick Action grid ─────────────────────────────────────
              // 2-column grid; childAspectRatio tuned so label text fits at 22px
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _QuickAction(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Check In',
                    color: AppTheme.primaryBlue,
                    bg: AppTheme.primaryLight,
                    onTap: () => context.push(AppConstants.routeElderlyCheckin),
                  ),
                  _QuickAction(
                    icon: Icons.medication_rounded,
                    label: 'Medications',
                    color: AppTheme.accentOrange,
                    bg: const Color(0xFFFFF7ED),
                    onTap: () => context.push(AppConstants.routeMedication),
                  ),
                  _QuickAction(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Talk to AI',
                    color: const Color(0xFF7C3AED),
                    bg: const Color(0xFFF5F3FF),
                    onTap: () => context.push(AppConstants.routeElderlyChat),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── SOS button ────────────────────────────────────────────
              _SosButton(
                onTap: () => context.push(AppConstants.routeSos),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String date;
  final String name;
  final VoidCallback? onProfileTap;

  const _Header({
    required this.greeting,
    required this.date,
    required this.name,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: AppTheme.elderlyTitleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primaryBlue,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Check-in Banner ───────────────────────────────────────────────────────────

class _CheckinBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CheckinBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Check-in",
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How are you feeling today?',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: AppTheme.elderlyIconSize,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: AppTheme.elderlyBodyFontSize, // 22px
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SOS Button ────────────────────────────────────────────────────────────────

class _SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.elderlyButtonHeight + 10, // 74px — extra prominent
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
          shadowColor: AppTheme.accentRed.withValues(alpha: 0.4),
          textStyle: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: const Icon(Icons.emergency_rounded, size: 32),
        label: const Text('SOS — Emergency'),
      ),
    );
  }
}
