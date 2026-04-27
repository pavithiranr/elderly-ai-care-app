import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/services/patient_service.dart';
import '../../../shared/services/user_session_service.dart';
import '../../sos-experiment/shake_sos_mixin.dart';
import '../../deadman-switch/inactivity_sos_mixin.dart';
import '../../deadman-switch/safety_status_indicator.dart';

/// Elderly Home Screen.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
class ElderlyHomeScreen extends StatefulWidget {
  const ElderlyHomeScreen({super.key});

  @override
  State<ElderlyHomeScreen> createState() => _ElderlyHomeScreenState();
}

class _ElderlyHomeScreenState extends State<ElderlyHomeScreen>
    with ShakeSosMixin, InactivitySosMixin {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _today => DateFormat('EEEE, MMMM d').format(DateTime.now());

  /// Timer to rebuild only when hour changes (active hours boundary)
  Timer? _hourChangeTimer;
  int _lastHour = DateTime.now().hour;

  @override
  void initState() {
    super.initState();
    initShakeSos(context);

    // Start inactivity monitor IMMEDIATELY on app start
    _initializeMonitor();  // Fire and forget, but tracks initialization

    // Check every minute if the hour changed (for active hours boundary: 8 AM or 10 PM)
    // Only rebuild on hour change to avoid excessive rebuilds
    _hourChangeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentHour = DateTime.now().hour;
      if (currentHour != _lastHour && mounted) {
        _lastHour = currentHour;
        setState(() {}); // Rebuild only when hour changes
      }
    });
  }

  /// Initialize the inactivity monitor asynchronously
  Future<void> _initializeMonitor() async {
    try {
      final userId = await UserSessionService.instance.getSavedUserId();
      if (userId != null && mounted) {
        await initInactivityMonitor(userId: userId);
        if (mounted) {
          setState(() {}); // Force rebuild once tracker is truly initialized
        }
      }
    } catch (e) {
      debugPrint('[ElderlyHomeScreen] Failed to initialize monitor: $e');
    }
  }

  @override
  void dispose() {
    _hourChangeTimer?.cancel();
    disposeShakeSos();
    disposeInactivityMonitor();
    super.dispose();
  }

  /// Refresh callback for pull-to-refresh gesture
  Future<void> _handleRefresh() async {
    // Force state rebuild to refresh all getters (isWithinActiveHours, etc.)
    if (mounted) {
      setState(() {});
    }
    // Simulate a small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: SafetyStatusIndicator(
                isActive: inactivityMonitorActive,
                isWithinActiveHours: isWithinActiveHours,
                timeSinceLastActivity: timeSinceLastActivity,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: inactivityResetTimer,
        behavior: HitTestBehavior.translucent,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SafeArea(
            child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
              const SizedBox(height: 32),

              // ── Check-in banner ───────────────────────────────────────
              _CheckinBanner(
                onTap: () => context.push(AppConstants.routeElderlyCheckin),
              ),
              const SizedBox(height: 32),

              // ── SOS button (prominent, immediately accessible) ────────
              _SosButton(
                onTap: () => context.push(AppConstants.routeSos),
              ),
              const SizedBox(height: 32),

              // ── AI Summary ────────────────────────────────────────────
              FutureBuilder<String?>(
                future: UserSessionService.instance.getSavedUserId(),
                builder: (context, idSnap) {
                  final userId = idSnap.data;
                  if (userId == null) return const SizedBox.shrink();
                  return _ElderlyAiSummary(patientId: userId);
                },
              ),
              const SizedBox(height: 32),

              // ── Section label ─────────────────────────────────────────
              Text(
                'What do you need?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 14),

              // ── Quick Action grid ─────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 0.95,
                children: [
                  _QuickAction(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Check In',
                    color: Theme.of(context).colorScheme.primary,
                    bg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    onTap: () => context.push(AppConstants.routeElderlyCheckin),
                  ),
                  _QuickAction(
                    icon: Icons.medication_rounded,
                    label: 'Medications',
                    color: const Color(0xFFEA580C),
                    bg: const Color(0xFFEA580C).withValues(alpha: 0.15),
                    onTap: () => context.push(AppConstants.routeMedication),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textMid = Theme.of(context).textTheme.bodyMedium?.color 
      ?? (isDarkMode ? Colors.grey[400] : Colors.grey[600]);
    final textDark = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
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
                  color: textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: AppTheme.elderlyTitleFontSize,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  color: textMid,
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
            decoration: BoxDecoration(
              color: isDarkMode ? primaryColor.withValues(alpha: 0.2) : primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: isDarkMode ? Border.all(color: primaryColor, width: 1.5) : null,
            ),
            child: Icon(
              Icons.person_rounded,
              color: primaryColor,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Use a darker, desaturated accent for dark mode
    final gradientStart = isDarkMode ? primaryColor.withValues(alpha: 0.8) : primaryColor;
    final gradientEnd = isDarkMode ? primaryColor.withValues(alpha: 0.6) : primaryColor.withAlpha(220);
    final textColor = isDarkMode ? Colors.white : Theme.of(context).colorScheme.onPrimary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: textColor,
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
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How are you feeling today?',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          color: textColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Theme.of(context).colorScheme.onSurface;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    // Adapt background color for dark mode for better contrast
    final adaptedBg = isDarkMode ? bg.withValues(alpha: 0.15) : bg.withValues(alpha: 0.1);
    
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode ? dividerColor.withValues(alpha: 0.6) : dividerColor,
              width: 1.5,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: adaptedBg,
                    borderRadius: BorderRadius.circular(14),
                    border: isDarkMode ? Border.all(color: color.withValues(alpha: 0.4), width: 1) : null,
                  ),
                  child: Icon(
                    icon,
                    color: isDarkMode ? color.withValues(alpha: 0.9) : color,
                    size: AppTheme.elderlyIconSize,
                  ),
                ),
                const SizedBox(height: 16),
                // Wrap label in FittedBox to allow text scaling without overflow
                // Use mainAxisSize.min to allow the Column to shrink-wrap
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: AppTheme.elderlyBodyFontSize, // 22px
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.2,
                    ),
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

// ── Elderly AI Summary ────────────────────────────────────────────────────────

class _ElderlyAiSummary extends StatefulWidget {
  final String patientId;
  const _ElderlyAiSummary({required this.patientId});

  @override
  State<_ElderlyAiSummary> createState() => _ElderlyAiSummaryState();
}

class _ElderlyAiSummaryState extends State<_ElderlyAiSummary> {
  late Future<String> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _fetchSummary();
  }

  Future<String> _fetchSummary() async {
    try {
      final health = await PatientService.instance.getTodayHealthData(widget.patientId);
      if (health == null) {
        return "You haven't checked in yet today. Tap 'Check In' above to log how you're feeling!";
      }

      final events = [
        'Mood today: ${health.mood}',
        'Pain level: ${health.painLevel}/10',
        'Medications taken: ${health.medicationsTaken} of ${health.medicationsTotal}',
        if (health.sosAlerts > 0) 'SOS alerts today: ${health.sosAlerts}',
      ];

      return await GeminiService.instance.generateHealthSummary(events);
    } catch (_) {
      return "Great job keeping up with your health today! Remember to take your medications and stay hydrated.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _summaryFuture,
      builder: (context, snap) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? primaryColor.withValues(alpha: 0.15)
                  : primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final summary = snap.data ?? '';
        if (summary.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? primaryColor.withValues(alpha: 0.15)
                : primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDarkMode ? 0.3 : 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Health Today',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: GoogleFonts.inter(
                  fontSize: AppTheme.elderlyBodyFontSize,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.55,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── SOS Button ────────────────────────────────────────────────────────────────

class _SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return SizedBox(
      width: double.infinity,
      height: AppTheme.elderlyButtonHeight + 10, // 74px — extra prominent
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: errorColor,
          foregroundColor: Theme.of(context).colorScheme.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
          shadowColor: errorColor.withValues(alpha: 0.4),
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
